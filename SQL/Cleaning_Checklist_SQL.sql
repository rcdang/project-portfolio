
-- **SQL Cleaning Checklist**
-- **Goal:** Detect and correct records that are corrupt, inaccurate, incomplete, irrelevant, or improperly formatted to improve data quality; (Data Cleansing/Scrubbing) 
-- 
-- *Out of Scope:* Reshaping the dataset through joining, grouping, aggregating, stacking, pivot/unpivoting, or deriving new features for a data model or report; (Data Transformation/Data Wrangling/Munging) 
-- 
-- *Note: All functions using Standard SQL unless otherwise notated* 


-- **Table of Contents**
-- 1. Column Profiling
-- 2. Missing Data
-- 3. Duplicate Data
-- 4. Correct Data Types
-- 5. Numeric Data
-- 6. Text Data
-- 7. Date and Time Data
-- 8. Categorical Data
-- 9. Validate


-- **Column Profiling**


-- Numeric Profile


-- Numeric Profile
SELECT 
    COUNT(*) AS row_count, 
    COUNT(product_id) AS non_null_count, 
    COUNT(*) - COUNT(product_id) AS null_count, 
    COUNT(DISTINCT product_id) AS distinct_count, 
    COUNT(product_name) - COUNT(DISTINCT product_name) AS dupe_count,
    MIN(product_id) AS column_min, 
    MAX(product_id) AS column_max, 
    ROUND(AVG(product_id),2) AS column_mean


-- VARCHAR Profile


-- VARCHAR Profile
SELECT 
    COUNT(*) AS row_count, 
    COUNT(product_name) AS non_null_count, 
    COUNT(*) - COUNT(product_name) AS null_count, 
    COUNT(DISTINCT product_name) AS distinct_count, 
    COUNT(product_name) - COUNT(DISTINCT product_name) AS dupe_count,
    MIN(CHAR_LENGTH(product_name)) AS column_len_min, 
    MAX(CHAR_LENGTH(product_name)) AS column_len_max 


-- Distribution & Frequency 


-- Distribution & Frequency 
SELECT 
    product_name,
    COUNT(product_name) AS non_null_count,
    ROUND(COUNT(product_name)*100.0 / (SELECT COUNT(product_name) FROM your_table_name),2) AS frequency
FROM 
    your_table_name
GROUP BY 
    product_name
ORDER BY 
    non_null_count DESC


-- **Filtering**


-- Multiple WHERE criteria, single table


-- Note: operators [>,<,=,!=,<=,>=] exclude NULLS from output unless IS NULL is specified 

SELECT
    VisitID,
    PatientID,
    VisitDate,
    DiagnosisCode,
    DischargeSummary,
    PrimaryPhysicianID
FROM
    Patient_Visits
WHERE
    -- 1. visits in last decade with assigned physician 
    VisitDate >= DATE '2020-01-01'
    AND PrimaryPhysicianID IS NOT NULL 
    
    -- 2. Criteria for specific patient populations 
    AND (
        -- Group A: Patients with critical or chronic conditions
        DiagnosisCode IN ('I50.9', 'J44.9', 'E10.9') -- Congestive Heart Failure, COPD, Type 1 Diabetes
        
        -- OR Group B: Patients who required a Discharge Summary (indicating a stay/complex visit)
        OR DischargeSummary IS NOT NULL 
    )
    -- 3. visits with no recorded follow ups and exclude standard screening z-codes
    AND (
        FollowUpAppointmentDate IS NULL 
        AND DiagnosisCode NOT LIKE '%Z%' 
    )

ORDER BY
    VisitDate DESC;


-- Filter current table with criteria from another


-- EXISTS: Patients with at least one recorded visit
SELECT
    patientID
FROM 
    patients AS p
WHERE EXISTS
    (SELECT 1
    FROM visits AS v
    WHERE v.patientID = p.patientID)

-- NOT EXISTS: Filter for Patients NOT assigned to a nurse
SELECT
    patientID
FROM 
    patients AS p
WHERE NOT EXISTS
    (SELECT 1
    FROM nurses AS n
    WHERE n.patientID = p.patientID);

/*
EXISTS can be more efficient, especially with large tables, because it stops processing the subquery as soon as a match is found. Handling NULL Values: NOT EXISTS handles NULL values more predictably than NOT IN. If the subquery in a NOT IN clause returns any NULL values, the entire outer query might return no rows, which can lead to unexpected results. NOT EXISTS avoids this issue.
*/


-- Filter current table with base table criteria and criteria from one or more other tables


-- EXISTS: Filter for patients that have visited since 2026 and have an active status, in that execution order 
SELECT
    patientID
FROM 
    patients AS p
WHERE 
    p.IsActive = 1
    
    AND EXISTS
    (SELECT 1
    FROM visits AS v
    WHERE v.patientID = p.patientID
    AND v.visitDate >= DATE '2026-01-01');

-- NOT EXISTS: Filter for patients not assigned to an ER nurse, assigned to a bed,  with status as Inpatient, in that execution order 
SELECT 
    patientID
FROM 
    patients AS p
WHERE 
    p.status = 'Inpatient'

    AND NOT EXISTS
    (SELECT 1
    FROM nurses AS n
    WHERE n.patientID = p.patientID
    AND n.classification = 'ER');

    AND EXISTS
    (SELECT 1
    FROM assignments AS a
    WHERE a.patientID = p.patientID
    AND a.resource_type = 'bed');


-- **Missing Data**


-- Identify NULLs 


-- Identify NULLs 
SELECT 
COUNT(*) AS row_count, 
COUNT(product_name) AS non_null_count, 
(COUNT(*) - COUNT(product_name)) AS null_count


-- Impute NULLs


-- Impute NULLs with default value, similar imputation with AVERAGE(), median, or mode
SELECT
    COALESCE(string_column, 'N/A') AS cleaned_string_column,
    COALESCE(numeric_column, 0) AS cleaned_numeric_column,
    COALESCE(boolean_column, FALSE) AS cleaned_boolean_column,


-- Forward Fill or Backward Fill


-- Forward fill, IGNORE NULLS function in most databases except for MS SQL Server < 2022, MySQL and PostgreSQL
SELECT
    chronological_column,
    measure_column,
    COALESCE(measure_column, LAG(measure_column,1) IGNORE NULLS OVER (ORDER BY chronological_column ASC)) AS prev_non_null

-- Backward fill (same as forward fill when ordered DESC), IGNORE NULLS function in most databases except for MS SQL Server < 2022, MySQL and PostgreSQL
SELECT
    chronological_column,
    measure_column,
    COALESCE(measure_column, LEAD(measure_column,1) IGNORE NULLS OVER (ORDER BY chronological_column DESC)) AS prev_non_null


-- Flag NULLs


-- Flag a column has NULL value by creating a separate binary flag column
SELECT 
    column_1,
    CASE WHEN column_1 IS NULL THEN 0 ELSE 1 END AS null_flag


-- Filter Out NULLs


-- Filter out Rows with Excessive NULLs (if imputation is not suitable)
SELECT *
FROM
    your_table_name
WHERE
    column_name_1 IS NOT NULL
    AND column_name_2 IS NOT NULL
    AND column_name_3 IS NOT NULL; 


-- **Duplicate Data**
-- 
-- * "Unique": That row or combination of columns only appearing once in the dataset. This implies there are no other duplicate instances of that specific row or combination.
-- * "Distinct": One value from each group, including truly unique values. This means if a combination appears 5 times, you get one instance of it. If it appears 1 time (truly unique), you also get that one instance.


-- GROUP BY for Unique, Distinct, and Distribution


/* 
Option 1 - Unique and Distinct row/combinations with GROUP BY 
- [PREMIUM] Value Distribution AND
- [PREMIUM] Truly unique rows, appearing only once in data set AND
- Be able to customize "uniqueness" and "distinctness" by selecting combinations OR
- Entirely distinct Rows 
*/

SELECT
    colA,
    colB,
    colC,
    COUNT(*) AS group_count
FROM
    your_table_name
GROUP BY
    colA,
    colB,
    colC
-- HAVING COUNT(*) = 1
ORDER BY 
    group_count DESC;


-- ROW_NUMBER for Ordered, Distinct Records


/* 
Option 2 - Ordered, distinct row/combinations with ROW_NUMBER()
- [PREMIUM] Be able to select all columns from the table AND
- [PREMIUM] Be able to choose which row to keep if there are duplicates such as the most recent occurrence AND 
- Be able to customize "distinctness" by selecting distinct combinations OR
- Entirely distinct rows 
*/

WITH subquery_alias AS 
    (
        SELECT
            *, -- Or list all relevant columns
            ROW_NUMBER() OVER (PARTITION BY colA, colB, colC /* ... columns defining "distinctness" */ ORDER BY (colA DESC)) as rn
            -- ORDER BY clause: pick most recent, last, etc with ASC/DESC
        FROM
            your_table_name
    )
SELECT
    colA,
    colB,
    colC
FROM subquery_alias
WHERE
    rn = 1; -- > 1 for just duplicates


-- COUNT over windows for Relative Frequencies and custom Count filtering


/* 
Option 3 - Identify dupes while retaining all rows with COUNT(*) OVER(PARTITION BY...) 
- [PREMIUM] Calculations between rows and groups (like % frequency)
- [PREMIUM] Be able to filter rows based on group properties
- [PREMIUM] Be able to select all columns from the table AND
- Be able to customize "uniqueness" by selecting combinations
- Add ORDER BY to get running counts/other aggregates (limitation: groups ties together)
*/

WITH SubQueryAlias AS
(
    SELECT
        *,
        COUNT(*) OVER(PARTITION BY colA) AS colA_count,
        COUNT(*) OVER(PARTITION BY colB) AS colB_count
    FROM your_table_name
) 
SELECT 
    colA, colB, colC
FROM
    SubQueryAlias
WHERE 
    colA_2015_count > 1 AND colB_count = 1;


-- **Data Type Conversion**


-- Integer, float, and boolean conversions


SELECT
    CAST(string_as_int_column AS INTEGER) AS converted_int_column,
    CAST(string_as_float_column AS FLOAT) AS converted_float_column,
    CAST(numeric_as_boolean_column AS BOOLEAN) AS converted_boolean_column, -- 0:FALSE, 1:TRUE.
    TRY_CONVERT(DATE, string_as_date_column, 120) -- T-SQL Only, Date style yyyy-mm-dd = 120	
    TRY_CONVERT(DATETIME2, string_as_timestamp_column, 120) -- T-SQL Only, Date style yyyy-mm-dd = 120	


-- String to Date Conversions in T-SQL: TRY_CONVERT 


SELECT 
    DateString,
    CASE
        -- 1. Unambiguous ISO 8601 (yyyy-mm-ddT...) - Style 126
        WHEN TRY_CONVERT(DATE, DateString, 126) IS NOT NULL THEN TRY_CONVERT(DATE, DateString, 126)
        
        -- 2. Standard Numeric Formats
        -- yyyy-mm-dd (unseparated/separated) - Style 112
        WHEN TRY_CONVERT(DATE, DateString, 112) IS NOT NULL THEN TRY_CONVERT(DATE, DateString, 112)
        -- yyyy/mm/dd - Style 111
        WHEN TRY_CONVERT(DATE, DateString, 111) IS NOT NULL THEN TRY_CONVERT(DATE, DateString, 111)
        
        -- 3. US Formats (mm/dd/yyyy) - Style 101, 110
        WHEN TRY_CONVERT(DATE, DateString, 101) IS NOT NULL THEN TRY_CONVERT(DATE, DateString, 101)
        WHEN TRY_CONVERT(DATE, DateString, 110) IS NOT NULL THEN TRY_CONVERT(DATE, DateString, 110)

        -- 4. European Formats (dd/mm/yyyy) - Style 103, 105
        WHEN TRY_CONVERT(DATE, DateString, 103) IS NOT NULL THEN TRY_CONVERT(DATE, DateString, 103)
        WHEN TRY_CONVERT(DATE, DateString, 105) IS NOT NULL THEN TRY_CONVERT(DATE, DateString, 105)

        -- 5. Text/Abbreviated Formats
        -- Mon dd, yyyy (The format you asked about) - Style 107
        WHEN TRY_CONVERT(DATE, DateString, 107) IS NOT NULL THEN TRY_CONVERT(DATE, DateString, 107)
        -- dd mon yyyy - Style 106
        WHEN TRY_CONVERT(DATE, DateString, 106) IS NOT NULL THEN TRY_CONVERT(DATE, DateString, 106)

        -- 6. Fallback (If the string is already in an acceptable ISO/Unambiguous format)
        WHEN TRY_CONVERT(DATE, DateString) IS NOT NULL THEN TRY_CONVERT(DATE, DateString)

        -- 7. If all conversions fail
        ELSE NULL 
    END AS ConvertedDate


-- String to Date Conversions (SAFE.PARSE_DATE)


-- Handle multiple date formats using CASE
-- SAFE.PARSE_DATE is a non-standard SQL function (e.g., BigQuery)
-- ISO 8601 Date Only YYYY-MM-DD

SELECT
    CASE
        -- Format 1: YYYY-MM-DD
        WHEN SAFE.PARSE_DATE('%Y-%m-%d', mixed_date_string) IS NOT NULL
            THEN SAFE.PARSE_DATE('%Y-%m-%d', mixed_date_string)
        -- Format 2: MM-DD-YYYY
        WHEN SAFE.PARSE_DATE('%m-%d-%Y', mixed_date_string) IS NOT NULL
            THEN SAFE.PARSE_DATE('%m-%d-%Y', mixed_date_string)
        -- Format 3: DD-MM-YYYY
        WHEN SAFE.PARSE_DATE('%d-%m-%Y', mixed_date_string) IS NOT NULL
            THEN SAFE.PARSE_DATE('%d-%m-%Y', mixed_date_string)
        -- Format 4: YYYY/MM/DD
        WHEN SAFE.PARSE_DATE('%Y/%m/%d', mixed_date_string) IS NOT NULL
            THEN SAFE.PARSE_DATE('%Y/%m/%d', mixed_date_string)
        -- Format 5: MM/DD/YYYY
        WHEN SAFE.PARSE_DATE('%m/%d/%Y', mixed_date_string) IS NOT NULL
            THEN SAFE.PARSE_DATE('%m/%d/%Y', mixed_date_string)
        -- Format 6: DD/MM/YYYY
        WHEN SAFE.PARSE_DATE('%d/%m/%Y', mixed_date_string) IS NOT NULL
            THEN SAFE.PARSE_DATE('%d/%m/%Y', mixed_date_string)
        ELSE NULL -- If none of the above formats match
    END AS robust_date_parsing


-- String to DATETIME2 Conversions in T-SQL: TRY_CONVERT 


SELECT 
    DateTimeString,
    CASE
        -- 1. International/Unambiguous Formats (Best to try first)
        -- ISO 8601 with 'T' (Web standard) - Style 126
        WHEN TRY_CONVERT(DATETIME2, DateTimeString, 126) IS NOT NULL THEN TRY_CONVERT(DATETIME2, DateTimeString, 126)
        -- ODBC Canonical (Standard SQL format) - Style 120
        WHEN TRY_CONVERT(DATETIME2, DateTimeString, 120) IS NOT NULL THEN TRY_CONVERT(DATETIME2, DateTimeString, 120)
        -- ODBC Canonical with milliseconds - Style 121
        WHEN TRY_CONVERT(DATETIME2, DateTimeString, 121) IS NOT NULL THEN TRY_CONVERT(DATETIME2, DateTimeString, 121)

        -- 2. Text/Abbreviated Formats
        -- mon dd yyyy hh:miAM/PM - Style 100
        WHEN TRY_CONVERT(DATETIME2, DateTimeString, 100) IS NOT NULL THEN TRY_CONVERT(DATETIME2, DateTimeString, 100)
        -- mon dd yyyy hh:mi:ss:mmmAM/PM - Style 109
        WHEN TRY_CONVERT(DATETIME2, DateTimeString, 109) IS NOT NULL THEN TRY_CONVERT(DATETIME2, DateTimeString, 109)

        -- 3. Regional Formats (These can be ambiguous, so placed lower)
        -- US mm/dd/yyyy with time - Style 101
        WHEN TRY_CONVERT(DATETIME2, DateTimeString, 101) IS NOT NULL THEN TRY_CONVERT(DATETIME2, DateTimeString, 101)
        -- British/French dd/mm/yyyy with time - Style 103
        WHEN TRY_CONVERT(DATETIME2, DateTimeString, 103) IS NOT NULL THEN TRY_CONVERT(DATETIME2, DateTimeString, 103)

        -- 4. Fallback (Plain CONVERT without style; depends on server's SET LANGUAGE)
        WHEN TRY_CONVERT(DATETIME2, DateTimeString) IS NOT NULL THEN TRY_CONVERT(DATETIME2, DateTimeString)

        -- 5. If all conversions fail
        ELSE NULL 
    END AS ConvertedTimestamp
FROM 
    YourTimestampTable;

-- Note: For time zone (e.g., '2025-09-23T17:52:48.500+05:00'), change target data type to DATETIMEOFFSET and use style codes like 127 or 130/131


-- String to Timestamp Conversions in BigQuery (SAFE.PARSE_TIMESTAMP)


-- Handle multiple timestamp formats using CASE
-- SAFE.PARSE_TIMESTAMP is a non-standard SQL function (e.g., BigQuery)
-- ISO 8601 Timestamp Only YYYY-MM-DD HH:MM:SS

SELECT
    CASE
        -- Format 1: YYYY-MM-DD HH:MI:SS
        WHEN SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', mixed_timestamp_string) IS NOT NULL
            THEN SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', mixed_timestamp_string)
        -- Format 2: MM-DD-YYYY HH:MI:SS
        WHEN SAFE.PARSE_TIMESTAMP('%m-%d-%Y %H:%M:%S', mixed_timestamp_string) IS NOT NULL
            THEN SAFE.PARSE_TIMESTAMP('%m-%d-%Y %H:%M:%S', mixed_timestamp_string)
        -- Format 3: DD-MM-YYYY HH:MI:SS
        WHEN SAFE.PARSE_TIMESTAMP('%d-%m-%Y %H:%M:%S', mixed_timestamp_string) IS NOT NULL
            THEN SAFE.PARSE_TIMESTAMP('%d-%m-%Y %H:%M:%S', mixed_timestamp_string)
        -- Format 4: YYYY/MM/DD HH:MI:SS
        WHEN SAFE.PARSE_TIMESTAMP('%Y/%m/%d %H:%M:%S', mixed_timestamp_string) IS NOT NULL
            THEN SAFE.PARSE_TIMESTAMP('%Y/%m/%d %H:%M:%S', mixed_timestamp_string)
        -- Format 5: MM/DD/YYYY HH:MI:SS
        WHEN SAFE.PARSE_TIMESTAMP('%m/%d/%Y %H:%M:%S', mixed_timestamp_string) IS NOT NULL
            THEN SAFE.PARSE_TIMESTAMP('%m/%d/%Y %H:%M:%S', mixed_timestamp_string)
        -- Format 6: DD/MM/YYYY HH:MI:SS
        WHEN SAFE.PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', mixed_timestamp_string) IS NOT NULL
            THEN SAFE.PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', mixed_timestamp_string)
        ELSE NULL -- If none of the above formats match
    END AS robust_timestamp_parsing


-- **Numeric Data**


-- Floor, Ceiling, & NULL Imputation 


-- Assign NULL to negative values that shouldn't be negative, like age
-- Assign a floor or ceiling value past a threshold. The threshold could be a percentile using PERCENTILE_CONT()
SELECT
    CASE
        WHEN age_column < 0 THEN NULL ELSE age_column END AS cleaned_age_column,


-- Identifying or Filtering Out Outliers 


-- Removing Outliers above or below percentiles
WITH PercentileBounds AS 
(
    SELECT
        PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY numeric_column) OVER () AS lower_bound,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY numeric_column) OVER () AS upper_bound
    FROM
        your_table_name
    WHERE
        numeric_column IS NOT NULL -- Percentile_CONT typically ignore NULLs, explicit filtering anyway                                 
)
SELECT
    t.id,
    t.numeric_column
FROM
    your_table_name AS t 
CROSS JOIN 
    PercentileBounds AS pb -- join single-row result to all rows of main table with cross-join
WHERE
    t.numeric_column >= pb.lower_bound
    AND t.numeric_column <= pb.upper_bound;


-- **Text Data**


-- Extract characters Relative to Position


-- Extract the first 5 characters from the 'string_column'
SELECT 
    LEFT(string_column, 5) AS prefix

-- Extract the last 5 characters from the 'string_column'
SELECT 
    RIGHT(string_column, 5) AS suffix

-- Extract 5th character to the end characters from the 'string_column'
SELECT 
    SUBSTRING(string_column FROM 5) AS 5_to_end,
    SUBSTRING(string_column, 5) AS 5_to_end -- T-SQL

-- Extract up to certain character 
SELECT 
    SUBSTRING(Email FROM 1 FOR POSITION('@' IN Email) - 1) AS username
    SUBSTRING(Email, 1, CHARINDEX('@', Email) - 1) AS username --T-SQL

-- Extract string length
SELECT
    CHAR_LENGTH(string_column) AS num_of_characters


-- Remove Whitespace or Substrings


-- Remove leading, trailing, or excessive internal whitespace
SELECT
    TRIM(string_column) AS trimmed_string

-- Remove Substring
SELECT 
    REPLACE(string_column,'extra words','') AS cleaned_text


-- Remove All Punctuation (Non-Standard SQL)


-- T-SQL; Remove Non-Alphanumeric Characters
SELECT
    OriginalText,
    TRANSLATE(OriginalText, '.,!?:;''"-()', '') AS PunctuationFreeText

-- PostgreSQL, BigQuery; Remove Non-Alphanumeric Characters, Keep only letters, numbers, and spaces
SELECT
    REGEXP_REPLACE(string_column, r'[^a-zA-Z0-9\s]', '') AS alphanumeric_only_string

-- PostgreSQL, BigQuery; international character friendly
SELECT
    REGEXP_REPLACE(string_column, r'[^\p{L}\p{N}\s]', '') AS unicode_alphanumeric_only_string 


-- Replace Substring or Multiple character list


-- Replace Substring
SELECT 
    REPLACE(string_column,'word to replace','replaced') AS cleaned_text

-- T-SQL: map characters in first with second, shorthand SQL case statement, "I have a cab." --> "I h1ve 1 312."
SELECT
    TRANSLATE(OriginalText, 'abc', '123') AS PunctuationFreeText



-- Letter Case


-- Standardize Case into Upper/Lower/Proper 
SELECT
    UPPER(string_column) AS uppercase_string,
    LOWER(string_column) AS lowercase_string,
    -- For proper case (first letter capitalized, rest lowercase)
    CONCAT(UPPER(SUBSTRING(string_column, 1, 1)), LOWER(SUBSTRING(string_column, 2))) AS proper_case_string


-- **Date and Time Data**


-- Extract date parts


-- Extracting parts from a DATE
SELECT
    EXTRACT(YEAR FROM date_column) AS invoice_year,
    EXTRACT(MONTH FROM date_column) AS invoice_month,
    EXTRACT(DAY FROM date_column) AS invoice_day,
    EXTRACT(WEEK FROM date_column) AS week_of_year,
    EXTRACT(QUARTER FROM date_column) AS quarter_of_year


-- Extract timestamp parts



-- Extracting parts from a TIMESTAMP
SELECT
    EXTRACT(YEAR FROM timestamp_column) AS event_year,
    EXTRACT(MONTH FROM timestamp_column) AS event_month,
    EXTRACT(DAY FROM timestamp_column) AS event_day,
    EXTRACT(HOUR FROM timestamp_column) AS event_hour,
    EXTRACT(MINUTE FROM timestamp_column) AS event_minute,
    EXTRACT(SECOND FROM timestamp_column) AS event_second_with_fractions,
    EXTRACT(WEEK FROM timestamp_column) AS event_week,
    EXTRACT(QUARTER FROM timestamp_column) AS event_quarter


-- Extract Current date or datetime2/timestamp


SELECT
    CURRENT_DATE AS date_today, -- or T-SQL GETDATE()

SELECT
    CURRENT_TIMESTAMP AS timestamp_today


-- **Categorical Data**


-- Clean categories 


-- Correct Inconsistent Categorical Values (Mapping/Standardization)
SELECT
    CASE
        WHEN country_column IN ('USA', 'U.S.A.', 'United States') THEN 'United States'
        WHEN country_column IN ('UK', 'U.K.', 'United Kingdom') THEN 'United Kingdom'
        ELSE country_column
    END AS standardized_country


-- Clean Booleans


-- Ensure boolean values are consistently represented (e.g., TRUE/FALSE, 1/0)
SELECT
    id,
    CASE
        WHEN is_active_column IN ('true', '1', 'yes') THEN TRUE
        WHEN is_active_column IN ('false', '0', 'no') THEN FALSE
        ELSE NULL -- Or a default boolean value
    END AS standardized_is_active


-- **Validate**


-- Within Range


-- Ranges of numeric or data values 
SELECT
    *
FROM
    your_table_name
WHERE
    age_column BETWEEN 0 AND 120 -- Age must be between 0 and 120
    AND price_column >= 0; -- Price cannot be negative


-- Unique & Distinct Values


-- Unique & Distinct Values 
SELECT
    colA,
    colB,
    colC,
    COUNT(*) AS group_count
FROM
    your_table_name
GROUP BY
    colA,
    colB,
    colC
-- HAVING COUNT(*) = 1
ORDER BY group_count ASC;


-- Referential Integrity


-- Referential Integrity: ensure every foreign key record has a matching primary key in the primary table
SELECT
    ct.*
FROM
    child_table ct
LEFT JOIN
    parent_table pt ON ct.parent_id = pt.id
WHERE
    pt.id IS NULL;


-- Logical 


--Logic: birth_date < admission_date < discharge_date, etc
SELECT
    *
FROM
    your_table_name
WHERE
    start_date_column > end_date_column; -- Identify records where end date is before start date


-- IBM's Dimensions of Data Quality
-- 1. Accuracy: Is the data provably correct and does it reflect real-world knowledge?
-- 2. Completeness: Does the data comprise all relevant and available information? Are there missing data elements or blank fields?
-- 3. Consistency: Do corresponding data values match across locations and environments?
-- 4. Validity: Is data being collected in the correct format for its intended use?
-- 5. Uniqueness: Is data duplicated or overlapping with other data?
-- 6. Timeliness: Is data up to date and readily available when needed?
-- 
-- **A** **C**ar **C**an't **V**room **U**nless (It's) **T**rustworthy
-- 
-- IBM's Types of Data Integrity
-- * Preventing duplication (entity integrity)
-- * Dictating how data is stored and used (referential integrity)
-- * Preserving data in an acceptable format (domain integrity)
-- * Ensuring data meets an organization’s unique or industry-specific needs (user-defined integrity)
-- * Data Security 
-- 
-- [IBM on Data Quality & Integrity](<https://www.ibm.com/think/topics/data-integrity-vs-data-quality>) 


