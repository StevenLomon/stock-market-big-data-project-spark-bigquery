/* 
Created by: Steven Lomon Lennartsson
Create date: 9/28/2024

This query creates a table with combined volume data to be explored in Looker Studio. The three columns are date, company
and volume.
*/

CREATE OR REPLACE TABLE `stock_market_data.combined_volume_data` AS
SELECT 
  DATE(date) AS date,
  'Google' AS company,
  volume AS volume
FROM 
  `stock_market_data.google_stock_data_v2`

UNION ALL

SELECT 
  DATE(date) AS date,
  'Microsoft' AS company,
  volume AS volume
FROM 
  `stock_market_data.microsoft_stock_data_v2`

UNION ALL

SELECT 
  DATE(date) AS date,
  'Apple' AS company,
  volume AS volume
FROM 
  `stock_market_data.apple_stock_data_v2`
ORDER BY 
  date ASC, company;
