/* 
Created by: Steven Lomon Lennartsson
Create date: 9/28/2024

This query computes the percentage growth of closing prices over the entire dataset for each company. It 
can help visualize long-term performance comparisons. The query calculates the percentage growth of the 
closing prices for each company over the dataset's time span, allowing you to compare their performance.The 
max close and min close as shown as well.
*/
WITH price_growth AS (
  SELECT 
    'Google' AS company,
    MAX(close) AS max_close,
    MIN(close) AS min_close,
    (MAX(close) - MIN(close)) / MIN(close) * 100 AS growth_percentage
  FROM `stock_market_data.google_stock_data_v2`
  UNION ALL
  SELECT 
    'Microsoft' AS company,
    MAX(close) AS max_close,
    MIN(close) AS min_close,
    (MAX(close) - MIN(close)) / MIN(close) * 100 AS growth_percentage
  FROM `stock_market_data.microsoft_stock_data_v2`
  UNION ALL
  SELECT 
    'Apple' AS company,
    MAX(close) AS max_close,
    MIN(close) AS min_close,
    (MAX(close) - MIN(close)) / MIN(close) * 100 AS growth_percentage
  FROM `stock_market_data.apple_stock_data_v2`
)
SELECT * FROM price_growth ORDER BY price_growth.growth_percentage DESC;