# Databricks notebook source
# MAGIC %md
# MAGIC # EV-Info Data Ingestion Pipeline
# MAGIC Ingests raw telemetry data from a 2023 Chevy Bolt EV OBD2 sensor into Delta Lake.
# MAGIC
# MAGIC **Data sources:**
# MAGIC - CSV files uploaded to Unity Catalog Volume
# MAGIC - JSON files uploaded to Unity Catalog Volume
# MAGIC - Direct SQL inserts from the iOS app
# MAGIC
# MAGIC **Target:** `ev_telemetry.bronze.raw_vehicle_data`

# COMMAND ----------

# MAGIC %md
# MAGIC ## 1. Configuration

# COMMAND ----------

CATALOG = "ev_telemetry"
SCHEMA_BRONZE = "bronze"
SCHEMA_SILVER = "silver"
SCHEMA_GOLD = "gold"

# Volume path where iOS app uploads CSV/JSON files
VOLUME_PATH = f"/Volumes/{CATALOG}/{SCHEMA_BRONZE}/raw_uploads"

# COMMAND ----------

# MAGIC %md
# MAGIC ## 2. Create Catalog and Schemas

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE CATALOG IF NOT EXISTS ev_telemetry;
# MAGIC USE CATALOG ev_telemetry;
# MAGIC
# MAGIC CREATE SCHEMA IF NOT EXISTS bronze COMMENT 'Raw ingested telemetry data';
# MAGIC CREATE SCHEMA IF NOT EXISTS silver COMMENT 'Cleaned and enriched telemetry data';
# MAGIC CREATE SCHEMA IF NOT EXISTS gold   COMMENT 'Aggregated metrics and dashboard tables';

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE VOLUME IF NOT EXISTS ev_telemetry.bronze.raw_uploads
# MAGIC COMMENT 'Landing zone for CSV/JSON uploads from iOS app';

# COMMAND ----------

# MAGIC %md
# MAGIC ## 3. Define Bronze Table Schema

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE TABLE IF NOT EXISTS ev_telemetry.bronze.raw_vehicle_data (
# MAGIC   id                      STRING        COMMENT 'Unique record UUID from iOS app',
# MAGIC   timestamp               TIMESTAMP     COMMENT 'Measurement time (ISO8601)',
# MAGIC   soc                     DOUBLE        COMMENT 'Displayed state of charge (%)',
# MAGIC   speed_kmh               INT           COMMENT 'Vehicle speed (km/h)',
# MAGIC   current_amps            DOUBLE        COMMENT 'HV battery current (A, signed)',
# MAGIC   voltage_volts           DOUBLE        COMMENT 'HV battery voltage (V)',
# MAGIC   distance_mi             DOUBLE        COMMENT 'Distance since DTC cleared (mi)',
# MAGIC   ambient_temp_f          DOUBLE        COMMENT 'Ambient temperature (°F)',
# MAGIC   soc_hd                  DOUBLE        COMMENT 'High-resolution SOC (%)',
# MAGIC   battery_avg_temp_c      DOUBLE        COMMENT 'Battery average temperature (°C)',
# MAGIC   battery_max_temp_c      DOUBLE        COMMENT 'Battery maximum temperature (°C)',
# MAGIC   battery_min_temp_c      DOUBLE        COMMENT 'Battery minimum temperature (°C)',
# MAGIC   battery_coolant_temp_c  DOUBLE        COMMENT 'Battery coolant temperature (°C)',
# MAGIC   hvac_measured_power_w   DOUBLE        COMMENT 'HVAC measured power draw (W)',
# MAGIC   hvac_commanded_power_w  DOUBLE        COMMENT 'HVAC commanded power (W)',
# MAGIC   ac_compressor_on        BOOLEAN       COMMENT 'A/C compressor active',
# MAGIC   battery_capacity_ah     DOUBLE        COMMENT 'Battery capacity (Ah)',
# MAGIC   battery_resistance_mohm DOUBLE        COMMENT 'Battery internal resistance (mΩ)',
# MAGIC   _ingested_at            TIMESTAMP     DEFAULT current_timestamp() COMMENT 'Ingestion timestamp',
# MAGIC   _source_file            STRING        COMMENT 'Source file path for file-based ingestion'
# MAGIC )
# MAGIC USING DELTA
# MAGIC COMMENT 'Raw OBD2 telemetry from 2023 Chevy Bolt EV'
# MAGIC TBLPROPERTIES (
# MAGIC   'delta.autoOptimize.optimizeWrite' = 'true',
# MAGIC   'delta.autoOptimize.autoCompact' = 'true'
# MAGIC );

# COMMAND ----------

# MAGIC %md
# MAGIC ## 4. Ingest CSV Files (Auto Loader)

# COMMAND ----------

from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType, StructField, StringType, DoubleType,
    IntegerType, BooleanType, TimestampType
)

csv_schema = StructType([
    StructField("timestamp", StringType()),
    StructField("soc", DoubleType()),
    StructField("speed_kmh", IntegerType()),
    StructField("current_amps", DoubleType()),
    StructField("voltage_volts", DoubleType()),
    StructField("distance_mi", DoubleType()),
    StructField("ambient_temp_f", DoubleType()),
    StructField("soc_hd", DoubleType()),
    StructField("battery_avg_temp_c", DoubleType()),
    StructField("battery_max_temp_c", DoubleType()),
    StructField("battery_min_temp_c", DoubleType()),
    StructField("battery_coolant_temp_c", DoubleType()),
    StructField("hvac_measured_power_w", DoubleType()),
    StructField("hvac_commanded_power_w", DoubleType()),
    StructField("ac_compressor_on", BooleanType()),
    StructField("battery_capacity_ah", DoubleType()),
    StructField("battery_resistance_mohm", DoubleType()),
])

# COMMAND ----------

# Auto Loader: incrementally ingest new CSV files as they arrive
csv_stream = (
    spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "csv")
    .option("cloudFiles.schemaLocation", f"{VOLUME_PATH}/_csv_schema")
    .option("header", "true")
    .option("inferSchema", "false")
    .schema(csv_schema)
    .load(f"{VOLUME_PATH}/vehicle_data_*.csv")
    .withColumn("timestamp", F.to_timestamp("timestamp"))
    .withColumn("id", F.expr("uuid()"))
    .withColumn("_ingested_at", F.current_timestamp())
    .withColumn("_source_file", F.input_file_name())
)

(
    csv_stream.writeStream
    .format("delta")
    .outputMode("append")
    .option("checkpointLocation", f"{VOLUME_PATH}/_csv_checkpoint")
    .option("mergeSchema", "true")
    .trigger(availableNow=True)
    .toTable("ev_telemetry.bronze.raw_vehicle_data")
)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 5. Ingest JSON Files (Auto Loader)

# COMMAND ----------

json_stream = (
    spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.schemaLocation", f"{VOLUME_PATH}/_json_schema")
    .load(f"{VOLUME_PATH}/vehicle_data_*.json")
    .select(
        F.expr("uuid()").alias("id"),
        F.to_timestamp("timestamp").alias("timestamp"),
        F.col("soc").cast("double"),
        F.col("speed_kmh").cast("int"),
        F.col("current_amps").cast("double"),
        F.col("voltage_volts").cast("double"),
        F.col("distance_mi").cast("double"),
        F.col("ambient_temp_f").cast("double"),
        F.col("soc_hd").cast("double"),
        F.col("battery_avg_temp_c").cast("double"),
        F.col("battery_max_temp_c").cast("double"),
        F.col("battery_min_temp_c").cast("double"),
        F.col("battery_coolant_temp_c").cast("double"),
        F.col("hvac_measured_power_w").cast("double"),
        F.col("hvac_commanded_power_w").cast("double"),
        F.col("ac_compressor_on").cast("boolean"),
        F.col("battery_capacity_ah").cast("double"),
        F.col("battery_resistance_mohm").cast("double"),
    )
    .withColumn("_ingested_at", F.current_timestamp())
    .withColumn("_source_file", F.input_file_name())
)

(
    json_stream.writeStream
    .format("delta")
    .outputMode("append")
    .option("checkpointLocation", f"{VOLUME_PATH}/_json_checkpoint")
    .option("mergeSchema", "true")
    .trigger(availableNow=True)
    .toTable("ev_telemetry.bronze.raw_vehicle_data")
)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 6. Verify Ingestion

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT
# MAGIC   count(*)          AS total_records,
# MAGIC   min(timestamp)    AS earliest,
# MAGIC   max(timestamp)    AS latest,
# MAGIC   count(DISTINCT date(timestamp)) AS days_of_data
# MAGIC FROM ev_telemetry.bronze.raw_vehicle_data;

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Recent data sample
# MAGIC SELECT * FROM ev_telemetry.bronze.raw_vehicle_data
# MAGIC ORDER BY timestamp DESC
# MAGIC LIMIT 20;
