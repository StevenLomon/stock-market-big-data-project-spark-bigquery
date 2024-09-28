/* 
Created by: Steven Lomon Lennartsson
Create date: 9/28/2024

This query identifies the top 10 days with the highest combined trading volume across the three companies.
*/

WITH combined_volume AS (
  SELECT 
    date,
    SUM(volume) AS total_volume
  FROM (
    SELECT date, volume FROM `stock_market_data.google_stock_data_v2`
    UNION ALL
    SELECT date, volume FROM `stock_market_data.microsoft_stock_data_v2`
    UNION ALL
    SELECT date, volume FROM `stock_market_data.apple_stock_data_v2`
  )
  GROUP BY date
)
SELECT 
  date,
  total_volume
FROM combined_volume
ORDER BY total_volume DESC
LIMIT 10;
