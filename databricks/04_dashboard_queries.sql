-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Dashboard Queries
-- MAGIC Ready-to-use queries for Databricks SQL Dashboard widgets.
-- MAGIC Each query corresponds to a dashboard tile.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## KPI Scorecards

-- COMMAND ----------

-- Widget: Lifetime KPI Cards
-- Type: Counter / Stat tiles
SELECT
  total_miles_driven,
  lifetime_efficiency_mi_per_kwh,
  total_net_energy_kwh,
  total_trips,
  total_driving_hours,
  avg_trip_distance_miles,
  top_speed_mph,
  regen_recovery_pct,
  hvac_energy_pct,
  battery_capacity_retention_pct,
  total_charge_sessions,
  total_energy_charged_kwh
FROM ev_telemetry.gold.lifetime_kpis;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Efficiency Over Time

-- COMMAND ----------

-- Widget: Daily Efficiency Trend
-- Type: Line chart (X: drive_date, Y: efficiency_mi_per_kwh)
SELECT
  drive_date,
  efficiency_mi_per_kwh,
  miles_driven,
  net_energy_kwh,
  avg_ambient_temp_f
FROM ev_telemetry.gold.daily_summary
WHERE efficiency_mi_per_kwh IS NOT NULL
ORDER BY drive_date;

-- COMMAND ----------

-- Widget: Weekly Efficiency Trend
-- Type: Line chart (X: week_start, Y: efficiency_mi_per_kwh)
SELECT
  week_start,
  efficiency_mi_per_kwh,
  miles_driven,
  trips
FROM ev_telemetry.gold.weekly_summary
ORDER BY week_start;

-- COMMAND ----------

-- Widget: Monthly Efficiency + Distance
-- Type: Combo chart (bar: miles_driven, line: efficiency_mi_per_kwh)
SELECT
  date_format(month_start, 'yyyy-MM')  AS month,
  efficiency_mi_per_kwh,
  miles_driven,
  net_energy_kwh,
  driving_hours,
  trips
FROM ev_telemetry.gold.monthly_summary
ORDER BY month_start;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Energy Analysis

-- COMMAND ----------

-- Widget: Daily Energy Breakdown
-- Type: Stacked bar chart
SELECT
  drive_date,
  energy_consumed_kwh,
  energy_regen_kwh,
  hvac_energy_kwh,
  net_energy_kwh - hvac_energy_kwh AS drivetrain_energy_kwh
FROM ev_telemetry.gold.daily_summary
ORDER BY drive_date;

-- COMMAND ----------

-- Widget: Energy Sankey / Pie
-- Type: Pie chart showing where energy goes
SELECT
  ROUND(SUM(net_energy_kwh) - SUM(hvac_energy_kwh), 1) AS drivetrain_kwh,
  ROUND(SUM(hvac_energy_kwh), 1)                        AS hvac_kwh,
  ROUND(SUM(energy_regen_kwh), 1)                       AS regen_recovered_kwh
FROM ev_telemetry.gold.daily_summary;

-- COMMAND ----------

-- Widget: Cumulative Distance Over Time
-- Type: Area chart
SELECT
  drive_date,
  SUM(miles_driven) OVER (ORDER BY drive_date) AS cumulative_miles,
  SUM(net_energy_kwh) OVER (ORDER BY drive_date) AS cumulative_energy_kwh
FROM ev_telemetry.gold.daily_summary
ORDER BY drive_date;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Temperature Impact

-- COMMAND ----------

-- Widget: Efficiency vs Temperature
-- Type: Bar chart (X: temp_range, Y: avg_efficiency_mi_per_kwh)
SELECT
  temp_range,
  trip_count,
  avg_efficiency_mi_per_kwh,
  avg_hvac_energy_kwh,
  hvac_energy_pct
FROM ev_telemetry.gold.efficiency_by_temperature;

-- COMMAND ----------

-- Widget: Efficiency vs Speed
-- Type: Bar chart (X: speed_range, Y: avg_efficiency_mi_per_kwh)
SELECT
  speed_range,
  trip_count,
  avg_efficiency_mi_per_kwh,
  avg_regen_pct
FROM ev_telemetry.gold.efficiency_by_speed;

-- COMMAND ----------

-- Widget: Daily Efficiency colored by Temperature
-- Type: Scatter plot (X: avg_ambient_temp_f, Y: efficiency_mi_per_kwh, size: miles_driven)
SELECT
  drive_date,
  avg_ambient_temp_f,
  efficiency_mi_per_kwh,
  miles_driven
FROM ev_telemetry.gold.daily_summary
WHERE efficiency_mi_per_kwh IS NOT NULL;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Battery Health

-- COMMAND ----------

-- Widget: Battery Capacity Trend
-- Type: Line chart (X: measure_date, Y: avg_capacity_ah)
SELECT
  measure_date,
  avg_capacity_ah,
  avg_resistance_mohm
FROM ev_telemetry.gold.battery_health_daily
ORDER BY measure_date;

-- COMMAND ----------

-- Widget: Battery Temperature Over Time
-- Type: Line chart with band (min/max/avg)
SELECT
  measure_date,
  avg_battery_temp_c,
  max_temp_spread_c,
  avg_coolant_temp_c
FROM ev_telemetry.gold.battery_health_daily
ORDER BY measure_date;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Driving Patterns

-- COMMAND ----------

-- Widget: When Do You Drive?
-- Type: Bar chart (X: hour_of_day, Y: trip_count)
SELECT
  hour_of_day,
  trip_count,
  avg_distance_miles,
  avg_efficiency,
  avg_speed_mph
FROM ev_telemetry.gold.hourly_patterns
ORDER BY hour_of_day;

-- COMMAND ----------

-- Widget: Day of Week Distribution
-- Type: Bar chart
SELECT
  CASE day_of_week
    WHEN 1 THEN 'Sunday'
    WHEN 2 THEN 'Monday'
    WHEN 3 THEN 'Tuesday'
    WHEN 4 THEN 'Wednesday'
    WHEN 5 THEN 'Thursday'
    WHEN 6 THEN 'Friday'
    WHEN 7 THEN 'Saturday'
  END AS day_name,
  day_of_week,
  COUNT(DISTINCT date) AS days_with_driving,
  ROUND(AVG(instant_efficiency_mi_per_kwh), 2) AS avg_efficiency,
  ROUND(AVG(speed_mph), 1) AS avg_speed_mph
FROM ev_telemetry.silver.vehicle_telemetry
WHERE is_moving = true
GROUP BY day_of_week
ORDER BY day_of_week;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Trip Explorer

-- COMMAND ----------

-- Widget: Trip List (detail table)
-- Type: Table with drill-down
SELECT
  trip_id,
  trip_start,
  trip_end,
  duration_minutes,
  ROUND(distance_miles, 1)          AS distance_miles,
  efficiency_mi_per_kwh,
  ROUND(net_energy_kwh, 2)          AS net_energy_kwh,
  ROUND(energy_regen_kwh, 2)        AS energy_regen_kwh,
  ROUND(hvac_energy_kwh, 2)         AS hvac_energy_kwh,
  ROUND(avg_speed_mph, 1)           AS avg_speed_mph,
  max_speed_mph,
  ROUND(soc_start, 1)              AS soc_start_pct,
  ROUND(soc_end, 1)                AS soc_end_pct,
  ROUND(soc_used, 1)               AS soc_used_pct,
  ROUND(avg_ambient_temp_f, 0)     AS ambient_temp_f,
  ROUND(avg_battery_temp_c, 0)     AS battery_temp_c
FROM ev_telemetry.silver.trips
WHERE distance_miles > 0.1
ORDER BY trip_start DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Charging Analysis

-- COMMAND ----------

-- Widget: Charging Session List
-- Type: Table
SELECT
  session_id,
  charge_start,
  charge_end,
  duration_minutes,
  ROUND(soc_start, 1)              AS soc_start_pct,
  ROUND(soc_end, 1)                AS soc_end_pct,
  ROUND(soc_gained, 1)             AS soc_gained_pct,
  ROUND(avg_charge_rate_kw, 1)     AS avg_charge_kw,
  ROUND(peak_charge_rate_kw, 1)    AS peak_charge_kw,
  ROUND(energy_added_kwh, 2)       AS energy_added_kwh,
  ROUND(avg_battery_temp_c, 0)     AS battery_temp_c
FROM ev_telemetry.silver.charging_sessions
WHERE duration_minutes > 1
ORDER BY charge_start DESC;

-- COMMAND ----------

-- Widget: Charging Speed by SOC Level
-- Type: Bar chart showing charge rate slows at higher SOC
SELECT
  CASE
    WHEN soc_start < 20 THEN '0-20%'
    WHEN soc_start < 40 THEN '20-40%'
    WHEN soc_start < 60 THEN '40-60%'
    WHEN soc_start < 80 THEN '60-80%'
    ELSE '80-100%'
  END AS starting_soc_range,
  COUNT(*) AS sessions,
  ROUND(AVG(avg_charge_rate_kw), 1) AS avg_charge_rate_kw,
  ROUND(AVG(peak_charge_rate_kw), 1) AS avg_peak_charge_rate_kw
FROM ev_telemetry.silver.charging_sessions
WHERE duration_minutes > 5
GROUP BY 1
ORDER BY
  CASE
    WHEN soc_start < 20 THEN 1
    WHEN soc_start < 40 THEN 2
    WHEN soc_start < 60 THEN 3
    WHEN soc_start < 80 THEN 4
    ELSE 5
  END;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Real-Time / Recent Activity

-- COMMAND ----------

-- Widget: Last 24 Hours Timeline
-- Type: Line chart (X: timestamp, Y: speed_mph + power_kw overlay)
SELECT
  timestamp,
  speed_mph,
  power_kw,
  soc_hd AS soc,
  battery_avg_temp_c,
  hvac_power_kw,
  instant_efficiency_mi_per_kwh
FROM ev_telemetry.silver.vehicle_telemetry
WHERE timestamp > current_timestamp() - INTERVAL 24 HOURS
ORDER BY timestamp;

-- COMMAND ----------

-- Widget: SOC Over Last 7 Days
-- Type: Area chart showing charge/discharge cycles
SELECT
  timestamp,
  soc_hd AS soc,
  is_charging,
  is_moving
FROM ev_telemetry.silver.vehicle_telemetry
WHERE timestamp > current_timestamp() - INTERVAL 7 DAYS
ORDER BY timestamp;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Cost Estimation (Configurable Rate)

-- COMMAND ----------

-- Widget: Estimated Electricity Cost
-- Adjust electricity_rate_per_kwh to your utility rate
WITH params AS (
  SELECT 0.12 AS electricity_rate_per_kwh  -- $/kWh, update to your rate
)
SELECT
  d.month_start,
  date_format(d.month_start, 'yyyy-MM') AS month,
  d.net_energy_kwh,
  ROUND(d.net_energy_kwh * p.electricity_rate_per_kwh, 2)      AS estimated_cost,
  ROUND(d.miles_driven / NULLIF(d.net_energy_kwh, 0), 2)       AS efficiency,
  ROUND(
    d.miles_driven / NULLIF(d.net_energy_kwh * p.electricity_rate_per_kwh, 0), 1
  )                                                              AS miles_per_dollar,
  -- Gas equivalent (assuming 30 mpg and $3.50/gal)
  ROUND(d.miles_driven / 30.0 * 3.50, 2)                       AS gas_equivalent_cost
FROM ev_telemetry.gold.monthly_summary d
CROSS JOIN params p
ORDER BY d.month_start;
