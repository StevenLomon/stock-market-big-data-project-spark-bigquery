/*This query calculates the percentage growth of the closing prices for each company over the dataset's time span, 
allowing us to compare their performance.*/
WITH price_growth AS (
  SELECT 
    'Google' AS company,
    (MAX(close) - MIN(close)) / MIN(close) * 100 AS growth_percentage
  FROM `your_project.your_dataset.google_table`
  UNION ALL
  SELECT 
    'Microsoft' AS company,
    (MAX(close) - MIN(close)) / MIN(close) * 100 AS growth_percentage
  FROM `your_project.your_dataset.microsoft_table`
  UNION ALL
  SELECT 
    'Apple' AS company,
    (MAX(close) - MIN(close)) / MIN(close) * 100 AS growth_percentage
  FROM `your_project.your_dataset.apple_table`
)
SELECT * FROM price_growth;
