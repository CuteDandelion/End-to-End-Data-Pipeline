FROM apache/airflow:3.1.1rc1-python3.13

USER root
RUN apt-get update && apt-get install -y gcc libpq-dev

USER airflow

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Baked DAGs, plugins, Great Expectations into image
COPY dags /opt/airflow/dags
COPY plugins /opt/airflow/plugins
COPY great_expectations /opt/airflow/great_expectations

# The default entrypoint/cmd from apache/airflow will start the scheduler/webserver
