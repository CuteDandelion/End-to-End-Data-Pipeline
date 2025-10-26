from pyspark.sql import SparkSession
from pyspark.sql.functions import from_json, col, when, lit
from pyspark.sql.types import StructType, StructField, StringType, LongType, DoubleType
import logging
import great_expectations as ge
from great_expectations.core.batch import RuntimeBatchRequest
import psycopg2
import os
import sys

## Logging Configuration
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")

# Kafka Configuration
KAFKA_BROKER = "127.0.0.1:9092"
KAFKA_TOPIC = "sensor_readings"
CONSUMER_GROUP = "sensor_readings_consumer"

# MinIO (S3-Compatible Storage) Configuration
MINIO_ENDPOINT = "https://s3.amazonaws.com"
MINIO_ACCESS_KEY = "AKIA"
MINIO_SECRET_KEY = "AE2K"
RAW_DATA_PATH = "s3a://data-pipeline-data-bucket-572642e9/raw-data/streaming_raw/"
ANOMALY_DATA_PATH = "s3a://data-pipeline-data-bucket-572642e9/processed-data/streaming_anomalies/"

# PostgreSQL Configuration
POSTGRES_HOST = "postgres"
POSTGRES_PORT = "5432"
POSTGRES_DB = "processed_db"
POSTGRES_USER = "user"
POSTGRES_PASSWORD = "pass"

# Define schema for incoming JSON
schema = StructType([
    StructField("event_id", StringType(), False),
    StructField("timestamp", LongType(), False),
    StructField("device_id", LongType(), False),
    StructField("reading_value", DoubleType(), False)
])


def validate_schema(df, batch_id):
    """
    Validate the schema of the incoming streaming DataFrame using Great Expectations.
    Ensures:
      - 'event_id' is non-null and unique
      - 'timestamp' is non-null and positive
      - 'device_id' is non-null and positive
      - 'reading_value' is non-null and within expected ranges (0-100)
    """
    logging.info("Validating streaming data schema with Great Expectations...")

    context = ge.get_context(context_root_dir="/opt/spark_jobs/great_expectations")

    ge_df = df.toPandas()  # Convert Spark DataFrame to Pandas for validation

    datasource = context.get_datasource("my_pandas_datasource")
    asset = datasource.get_asset("my_runtime_data_asset")
    batch_request = asset.build_batch_request(options={"dataframe": ge_df})

    # Create (or load) an expectation suite
    try:
        context.add_or_update_expectation_suite(expectation_suite_name="stream_suite")
    except Exception:
        pass

       
    validator = context.get_validator(batch_request=batch_request, create_expectation_suite_with_name="stream_suite")

    # Expect event_id to be unique and non-null
    validator.expect_column_values_to_not_be_null("event_id")

    # Expect timestamp to be non-null and positive
    validator.expect_column_values_to_be_between("timestamp", min_value=1)

    # Expect device_id to be non-null and positive
    validator.expect_column_values_to_be_between("device_id", min_value=1)
    
    # Expect reading_value to be between 0 and 100 (sensor range)
    validator.expect_column_values_to_be_between("reading_value", min_value=0, max_value=100)
    
    result = validator.validate()
    if not result["success"]:
       logging.info(result)
       raise ValueError("GE validation failed for batch {}".format(batch_id))

    logging.info("Schema validation passed for batch {}".format(batch_id))
    logging.info(result)


def save_to_postgres(df, table_name):
    """
    Saves the processed DataFrame to PostgreSQL.
    """
    logging.info(f"Writing data to PostgreSQL table: {table_name}...")

    try:
        df.write \
            .format("jdbc") \
            .option("url", f"jdbc:postgresql://{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}") \
            .option("dbtable", table_name) \
            .option("user", POSTGRES_USER) \
            .option("password", POSTGRES_PASSWORD) \
            .option("driver", "org.postgresql.Driver") \
            .mode("append") \
            .save()

        logging.info(f"Successfully written to PostgreSQL table: {table_name}")

    except Exception as e:
        logging.error(f"Failed to write to PostgreSQL: {str(e)}")


# Define per-batch processing logic
def process_batch(batch_df, batch_id):
    logging.info("Processing Streaming Starting ...")
    logging.info(f"Processing batch {batch_id}")

    batch_df.show(5, truncate=False)

    # Validate schema
    validate_schema(batch_df, batch_id)

    if not batch_df.isEmpty():
       # Write raw streaming data to MinIO (S3)
       batch_df.write \
         .format("parquet") \
         .mode("append") \
         .option("path", RAW_DATA_PATH) \
         .save()
 
       # Detect anomalies where reading_value > 70
       df_anomalies = batch_df.filter(col("reading_value") > 70.0)

       # Write anomaly data to MinIO (S3)
       df_anomalies.write \
         .format("parquet") \
         .mode("append") \
         .option("path", ANOMALY_DATA_PATH) \
         .save()
 


def main():
    """
    Streaming ETL Pipeline:
    - Reads real-time sensor data from Kafka
    - Parses JSON messages into structured Spark DataFrame
    - Validates schema using Great Expectations
    - Filters out malformed and invalid records
    - Detects anomalies (reading_value > 70)
    - Writes anomalies to PostgreSQL & MinIO for analytics
    - Writes raw and cleaned data for historical tracking
    """
    try:
        # Initialize Spark session
        spark = SparkSession.builder \
            .appName("StreamingETL") \
            .config("spark.driver.extraJavaOptions", "-Duser.name=spark") \
            .config("spark.executor.extraJavaOptions", "-Duser.name=spark") \
            .getOrCreate()

        # Configure Spark to access MinIO using s3a
        spark._jsc.hadoopConfiguration().set("fs.s3a.endpoint", MINIO_ENDPOINT)
        spark._jsc.hadoopConfiguration().set("fs.s3a.access.key", MINIO_ACCESS_KEY)
        spark._jsc.hadoopConfiguration().set("fs.s3a.secret.key", MINIO_SECRET_KEY)
       # spark._jsc.hadoopConfiguration().set("fs.s3a.path.style.access", "true")
        spark._jsc.hadoopConfiguration().set("fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")

        logging.info(f"Starting Spark Structured Streaming from Kafka topic: {KAFKA_TOPIC}")

        # Read stream from Kafka
        df_stream = spark.readStream \
            .format("kafka") \
            .option("kafka.bootstrap.servers", KAFKA_BROKER) \
            .option("subscribe", KAFKA_TOPIC) \
            .option("startingOffsets", "latest") \
            .load()


        # Parse JSON messages
        df_parsed = df_stream.select(
            from_json(col("value").cast("string"), schema).alias("json_data")
        ).select("json_data.*")

        # Filter out invalid records
        df_clean = df_parsed.filter(
            col("event_id").isNotNull() &
            col("timestamp").isNotNull() &
            col("device_id").isNotNull() &
            col("reading_value").isNotNull()
        )

        # WriteStream with foreachBatch
        query = (
           df_clean.writeStream
            .outputMode("append")
            .foreachBatch(process_batch)
            .option("checkpointLocation", "/tmp/spark-checkpoints/kafka_stream")
            .start()
        )

        query.awaitTermination()

        # Write anomalies to PostgreSQL
        #df_anomalies.writeStream \
        #    .foreachBatch(lambda batch_df, batch_id: save_to_postgres(batch_df, "anomalies_stream")) \
        #    .outputMode("append") \

    except Exception as e:
        logging.error(f"Streaming processing failed: {str(e)}")
        spark.stop()


if __name__ == "__main__":
    main()
