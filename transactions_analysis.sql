-- =====================================================================
-- Project 2: Sales Performance and Product Trend Analysis
-- Dataset: Credit Card Transactions (Priyam Choksi, Kaggle, Apache 2.0)
-- Engine:  SQLite, run in DB Browser for SQLite
-- Author:  Eric Benitez
--
-- FRAMING: this is consumer card-spending data. "amt" is the sales
-- measure, "category" is the product category, "state" is the region.
-- Fraudulent transactions (is_fraud = 1) are not revenue, so the clean
-- copy splits them and the sales aggregations run on legitimate spend
-- only. The fraud rate is reported separately in Part 4. The large
-- transaction amounts are concentrated in fraud, so separating fraud is
-- the deliberate alternative to clipping outliers.
-- =====================================================================

-- Step 1: Confirmed date format is correct so time based calculations are accurate
SELECT trans_date_trans_time
FROM credit_card_transactions
LIMIT 10;

-- Step 2: Validated date range across all 1,296,675 rows confirmed earliest transaction 2019-01-01 and latest 2020-06-21 so that calculations for "Total sales over time" are accurate. 
SELECT COUNT(*) AS total_rows,
       MIN(trans_date_trans_time) AS earliest,
       MAX(trans_date_trans_time) AS latest
FROM credit_card_transactions;

-- Step 3: Checked for missing merchant zip codes. Found 195,973 missing out of 1,296,675 rows so that Sales by region calculations are accurate.
SELECT count(*) AS total_rows,
		count(merch_zipcode) AS non_null_zips,
		count(*) - count(merch_zipcode) AS null_zips
FROM credit_card_transactions;

-- Step 4: baseline row count before cleaning
SELECT COUNT(*) AS total_rows_before_cleaning
FROM credit_card_transactions;

-- Step 5: Created clean copy of table dropping index column, retyping cc_num as text, and adding trans_month for grouping
DROP TABLE IF EXISTS transactions_clean;

CREATE TABLE transactions_clean AS
SELECT
    trans_date_trans_time                    AS trans_datetime,
    strftime('%Y-%m', trans_date_trans_time) AS trans_month,
    CAST(cc_num AS TEXT)                     AS cc_num,
    merchant,
    category,
    amt,
    city,
    state,
    is_fraud
FROM credit_card_transactions;

-- Step 6: Confirmed clean copy row count matches baseline so no rows were lost during cleaning
SELECT COUNT(*) AS rows_after_cleaning
FROM transactions_clean;

-- Step 7: Total sales by month on legitimate transactions only so fraud is not counted as revenue
SELECT trans_month,
       ROUND(SUM(amt), 2) AS total_sales,
       COUNT(*)           AS transaction_count
FROM transactions_clean
WHERE is_fraud = 0
GROUP BY trans_month
ORDER BY trans_month;

-- Step 8: Sales by product category on legitimate transactions only so spend by category is accurate
SELECT category,
       ROUND(SUM(amt), 2) AS total_sales,
       COUNT(*)           AS transaction_count,
       ROUND(AVG(amt), 2) AS avg_order_value
FROM transactions_clean
WHERE is_fraud = 0
GROUP BY category
ORDER BY total_sales DESC;

-- Step 9: Sales by state on legitimate transactions only so regional analysis uses complete data
SELECT state,
       ROUND(SUM(amt), 2) AS total_sales,
       COUNT(*)           AS transaction_count
FROM transactions_clean
WHERE is_fraud = 0
GROUP BY state
ORDER BY total_sales DESC;

-- Step 10: Headline numbers for dashboard cards including total sales, average order value, and unique customers
SELECT ROUND(AVG(amt), 2)     AS average_order_value,
       ROUND(SUM(amt), 2)     AS total_sales,
       COUNT(*)               AS transaction_count,
       COUNT(DISTINCT cc_num) AS unique_customers
FROM transactions_clean
WHERE is_fraud = 0;

-- Step 11: New customers per month using each cardholders first transaction date
WITH first_seen AS (
    SELECT cc_num,
           MIN(trans_month) AS first_month
    FROM transactions_clean
    GROUP BY cc_num
)
SELECT first_month AS acquisition_month,
       COUNT(*)    AS new_customers
FROM first_seen
GROUP BY first_month
ORDER BY first_month;

-- Step 12: Overall fraud rate across all transactions so legitimate spend and fraud are clearly separated
SELECT COUNT(*)                                   AS total_transactions,
       SUM(is_fraud)                              AS fraud_transactions,
       ROUND(100.0 * SUM(is_fraud) / COUNT(*), 3) AS fraud_rate_pct
FROM transactions_clean;

-- Step 13: Fraud rate by category so where fraud concentrates by merchant type is visible
SELECT category,
       COUNT(*)                                                  AS total_transactions,
       SUM(is_fraud)                                             AS fraud_transactions,
       ROUND(100.0 * SUM(is_fraud) / COUNT(*), 3)               AS fraud_rate_pct,
       ROUND(SUM(CASE WHEN is_fraud = 1 THEN amt ELSE 0 END), 2) AS fraud_dollar_amount
FROM transactions_clean
GROUP BY category
ORDER BY fraud_rate_pct DESC;