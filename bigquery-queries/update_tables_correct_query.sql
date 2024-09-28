/* 
Created by: Steven Lomon Lennartsson
Create date: 9/28/2024

This query updates tables that are already in the data warehouse to follow a schema that doesn't require 
casting the date column every time we write queries
*/

-- Step 1: Create a new table with the updated schema. Change name of the company as needed
CREATE TABLE `stock_market_data.google_stock_data_v2` (
  date DATE,
  open FLOAT64,
  high FLOAT64,
  low FLOAT64,
  close FLOAT64,
  volume INT64
);

-- Step 2: Insert data from the old table, casting fields to match the new schema
INSERT INTO `stock_market_data.google_stock_data_v2`
SELECT
  CAST(date AS DATE) AS date,
  CAST(open AS FLOAT64) AS open,
  CAST(high AS FLOAT64) AS high,
  CAST(low AS FLOAT64) AS low,
  CAST(close AS FLOAT64) AS close,
  CAST(volume AS INT64) AS volume
FROM `stock_market_data.google_stock_data`;

-- Step 3: Validate and make sure the new table has the correct schema and data
SELECT * FROM `stock_market_data.google_stock_data_v2` LIMIT 10;