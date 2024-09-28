WITH daily_percentage_change AS (
  SELECT 
    date,
    company,
    close,
    LAG(close) OVER (PARTITION BY company ORDER BY date) AS prev_close,
    (close - LAG(close) OVER (PARTITION BY company ORDER BY date)) / LAG(close) OVER (PARTITION BY company ORDER BY date) * 100 AS daily_change
  FROM (
    SELECT date, close, 'Google' AS company FROM `stock_market_data.google_stock_data`
    UNION ALL
    SELECT date, close, 'Microsoft' AS company FROM `stock_market_data.microsoft_stock_data`
    UNION ALL
    SELECT date, close, 'Apple' AS company FROM `stock_market_data.apple_stock_data`
  )
)
SELECT date, 
       COUNT(DISTINCT company) AS num_companies_with_drop,
       ARRAY_AGG(STRUCT(company, daily_change)) AS companies_with_drop
FROM daily_percentage_change
WHERE daily_change < -2
GROUP BY date
HAVING COUNT(DISTINCT company) = 3
ORDER BY date;
