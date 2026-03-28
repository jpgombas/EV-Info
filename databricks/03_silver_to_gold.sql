-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Silver → Gold: Aggregated Metrics & Dashboard Tables
-- MAGIC Pre-computes KPIs, daily/weekly/monthly rollups, and battery health trends.

-- COMMAND ----------

USE CATALOG ev_telemetry;
USE SCHEMA gold;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. Lifetime KPIs (Single-Row Summary)

-- COMMAND ----------

CREATE OR REPLACE TABLE ev_telemetry.gold.lifetime_kpis AS
WITH trip_totals AS (
  SELECT
    SUM(distance_miles)           AS total_miles,
    SUM(energy_consumed_kwh)      AS total_energy_consumed_kwh,
    SUM(energy_regen_kwh)         AS total_energy_regen_kwh,
    SUM(net_energy_kwh)           AS total_net_energy_kwh,
    SUM(hvac_energy_kwh)          AS total_hvac_energy_kwh,
    COUNT(*)                      AS total_trips,
    SUM(duration_minutes)         AS total_driving_minutes,
    AVG(efficiency_mi_per_kwh)    AS avg_efficiency,
    MAX(max_speed_mph)            AS top_speed_mph
  FROM ev_telemetry.silver.trips
  WHERE distance_miles > 0.1
),
charge_totals AS (
  SELECT
    SUM(energy_added_kwh)         AS total_energy_charged_kwh,
    COUNT(*)                      AS total_charge_sessions,
    SUM(duration_minutes)         AS total_charge_minutes
  FROM ev_telemetry.silver.charging_sessions
  WHERE duration_minutes > 1
),
battery_health AS (
  SELECT
    FIRST_VALUE(battery_capacity_ah) OVER (ORDER BY timestamp ASC)  AS initial_capacity_ah,
    FIRST_VALUE(battery_capacity_ah) OVER (ORDER BY timestamp DESC) AS latest_capacity_ah,
    FIRST_VALUE(battery_resistance_mohm) OVER (ORDER BY timestamp ASC)  AS initial_resistance_mohm,
    FIRST_VALUE(battery_resistance_mohm) OVER (ORDER BY timestamp DESC) AS latest_resistance_mohm
  FROM ev_telemetry.silver.vehicle_telemetry
  WHERE battery_capacity_ah IS NOT NULL AND battery_capacity_ah > 0
  LIMIT 1
)
SELECT
  -- Distance
  ROUND(t.total_miles, 1)                                         AS total_miles_driven,

  -- Energy
  ROUND(t.total_energy_consumed_kwh, 1)                           AS total_energy_consumed_kwh,
  ROUND(t.total_energy_regen_kwh, 1)                              AS total_energy_regen_kwh,
  ROUND(t.total_net_energy_kwh, 1)                                AS total_net_energy_kwh,
  ROUND(t.total_hvac_energy_kwh, 1)                               AS total_hvac_energy_kwh,
  ROUND(c.total_energy_charged_kwh, 1)                            AS total_energy_charged_kwh,

  -- Efficiency
  ROUND(t.total_miles / NULLIF(t.total_net_energy_kwh, 0), 2)    AS lifetime_efficiency_mi_per_kwh,
  ROUND(t.avg_efficiency, 2)                                      AS avg_trip_efficiency_mi_per_kwh,

  -- Usage
  t.total_trips,
  ROUND(t.total_driving_minutes / 60.0, 1)                       AS total_driving_hours,
  ROUND(t.total_miles / NULLIF(t.total_trips, 0), 1)             AS avg_trip_distance_miles,
  t.top_speed_mph,

  -- Charging
  c.total_charge_sessions,
  ROUND(c.total_charge_minutes / 60.0, 1)                        AS total_charge_hours,

  -- Regen contribution
  ROUND(
    t.total_energy_regen_kwh / NULLIF(t.total_energy_consumed_kwh, 0) * 100, 1
  )                                                               AS regen_recovery_pct,

  -- HVAC as % of total energy
  ROUND(
    t.total_hvac_energy_kwh / NULLIF(t.total_energy_consumed_kwh, 0) * 100, 1
  )                                                               AS hvac_energy_pct,

  -- Battery health
  b.initial_capacity_ah,
  b.latest_capacity_ah,
  ROUND(
    (b.latest_capacity_ah / NULLIF(b.initial_capacity_ah, 0)) * 100, 1
  )                                                               AS battery_capacity_retention_pct,
  b.initial_resistance_mohm,
  b.latest_resistance_mohm,

  current_timestamp()                                             AS last_updated

FROM trip_totals t
CROSS JOIN charge_totals c
CROSS JOIN battery_health b;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. Daily Driving Summary

-- COMMAND ----------

CREATE OR REPLACE TABLE ev_telemetry.gold.daily_summary AS
SELECT
  date(trip_start)                                              AS drive_date,
  COUNT(*)                                                      AS trips,
  ROUND(SUM(distance_miles), 1)                                 AS miles_driven,
  ROUND(SUM(net_energy_kwh), 2)                                 AS net_energy_kwh,
  ROUND(SUM(energy_consumed_kwh), 2)                            AS energy_consumed_kwh,
  ROUND(SUM(energy_regen_kwh), 2)                               AS energy_regen_kwh,
  ROUND(SUM(hvac_energy_kwh), 2)                                AS hvac_energy_kwh,
  ROUND(
    SUM(distance_miles) / NULLIF(SUM(net_energy_kwh), 0), 2
  )                                                             AS efficiency_mi_per_kwh,
  ROUND(SUM(duration_minutes), 1)                               AS driving_minutes,
  ROUND(AVG(avg_speed_mph), 1)                                  AS avg_speed_mph,
  ROUND(AVG(avg_ambient_temp_f), 1)                             AS avg_ambient_temp_f,
  ROUND(AVG(avg_battery_temp_c), 1)                             AS avg_battery_temp_c,
  MAX(soc_start)                                                AS max_soc,
  MIN(soc_end)                                                  AS min_soc
FROM ev_telemetry.silver.trips
WHERE distance_miles > 0.1
GROUP BY date(trip_start)
ORDER BY drive_date;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Weekly Summary

-- COMMAND ----------

CREATE OR REPLACE TABLE ev_telemetry.gold.weekly_summary AS
SELECT
  date_trunc('week', drive_date)                                AS week_start,
  SUM(trips)                                                    AS trips,
  ROUND(SUM(miles_driven), 1)                                   AS miles_driven,
  ROUND(SUM(net_energy_kwh), 2)                                 AS net_energy_kwh,
  ROUND(
    SUM(miles_driven) / NULLIF(SUM(net_energy_kwh), 0), 2
  )                                                             AS efficiency_mi_per_kwh,
  ROUND(SUM(driving_minutes), 1)                                AS driving_minutes,
  ROUND(AVG(avg_speed_mph), 1)                                  AS avg_speed_mph,
  ROUND(AVG(avg_ambient_temp_f), 1)                             AS avg_ambient_temp_f
FROM ev_telemetry.gold.daily_summary
GROUP BY date_trunc('week', drive_date)
ORDER BY week_start;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 4. Monthly Summary

-- COMMAND ----------

CREATE OR REPLACE TABLE ev_telemetry.gold.monthly_summary AS
SELECT
  date_trunc('month', drive_date)                               AS month_start,
  SUM(trips)                                                    AS trips,
  ROUND(SUM(miles_driven), 1)                                   AS miles_driven,
  ROUND(SUM(net_energy_kwh), 2)                                 AS net_energy_kwh,
  ROUND(SUM(energy_consumed_kwh), 2)                            AS energy_consumed_kwh,
  ROUND(SUM(energy_regen_kwh), 2)                               AS energy_regen_kwh,
  ROUND(SUM(hvac_energy_kwh), 2)                                AS hvac_energy_kwh,
  ROUND(
    SUM(miles_driven) / NULLIF(SUM(net_energy_kwh), 0), 2
  )                                                             AS efficiency_mi_per_kwh,
  ROUND(SUM(driving_minutes) / 60.0, 1)                        AS driving_hours,
  ROUND(AVG(avg_speed_mph), 1)                                  AS avg_speed_mph,
  ROUND(AVG(avg_ambient_temp_f), 1)                             AS avg_ambient_temp_f
FROM ev_telemetry.gold.daily_summary
GROUP BY date_trunc('month', drive_date)
ORDER BY month_start;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 5. Hourly Driving Patterns

-- COMMAND ----------

CREATE OR REPLACE TABLE ev_telemetry.gold.hourly_patterns AS
SELECT
  hour(trip_start)                              AS hour_of_day,
  COUNT(*)                                      AS trip_count,
  ROUND(AVG(distance_miles), 1)                 AS avg_distance_miles,
  ROUND(AVG(efficiency_mi_per_kwh), 2)          AS avg_efficiency,
  ROUND(AVG(avg_speed_mph), 1)                  AS avg_speed_mph,
  ROUND(AVG(duration_minutes), 1)               AS avg_duration_minutes
FROM ev_telemetry.silver.trips
WHERE distance_miles > 0.1
GROUP BY hour(trip_start)
ORDER BY hour_of_day;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 6. Battery Health Trend (Daily)

-- COMMAND ----------

CREATE OR REPLACE TABLE ev_telemetry.gold.battery_health_daily AS
SELECT
  date                                                  AS measure_date,
  ROUND(AVG(battery_capacity_ah), 2)                    AS avg_capacity_ah,
  ROUND(AVG(battery_resistance_mohm), 1)                AS avg_resistance_mohm,
  ROUND(AVG(battery_avg_temp_c), 1)                     AS avg_battery_temp_c,
  ROUND(MAX(battery_temp_spread_c), 1)                  AS max_temp_spread_c,
  ROUND(AVG(battery_coolant_temp_c), 1)                 AS avg_coolant_temp_c
FROM ev_telemetry.silver.vehicle_telemetry
WHERE battery_capacity_ah IS NOT NULL AND battery_capacity_ah > 0
GROUP BY date
ORDER BY measure_date;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 7. Efficiency by Temperature Bucket

-- COMMAND ----------

CREATE OR REPLACE TABLE ev_telemetry.gold.efficiency_by_temperature AS
SELECT
  CASE
    WHEN avg_ambient_temp_f < 20  THEN '< 20°F'
    WHEN avg_ambient_temp_f < 32  THEN '20-32°F'
    WHEN avg_ambient_temp_f < 50  THEN '32-50°F'
    WHEN avg_ambient_temp_f < 70  THEN '50-70°F'
    WHEN avg_ambient_temp_f < 85  THEN '70-85°F'
    WHEN avg_ambient_temp_f < 100 THEN '85-100°F'
    ELSE '100°F+'
  END                                                   AS temp_range,
  COUNT(*)                                              AS trip_count,
  ROUND(AVG(efficiency_mi_per_kwh), 2)                  AS avg_efficiency_mi_per_kwh,
  ROUND(AVG(distance_miles), 1)                         AS avg_distance_miles,
  ROUND(AVG(hvac_energy_kwh), 3)                        AS avg_hvac_energy_kwh,
  ROUND(
    AVG(hvac_energy_kwh) / NULLIF(AVG(net_energy_kwh), 0) * 100, 1
  )                                                     AS hvac_energy_pct
FROM ev_telemetry.silver.trips
WHERE distance_miles > 1 AND efficiency_mi_per_kwh IS NOT NULL
GROUP BY 1
ORDER BY
  CASE
    WHEN avg_ambient_temp_f < 20  THEN 1
    WHEN avg_ambient_temp_f < 32  THEN 2
    WHEN avg_ambient_temp_f < 50  THEN 3
    WHEN avg_ambient_temp_f < 70  THEN 4
    WHEN avg_ambient_temp_f < 85  THEN 5
    WHEN avg_ambient_temp_f < 100 THEN 6
    ELSE 7
  END;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 8. Efficiency by Speed Bucket

-- COMMAND ----------

CREATE OR REPLACE TABLE ev_telemetry.gold.efficiency_by_speed AS
SELECT
  CASE
    WHEN avg_speed_mph < 15 THEN '< 15 mph'
    WHEN avg_speed_mph < 25 THEN '15-25 mph'
    WHEN avg_speed_mph < 35 THEN '25-35 mph'
    WHEN avg_speed_mph < 45 THEN '35-45 mph'
    WHEN avg_speed_mph < 55 THEN '45-55 mph'
    WHEN avg_speed_mph < 65 THEN '55-65 mph'
    WHEN avg_speed_mph < 75 THEN '65-75 mph'
    ELSE '75+ mph'
  END                                                   AS speed_range,
  COUNT(*)                                              AS trip_count,
  ROUND(AVG(efficiency_mi_per_kwh), 2)                  AS avg_efficiency_mi_per_kwh,
  ROUND(AVG(distance_miles), 1)                         AS avg_distance_miles,
  ROUND(AVG(net_energy_kwh), 2)                         AS avg_net_energy_kwh,
  ROUND(AVG(energy_regen_kwh / NULLIF(energy_consumed_kwh, 0)) * 100, 1)
                                                        AS avg_regen_pct
FROM ev_telemetry.silver.trips
WHERE distance_miles > 1 AND efficiency_mi_per_kwh IS NOT NULL
GROUP BY 1
ORDER BY
  CASE
    WHEN avg_speed_mph < 15 THEN 1
    WHEN avg_speed_mph < 25 THEN 2
    WHEN avg_speed_mph < 35 THEN 3
    WHEN avg_speed_mph < 45 THEN 4
    WHEN avg_speed_mph < 55 THEN 5
    WHEN avg_speed_mph < 65 THEN 6
    WHEN avg_speed_mph < 75 THEN 7
    ELSE 8
  END;
