USE hospital_db;
GO
--------------------------------------------------------------------------------------------------
--Testing bronze.encounters table
SELECT TOP(1000) *
FROM bronze.encounters
SELECT COUNT(*)
FROM [bronze].[encounters]

--There are no NULLs or duplicated in the Id column
--But you need to account for that for any future changes


--encounters date range
SELECT MIN(START),
MAX(START)
FROM bronze.encounters

--encounter length
SELECT 
   START,
   STOP,
   DATEDIFF(MINUTE, START, STOP) AS DurationMinutes
FROM bronze.encounters
WHERE DATEDIFF(MINUTE, START, STOP) < 0
--There are no negative durations
--Is there outliers?
SELECT TOP(100)
	*,
   DATEDIFF(MINUTE, START, STOP) AS DurationMinutes
FROM bronze.encounters
ORDER BY DATEDIFF(MINUTE, START, STOP) DESC
--There are outlieres in the high side

--Calculating the IQR, Q1, AND Q3
WITH encounter_duration_upper_limit AS 
(
SELECT CEILING(Q3 + (1.5 * IQR)) AS UpperLimit
FROM
(
	SELECT DISTINCT
		PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY DurationMinutes) OVER() AS Q1,
		PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY DurationMinutes) OVER() AS Q3,
		PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY DurationMinutes) OVER()-
		PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY DurationMinutes) OVER()
		AS IQR
	FROM
	(
		SELECT  DATEDIFF(MINUTE, START, STOP) AS DurationMinutes
		FROM bronze.encounters
		) AS sub1
	) AS sub2
)
SELECT *,
	CASE WHEN DurationMinutes > encounter_duration_upper_limit.UpperLimit THEN encounter_duration_upper_limit.UpperLimit
		 WHEN DurationMinutes < 0 THEN 1
		 ELSE DurationMinutes END AS cleaned_duration
FROM
(
SELECT *,
   DATEDIFF(MINUTE, START, STOP) AS DurationMinutes
FROM bronze.encounters
) AS sub3
JOIN encounter_duration_upper_limit 
ON 1=1
ORDER BY cleaned_duration DESC

--How many NULL VALUES IN THE PAYER column
SELECT COUNT(*)
FROM bronze.encounters
WHERE PAYER IS NULL
--there are no null values in PAYER column


-- How many PAYER does not exist in the payer_id 
SELECT DISTINCT PAYER
FROM bronze.encounters
WHERE PAYER NOT IN
(
	SELECT DISTINCT payer_id
	FROM silver.payers
)

--There are 1 PAYER that does not exist in the payer_id column
--How many records does it have?

SELECT COUNT(*)
FROM bronze.encounters
WHERE PAYER =
(
	SELECT DISTINCT PAYER
	FROM bronze.encounters
	WHERE PAYER NOT IN
	(
		SELECT DISTINCT payer_id
		FROM silver.payers
	)
)
--It have 8807 records
--The payer_id will be added to the payers table


--ENCOUNTERCLASS
SELECT DISTINCT ENCOUNTERCLASS
FROM bronze.encounters
--just needs propper casing
--Exploring the CODE and DISCRIPTION columns
SELECT DISTINCT CODE , DESCRIPTION
FROM bronze.encounters
WHERE CODE IN
(
	SELECT DISTINCT CODE
	FROM(
		SELECT ROW_NUMBER() OVER(PARTITION BY CODE ORDER BY CODE) AS r
			,CODE,DESCRIPTION
		FROM
		(
			SELECT DISTINCT CODE,DESCRIPTION
			FROM bronze.encounters
			) AS sub1
	) AS sub2
	WHERE r>1
)
ORDER BY CODE

--Is there PAYER_COVERAGE more than TOTAL_CLAIM_COST?
SELECT  PAYER_COVERAGE,TOTAL_CLAIM_COST ,TOTAL_CLAIM_COST-PAYER_COVERAGE
FROM bronze.encounters
WHERE TOTAL_CLAIM_COST-PAYER_COVERAGE < 0
--No!!!!
--------------------------------------------------------------------------------------------------
--testing bronze.patients table
SELECT TOP(20) *
FROM bronze.patients
SELECT COUNT(*)
FROM bronze.patients

--There are no NULLs or duplicated in the Id column
--But you need to account for that for any future changes

--BIRTHDATE DEATHDATE rangeS?
SELECT MIN(BIRTHDATE) AS MinBirth,
	MAX(BIRTHDATE) AS MaxBirth,
	MIN(DEATHDATE)AS MinDeath,
	MAX(DEATHDATE) AS MaxDeath
FROM bronze.patients

--NULLs in BIRTHDATE
SELECT *
FROM bronze.patients
WHERE BIRTHDATE IS NULL

--PREFIX
SELECT DISTINCT PREFIX
FROM bronze.patients


--Does all Mrs. have a value in MAIDEN?
SELECT * 
FROM bronze.patients
WHERE PREFIX ='Mrs.' AND MAIDEN IS NULL 

--ALL MAIDEN NON NULL VALUES --> TRUE
--ALL MAIDEN     NULL VALUES --> FALSE

--SUFFIX NULL values count
SELECT *
FROM bronze.patients
WHERE SUFFIX IS NOT NULL

--MARITAL
SELECT DISTINCT MARITAL
FROM bronze.patients

--RACE
SELECT DISTINCT RACE
FROM bronze.patients

--ETHNICITY
SELECT DISTINCT ETHNICITY
FROM bronze.patients

--GENDER
SELECT DISTINCT GENDER
FROM bronze.patients

--------------------------------------------------------------------------------------------------
--testing bronze.payers table
SELECT TOP(20) *
FROM bronze.payers
SELECT COUNT(*)
FROM bronze.payers

--There are no NULLs or duplicated in the Id column
--But you need to account for that for any future changes

--------------------------------------------------------------------------------------------------
--testing bronze.procedures table
SELECT TOP(20) *
FROM bronze.procedures
SELECT COUNT(*)
FROM bronze.procedures


--Exploring the CODE column in the procedures table
SELECT DISTINCT CODE , DESCRIPTION
FROM bronze.procedures
WHERE CODE IN
(
	SELECT DISTINCT CODE
	FROM(
		SELECT ROW_NUMBER() OVER(PARTITION BY CODE ORDER BY CODE) AS r
			,CODE,DESCRIPTION
		FROM
		(
			SELECT DISTINCT CODE,DESCRIPTION
			FROM bronze.procedures
			) AS sub1
	) AS sub2
	WHERE r>1
)
ORDER BY CODE

SELECT DISTINCT CODE, DESCRIPTION
FROM bronze.procedures
WHERE DESCRIPTION LIKE '%(procedure)%'

--the '%(procedure)%' text is not adding to the description


--Does the ENCOUNTER column is a unique identifier of the procedures table?
SELECT 
ENCOUNTER,
COUNT(*) 
FROM bronze.procedures
GROUP BY ENCOUNTER
HAVING COUNT(*) >1 OR ENCOUNTER IS NULL

--There are no NULLS 
--The one ENCOUNTER could have several procedures
--So, you need to create an index Primary Key column for the procedures


--Does all ENCOUNTERs in the encounters table
SELECT * FROM bronze.procedures as p
WHERE  ENCOUNTER NOT IN
(
	SELECT DISTINCT encounter_id
	FROM silver.encounters AS e
)
--There are no ENCOUNTERS in the procedures table that does not existis in the encounters table


-------------------------------------------------------------
--Is there duplicate procedures?
-- Duplicating based on START, PATIENT, and CODE
--As one patient can't have the same procedure at the same time more than once
SELECT *, 
-- Partition by your composite columns to assign a unique increment flag
	ROW_NUMBER() OVER(PARTITION BY START, PATIENT, CODE ORDER BY STOP DESC -- Keeps the record with the latest STOP time if duplicates exist
	) AS dedupe_flag
FROM bronze.procedures
ORDER BY dedupe_flag DESC

--There are no duplicates in the procedures table


----------------------------------------------------------
--silver layer
SELECT TOP 100 * 
FROM silver.payers

SELECT TOP 100 *
FROM silver.encounters

SELECT TOP 100 * 
FROM silver.procedures


-------------------------------------------------------------
--gold layer
SELECT TOP 100 *
FROM gold.fact_procedures

------------------------------------------------------------- 
--the final views
USE hospital_db;
GO
-- 1. Preview Payers Dimension
SELECT TOP 100 * 
FROM gold.vw_dim_payers;

-- 2. Preview Patients Dimension
SELECT TOP 100 * 
FROM gold.vw_dim_patients;

-- 3. Preview Encounter Dates Dimension
SELECT TOP 100 * 
FROM gold.vw_dim_encounter_date;

-- 4. Preview Procedure Dates Dimension
SELECT TOP 100 * 
FROM gold.vw_dim_procedure_date;

-- 5. Preview Encounters Fact
SELECT TOP 100 * 
FROM gold.vw_fact_encounters;

-- 6. Preview Procedures Fact
SELECT TOP 100 * 
FROM gold.vw_fact_procedures;