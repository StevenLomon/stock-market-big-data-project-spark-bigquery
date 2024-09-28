/* 
Created by: Steven Lomon Lennartsson
Create date: 9/28/2024

This query identifies the years with the highest and lowest average annual returns for each company. It finds the 
best and worst-performing years for each company based on average annual returns, allowing us to identify periods 
of maximum gain and loss.
*/

WITH annual_returns AS (
  SELECT 
    company,
    EXTRACT(YEAR FROM date) AS year,
    (MAX(close) - MIN(close)) / MIN(close) * 100 AS annual_return
  FROM (
    SELECT date, close, 'Google' AS company FROM `stock_market_data.google_stock_data_v2`
    UNION ALL
    SELECT date, close, 'Microsoft' AS company FROM `stock_market_data.microsoft_stock_data_v2`
    UNION ALL
    SELECT date, close, 'Apple' AS company FROM `stock_market_data.apple_stock_data_v2`
  )
  GROUP BY company, year
),
ranked_annual_returns AS (
  SELECT 
    company,
    year,
    annual_return,
    RANK() OVER (PARTITION BY company ORDER BY annual_return DESC) AS rank_performance
  FROM annual_returns
)
SELECT 
  company,
  year,
  annual_return
  --rank_performance
FROM ranked_annual_returns
WHERE rank_performance = 1 OR rank_performance = (SELECT MAX(rank_performance) FROM ranked_annual_returns a WHERE a.company = ranked_annual_returns.company); -- SELECT MAX(rank_performance) picks the worst year. Highest rank -> worst year
