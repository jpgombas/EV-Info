-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Bronze → Silver: Clean & Enrich Telemetry
-- MAGIC Deduplicates, validates, and computes derived fields from raw OBD2 data.

-- COMMAND ----------

USE CATALOG ev_telemetry;
USE SCHEMA silver;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. Cleaned Vehicle Telemetry

-- COMMAND ----------

CREATE OR REPLACE TABLE ev_telemetry.silver.vehicle_telemetry AS
WITH deduplicated AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY timestamp
      ORDER BY _ingested_at DESC
    ) AS _row_num
  FROM ev_telemetry.bronze.raw_vehicle_data
  WHERE timestamp IS NOT NULL
)
SELECT
  id,
  timestamp,
  date(timestamp)                                     AS date,
  hour(timestamp)                                     AS hour,
  dayofweek(timestamp)                                AS day_of_week,

  -- State of charge
  soc,
  soc_hd,

  -- Speed (convert km/h → mph for consistency with distance)
  speed_kmh,
  ROUND(speed_kmh * 0.621371, 1)                      AS speed_mph,

  -- Battery electrical
  current_amps,
  voltage_volts,
  ROUND(current_amps * voltage_volts / 1000.0, 3)     AS power_kw,

  -- Drivetrain power (total power minus HVAC)
  ROUND(
    (current_amps * voltage_volts / 1000.0)
    - COALESCE(hvac_measured_power_w, 0) / 1000.0,
    3
  )                                                    AS drivetrain_power_kw,

  -- Distance
  distance_mi,

  -- Temperatures
  ambient_temp_f,
  ROUND((ambient_temp_f - 32) * 5.0 / 9.0, 1)        AS ambient_temp_c,
  battery_avg_temp_c,
  battery_max_temp_c,
  battery_min_temp_c,
  battery_coolant_temp_c,
  ROUND(battery_max_temp_c - battery_min_temp_c, 1)   AS battery_temp_spread_c,

  -- HVAC
  hvac_measured_power_w,
  ROUND(hvac_measured_power_w / 1000.0, 3)             AS hvac_power_kw,
  hvac_commanded_power_w,
  ac_compressor_on,

  -- Battery health
  battery_capacity_ah,
  battery_resistance_mohm,

  -- Efficiency: mi/kWh (only when driving forward and consuming power)
  CASE
    WHEN speed_kmh > 3
     AND current_amps * voltage_volts / 1000.0 > 0.5
    THEN ROUND(
      (speed_kmh * 0.621371) / (current_amps * voltage_volts / 1000.0),
      2
    )
  END                                                  AS instant_efficiency_mi_per_kwh,

  -- Is vehicle moving?
  speed_kmh > 0                                        AS is_moving,

  -- Is vehicle charging? (negative current = regen or charging)
  current_amps < -1.0 AND speed_kmh = 0                AS is_charging,

  -- Is regenerative braking?
  current_amps < -1.0 AND speed_kmh > 0                AS is_regen,

  _ingested_at

FROM deduplicated
WHERE _row_num = 1
  AND (speed_kmh IS NULL OR speed_kmh BETWEEN 0 AND 200)
  AND (voltage_volts IS NULL OR voltage_volts BETWEEN 200 AND 450)
  AND (soc IS NULL OR soc BETWEEN 0 AND 100);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. Trip Detection
-- MAGIC Groups consecutive driving periods into trips based on time gaps.

-- COMMAND ----------

CREATE OR REPLACE TABLE ev_telemetry.silver.trips AS
WITH movement AS (
  SELECT *,
    LAG(timestamp) OVER (ORDER BY timestamp) AS prev_ts,
    LEAD(timestamp) OVER (ORDER BY timestamp) AS next_ts
  FROM ev_telemetry.silver.vehicle_telemetry
  WHERE is_moving = true
),
trip_boundaries AS (
  SELECT *,
    CASE
      WHEN prev_ts IS NULL
        OR unix_timestamp(timestamp) - unix_timestamp(prev_ts) > 300
      THEN 1 ELSE 0
    END AS is_trip_start
  FROM movement
),
trip_ids AS (
  SELECT *,
    SUM(is_trip_start) OVER (ORDER BY timestamp) AS trip_id
  FROM trip_boundaries
)
SELECT
  trip_id,
  MIN(timestamp)                                               AS trip_start,
  MAX(timestamp)                                               AS trip_end,
  ROUND((unix_timestamp(MAX(timestamp)) - unix_timestamp(MIN(timestamp))) / 60.0, 1)
                                                               AS duration_minutes,
  COUNT(*)                                                     AS sample_count,

  -- Distance: difference in odometer between first and last reading
  ROUND(MAX(distance_mi) - MIN(distance_mi), 2)               AS distance_miles,

  -- Energy: integrate power over time (sum of power_kw * sample_interval)
  ROUND(
    SUM(
      CASE WHEN power_kw > 0 THEN
        power_kw * (unix_timestamp(timestamp) - unix_timestamp(prev_ts)) / 3600.0
      ELSE 0 END
    ), 3
  )                                                            AS energy_consumed_kwh,

  -- Regen energy recovered
  ROUND(
    SUM(
      CASE WHEN power_kw < 0 THEN
        ABS(power_kw) * (unix_timestamp(timestamp) - unix_timestamp(prev_ts)) / 3600.0
      ELSE 0 END
    ), 3
  )                                                            AS energy_regen_kwh,

  -- HVAC energy
  ROUND(
    SUM(
      COALESCE(hvac_power_kw, 0) * (unix_timestamp(timestamp) - unix_timestamp(prev_ts)) / 3600.0
    ), 3
  )                                                            AS hvac_energy_kwh,

  -- Speed stats
  ROUND(AVG(speed_mph), 1)                                     AS avg_speed_mph,
  MAX(speed_mph)                                                AS max_speed_mph,

  -- SOC change
  FIRST_VALUE(soc_hd) OVER (PARTITION BY trip_id ORDER BY timestamp)  AS soc_start,
  LAST_VALUE(soc_hd) OVER (
    PARTITION BY trip_id ORDER BY timestamp
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
  )                                                            AS soc_end,

  -- Temperature
  ROUND(AVG(ambient_temp_f), 1)                                AS avg_ambient_temp_f,
  ROUND(AVG(battery_avg_temp_c), 1)                            AS avg_battery_temp_c

FROM trip_ids
GROUP BY trip_id;

-- COMMAND ----------

-- Update trip-level efficiency
ALTER TABLE ev_telemetry.silver.trips ADD COLUMNS IF NOT EXISTS (
  efficiency_mi_per_kwh DOUBLE COMMENT 'Trip efficiency (mi/kWh)',
  net_energy_kwh        DOUBLE COMMENT 'Net energy (consumed - regen)',
  soc_used              DOUBLE COMMENT 'SOC percentage consumed'
);

-- COMMAND ----------

MERGE INTO ev_telemetry.silver.trips AS t
USING (
  SELECT
    trip_id,
    CASE WHEN energy_consumed_kwh > 0 AND distance_miles > 0.1
      THEN ROUND(distance_miles / energy_consumed_kwh, 2)
    END AS efficiency_mi_per_kwh,
    ROUND(energy_consumed_kwh - energy_regen_kwh, 3) AS net_energy_kwh,
    ROUND(soc_start - soc_end, 2) AS soc_used
  FROM ev_telemetry.silver.trips
) AS src
ON t.trip_id = src.trip_id
WHEN MATCHED THEN UPDATE SET
  t.efficiency_mi_per_kwh = src.efficiency_mi_per_kwh,
  t.net_energy_kwh = src.net_energy_kwh,
  t.soc_used = src.soc_used;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Charging Sessions

-- COMMAND ----------

CREATE OR REPLACE TABLE ev_telemetry.silver.charging_sessions AS
WITH charging AS (
  SELECT *,
    LAG(timestamp) OVER (ORDER BY timestamp) AS prev_ts
  FROM ev_telemetry.silver.vehicle_telemetry
  WHERE is_charging = true
),
charge_boundaries AS (
  SELECT *,
    CASE
      WHEN prev_ts IS NULL
        OR unix_timestamp(timestamp) - unix_timestamp(prev_ts) > 300
      THEN 1 ELSE 0
    END AS is_session_start
  FROM charging
),
session_ids AS (
  SELECT *,
    SUM(is_session_start) OVER (ORDER BY timestamp) AS session_id
  FROM charge_boundaries
)
SELECT
  session_id,
  MIN(timestamp)                                        AS charge_start,
  MAX(timestamp)                                        AS charge_end,
  ROUND((unix_timestamp(MAX(timestamp)) - unix_timestamp(MIN(timestamp))) / 60.0, 1)
                                                        AS duration_minutes,
  COUNT(*)                                              AS sample_count,

  -- SOC change
  MIN(soc_hd)                                           AS soc_start,
  MAX(soc_hd)                                           AS soc_end,
  ROUND(MAX(soc_hd) - MIN(soc_hd), 2)                  AS soc_gained,

  -- Power stats (charging = negative current, so negate for positive kW)
  ROUND(AVG(ABS(power_kw)), 2)                          AS avg_charge_rate_kw,
  ROUND(MAX(ABS(power_kw)), 2)                          AS peak_charge_rate_kw,

  -- Energy added (integrate abs power over time)
  ROUND(
    SUM(
      ABS(power_kw) * (unix_timestamp(timestamp) - unix_timestamp(prev_ts)) / 3600.0
    ), 3
  )                                                     AS energy_added_kwh,

  -- Temperature during charge
  ROUND(AVG(battery_avg_temp_c), 1)                     AS avg_battery_temp_c

FROM session_ids
GROUP BY session_id;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 4. Verify Silver Tables

-- COMMAND ----------

SELECT 'vehicle_telemetry' AS table_name, count(*) AS rows FROM ev_telemetry.silver.vehicle_telemetry
UNION ALL
SELECT 'trips', count(*) FROM ev_telemetry.silver.trips
UNION ALL
SELECT 'charging_sessions', count(*) FROM ev_telemetry.silver.charging_sessions;
