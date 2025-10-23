FROM spark:3.5.2-java17-python3

USER root

# Install pip if missing, install Python packages
RUN apt-get update && apt-get install -y python3-pip \
    && pip3 install --no-cache-dir boto3 pandas great_expectations \
    && rm -rf /var/lib/apt/lists/*

# Add Kafka connector for Spark (ensure version matches Spark!)
RUN wget https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_2.12/3.5.2/spark-sql-kafka-0-10_2.12-3.5.2.jar -P $SPARK_HOME/jars
RUN wget https://repo1.maven.org/maven2/org/apache/kafka/kafka-clients/3.5.2/kafka-clients-3.5.2.jar -P $SPARK_HOME/jars

USER 1001
WORKDIR /opt/spark_jobs

COPY . /opt/spark_jobs

# Optional: default job
# CMD ["spark-submit", "/opt/spark_jobs/spark_batch_job.py"]
CMD ["tail", "-f", "/dev/null"]
