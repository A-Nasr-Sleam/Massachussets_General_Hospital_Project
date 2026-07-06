USE hospital_db;
GO

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME,@batch_start_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY
	SET @batch_start_time = GETDATE();
	--------------------------------------------------------------------------------------------------------
	--payers table
	--Implementing slowly changing dimension type 1
	SET @start_time = GETDATE();
	PRINT '******************************************************************';
	PRINT 'Phase2:Data transformation and inserting in the silver schema';
	PRINT '******************************************************************';
	PRINT '--------------------------------------------------------------------------------------------';
	PRINT '>> Implementing Slowly Changing Dimension type 1 In Table: silver.payers based on ID column'
	PRINT '--------------------------------------------------------------------------------------------';

	MERGE INTO silver.payers AS silver_table
	USING(
		--Transformed bronze.payers
		SELECT
			TRIM(Id) AS Id,
			TRIM(NAME) AS NAME,
			TRIM(ADDRESS) AS ADDRESS,
			TRIM(CITY) AS CITY,
			TRIM(STATE_HEADQUARTERED) AS STATE_HEADQUARTERED,
			s.StateName,
			ZIP,
			PHONE,
			GETDATE() AS UpdateDate
		FROM(
			--Subquery to clean NULLs or duplicate Ids
			SELECT *,
				ROW_NUMBER() OVER(PARTITION BY Id ORDER BY Id) AS flag
			FROM bronze.payers
			WHERE Id IS NOT NULL
		) AS sub1 
		INNER JOIN dbo.USStates AS s
			ON s.Abbreviation = sub1.STATE_HEADQUARTERED
		WHERE sub1.flag = 1
	) AS bronze_table
	ON bronze_table.Id = silver_table.payer_id

	-- Added ISNULL checks to protect against comparison failures with NULL values
	WHEN MATCHED AND (
		ISNULL(silver_table.payer_name, '')         <> ISNULL(bronze_table.NAME, '') OR
		ISNULL(silver_table.payer_address, '')      <> ISNULL(bronze_table.ADDRESS, '') OR
		ISNULL(silver_table.payer_city, '')         <> ISNULL(bronze_table.CITY, '') OR
		ISNULL(silver_table.state_headquartered, '')<> ISNULL(bronze_table.STATE_HEADQUARTERED, '') OR
		ISNULL(silver_table.payer_state, '')        <> ISNULL(bronze_table.StateName, '') OR
		ISNULL(silver_table.zip, '')                <> ISNULL(bronze_table.ZIP, '') OR
		ISNULL(silver_table.phone, '')              <> ISNULL(bronze_table.PHONE, '')
	)
	THEN
		UPDATE SET 
			silver_table.payer_name          = bronze_table.NAME,
			silver_table.payer_address       = bronze_table.ADDRESS,
			silver_table.payer_city          = bronze_table.CITY,
			silver_table.state_headquartered = bronze_table.STATE_HEADQUARTERED,
			silver_table.payer_state         = bronze_table.StateName,
			silver_table.zip                 = bronze_table.ZIP,
			silver_table.phone               = bronze_table.PHONE,
			silver_table.UpdatedAt           = GETDATE()

	WHEN NOT MATCHED BY TARGET THEN
		INSERT (
			payer_id, 
			payer_name, 
			payer_address, 
			payer_city, 
			state_headquartered, 
			payer_state, 
			zip, 
			phone, 
			UpdatedAt
		)
		VALUES (
			bronze_table.Id, 
			bronze_table.NAME, 
			bronze_table.ADDRESS, 
			bronze_table.CITY, 
			bronze_table.STATE_HEADQUARTERED, 
			bronze_table.StateName, 
			bronze_table.ZIP, 
			bronze_table.PHONE, 
			GETDATE()
		);



	----------------------------------------------------------------------------------------
	--Inserting Place holder for no payer
	PRINT '--------------------------------------------------------------------------------------------';
	PRINT '>> Inserting Place holder for no payer In Table: silver.payers'
	PRINT '--------------------------------------------------------------------------------------------';
-- 1. Check if the default key '0' already exists in the table
IF NOT EXISTS (SELECT 1 FROM silver.payers WHERE payer_key = 0)
BEGIN

    -- 2. Enable manual identity insertions
    SET IDENTITY_INSERT silver.payers ON;

    -- 3. Insert the placeholder row
    INSERT INTO silver.payers (
        payer_key, 
        payer_id,       
        payer_name, 
        payer_address, 
        payer_city, 
        state_headquartered, 
        payer_state, 
        ZIP, 
        phone, 
        UpdatedAt
    )
    VALUES (
        0,                                     
        '0000',
        'No Payer / Self-Pay', 
        'N/A', 
        'N/A',
        'NA', 
        'Not Applicable', 
        '00000', 
        '000-000-0000', 
        GETDATE()
    );

    -- 4. Disable identity insertions to restore standard auto-increment behavior
    SET IDENTITY_INSERT silver.payers OFF;

END


	-------------------------------------------------------------------------------------------
	--Adding the payer_id that does not exist in the payers table but exists in encounters
	PRINT '--------------------------------------------------------------------------------------------';
	PRINT '>> Adding the payer_id that does not exist in the payers table but exists in encounters In Table: silver.payers'
	PRINT '--------------------------------------------------------------------------------------------';
	INSERT INTO silver.payers (
		payer_id, 
		payer_name, 
		payer_address, 
		payer_city, 
		state_headquartered, 
		payer_state, 
		ZIP, 
		phone, 
		UpdatedAt
	)
	SELECT 
		source.PAYER AS payer_id,
		'Unknown Payer / Auto-Generated' AS payer_name,
		'N/A' AS payer_address,
		'N/A' AS payer_city,
		'NA'  AS state_headquartered,
		'Not Applicable' AS payer_state,
		'00000' AS ZIP,
		'000-000-0000' AS phone,
		GETDATE() AS UpdatedAt
	FROM (
		SELECT DISTINCT PAYER
		FROM bronze.encounters
		--filtering out any NULL values as they will nne replaced with the place holder No payer
		WHERE PAYER IS NOT NULL
	) AS source
	WHERE NOT EXISTS (
		SELECT 1 
		FROM silver.payers AS target
		WHERE target.payer_id = source.PAYER
	);

	SET @end_time = GETDATE();
	PRINT 'Load Duration : ' + CAST(DATEDIFF(millisecond,@start_time , @end_time) AS VARCHAR) + ' millisecond'
	

	--------------------------------------------------------------------------------------------------------
	--patients table
	--Implementing slowly changing dimension type 1
	SET @start_time = GETDATE();
	PRINT '--------------------------------------------------------------------------------------------';
	PRINT '>> Implementing Slowly Changing Dimension type 1 In Table: silver.patients based on ID column' 
	PRINT '--------------------------------------------------------------------------------------------';
	MERGE INTO silver.patients AS silver_table
	USING (
		-- Transformed bronze.patients
		SELECT
			TRIM(Id) AS Id,
			BIRTHDATE,
			DEATHDATE,
			TRIM(CONCAT(TRIM(PREFIX), ' ', TRIM(FIRST), ' ', TRIM(LAST))) AS patient_name,

			CASE 
				WHEN SUFFIX IS NULL THEN 'Unknown'
				ELSE SUFFIX 
			END AS SUFFIX,

			CASE 
				WHEN MAIDEN IS NULL THEN 0
				ELSE 1 
			END AS MAIDEN,

			CASE
				WHEN TRIM(UPPER(MARITAL)) = 'S' THEN 'Single'
				WHEN TRIM(UPPER(MARITAL)) = 'M' THEN 'Married'
				ELSE 'Unknown' 
			END AS marital_status,

			-- Title Case Transformation with NULL protection
			CASE WHEN NULLIF(TRIM(RACE), '') IS NOT NULL THEN TRIM(UPPER(LEFT(RACE, 1)) + LOWER(SUBSTRING(RACE, 2, LEN(RACE)))) ELSE 'Unknown' END AS RACE,
			CASE WHEN NULLIF(TRIM(ETHNICITY), '') IS NOT NULL THEN TRIM(UPPER(LEFT(ETHNICITY, 1)) + LOWER(SUBSTRING(ETHNICITY, 2, LEN(ETHNICITY)))) ELSE 'Unknown' END AS ETHNICITY,
        
			CASE
				WHEN TRIM(UPPER(GENDER)) = 'F' THEN 'Female'
				WHEN TRIM(UPPER(GENDER)) = 'M' THEN 'Male'
				ELSE 'Unknown' 
			END AS GENDER,

			BIRTHPLACE,
			ADDRESS,
			CASE WHEN NULLIF(TRIM(CITY), '') IS NOT NULL THEN TRIM(UPPER(LEFT(CITY, 1)) + LOWER(SUBSTRING(CITY, 2, LEN(CITY)))) ELSE NULL END AS CITY,
			CASE WHEN NULLIF(TRIM(STATE), '') IS NOT NULL THEN TRIM(UPPER(LEFT(STATE, 1)) + LOWER(SUBSTRING(STATE, 2, LEN(STATE)))) ELSE NULL END AS STATE,
			CASE WHEN NULLIF(TRIM(COUNTY), '') IS NOT NULL THEN TRIM(UPPER(LEFT(COUNTY, 1)) + LOWER(SUBSTRING(COUNTY, 2, LEN(COUNTY)))) ELSE NULL END AS COUNTY,
			ZIP,
			LAT,
			LON
		FROM (
			-- Subquery to clean NULLs or duplicate Ids
			SELECT *,
				ROW_NUMBER() OVER(PARTITION BY Id ORDER BY Id) AS flag
			FROM bronze.patients
			WHERE Id IS NOT NULL
		) AS sub1
		WHERE flag = 1
	) AS bronze_table
	ON silver_table.patient_id = bronze_table.Id

	-- 1. UPDATE BLOCK: Runs if patient exists but information changed
	WHEN MATCHED AND (
		ISNULL(silver_table.birth_date, '1900-01-01')    <> ISNULL(bronze_table.BIRTHDATE, '1900-01-01') OR
		ISNULL(silver_table.death_date, '1900-01-01')    <> ISNULL(bronze_table.DEATHDATE, '1900-01-01') OR
		silver_table.patient_name                        <> bronze_table.patient_name OR
		ISNULL(silver_table.suffix, '')                 <> ISNULL(bronze_table.SUFFIX, '') OR
		silver_table.maiden                              <> bronze_table.MAIDEN OR
		ISNULL(silver_table.marital_status, '')          <> ISNULL(bronze_table.marital_status, '') OR
		ISNULL(silver_table.race, '')                    <> ISNULL(bronze_table.RACE, '') OR
		ISNULL(silver_table.ethnicity, '')               <> ISNULL(bronze_table.ETHNICITY, '') OR
		ISNULL(silver_table.gender, '')                  <> ISNULL(bronze_table.GENDER, '') OR
		ISNULL(silver_table.birth_place, '')             <> ISNULL(bronze_table.BIRTHPLACE, '') OR
		ISNULL(silver_table.patient_address, '')         <> ISNULL(bronze_table.ADDRESS, '') OR
		ISNULL(silver_table.patient_city, '')            <> ISNULL(bronze_table.CITY, '') OR
		ISNULL(silver_table.patient_state, '')           <> ISNULL(bronze_table.STATE, '') OR
		ISNULL(silver_table.patient_county, '')          <> ISNULL(bronze_table.COUNTY, '') OR
		ISNULL(silver_table.ZIP, '')                     <> ISNULL(bronze_table.ZIP, '') OR
		ISNULL(silver_table.LAT, 0)                      <> ISNULL(bronze_table.LAT, 0) OR
		ISNULL(silver_table.LON, 0)                      <> ISNULL(bronze_table.LON, 0)
	)
	THEN
		UPDATE SET 
			silver_table.birth_date       = bronze_table.BIRTHDATE,
			silver_table.death_date       = bronze_table.DEATHDATE,
			silver_table.patient_name     = bronze_table.patient_name,
			silver_table.suffix           = bronze_table.SUFFIX,
			silver_table.maiden           = bronze_table.MAIDEN,
			silver_table.marital_status   = bronze_table.marital_status,
			silver_table.race             = bronze_table.RACE,
			silver_table.ethnicity        = bronze_table.ETHNICITY,
			silver_table.gender           = bronze_table.GENDER,
			silver_table.birth_place      = bronze_table.BIRTHPLACE,
			silver_table.patient_address  = bronze_table.ADDRESS,
			silver_table.patient_city     = bronze_table.CITY,
			silver_table.patient_state    = bronze_table.STATE,
			silver_table.patient_county   = bronze_table.COUNTY,
			silver_table.ZIP              = bronze_table.ZIP,
			silver_table.LAT              = bronze_table.LAT,
			silver_table.LON              = bronze_table.LON,
			silver_table.UpdatedAt         = GETDATE()

	-- 2. INSERT BLOCK: Runs if the patient ID doesn't exist in silver yet
	WHEN NOT MATCHED BY TARGET THEN
		INSERT (
			patient_id, birth_date, death_date, patient_name, suffix, maiden, 
			marital_status, race, ethnicity, gender, birth_place, patient_address, 
			patient_city, patient_state, patient_county, ZIP, LAT, LON, UpdatedAt
		)
		VALUES (
			bronze_table.Id, bronze_table.BIRTHDATE, bronze_table.DEATHDATE, bronze_table.patient_name, bronze_table.SUFFIX, bronze_table.MAIDEN, 
			bronze_table.marital_status, bronze_table.RACE, bronze_table.ETHNICITY, bronze_table.GENDER, bronze_table.BIRTHPLACE, bronze_table.ADDRESS, 
			bronze_table.CITY, bronze_table.STATE, bronze_table.COUNTY, bronze_table.ZIP, bronze_table.LAT, bronze_table.LON, GETDATE()
		);

		SET @end_time = GETDATE();
		PRINT 'Load Duration : ' + CAST(DATEDIFF(millisecond,@start_time , @end_time) AS VARCHAR) + ' millisecond'



	---------------------------------------------------------------------------------------------------------
	--encounters table
	--performing increamental insert in the silver.encounters table 

	PRINT '--------------------------------------------------------------------------------------------';
	PRINT '>> Performing Incremental Insert In Table: silver.procedures based on ID column' 
	PRINT '--------------------------------------------------------------------------------------------';
	SET @start_time = GETDATE();

	-- 1. Calculate the dynamic upper limit variable based on IQR rules
	DECLARE @encounter_duration_upper_limit INT;
	SET @encounter_duration_upper_limit = (
		SELECT CEILING(Q3 + (1.5 * IQR)) AS UpperLimit
		FROM (
			SELECT DISTINCT
				PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY DurationMinutes) OVER() AS Q1,
				PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY DurationMinutes) OVER() AS Q3,
				PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY DurationMinutes) OVER() -
				PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY DurationMinutes) OVER() AS IQR
			FROM (
				SELECT DATEDIFF(MINUTE, START, STOP) AS DurationMinutes
				FROM bronze.encounters
			) AS sub1
		) AS sub2
	);


	WITH code_description AS (
		SELECT CODE, DESCRIPTION
		FROM (
			SELECT CODE, DESCRIPTION,
				   ROW_NUMBER() OVER(PARTITION BY CODE ORDER BY LEN(DESCRIPTION) ASC) AS r
			FROM (
				SELECT DISTINCT CODE, DESCRIPTION
				FROM bronze.encounters
			) AS sub1
		) AS sub2
		WHERE r = 1
	),
	CleanBronzeEncounters AS (
		-- Deduplicate and evaluate referential integrity filters upfront
		SELECT *,
			   DATEDIFF(MINUTE, START, STOP) AS DurationMinutes
		FROM (
			SELECT *,
				   ROW_NUMBER() OVER(PARTITION BY Id ORDER BY Id) AS flag
			FROM bronze.encounters
			WHERE Id IS NOT NULL
			  -- Referential integrity check for Patients
			  AND TRIM(PATIENT) IN (SELECT patient_id FROM silver.patients)
			  -- Referential integrity check for payers
			  AND COALESCE(TRIM(PAYER), '0000') IN (SELECT payer_id FROM silver.payers)
		) AS sub
		WHERE flag = 1
	),
	TransformedData AS (
		SELECT 
			TRIM(b.Id) AS encounter_id,
			b.START AS encounter_start,
			b.STOP AS encounter_stop,
			CONVERT(INT, FORMAT(b.START, 'yyyyMMdd')) AS date_key,
			CASE 
				WHEN b.DurationMinutes > @encounter_duration_upper_limit THEN @encounter_duration_upper_limit
				WHEN b.DurationMinutes < 0 THEN 1
				ELSE b.DurationMinutes 
			END AS encounter_duration_MIN,
			patient.patient_key AS patient_key,
			DATEDIFF(YEAR, patient.birth_date, b.START) AS patient_age_ED,
			b.ORGANIZATION AS organization,
			payer.payer_key AS payer_key,
			CASE 
				WHEN NULLIF(TRIM(b.ENCOUNTERCLASS), '') IS NOT NULL 
				THEN TRIM(UPPER(LEFT(b.ENCOUNTERCLASS, 1)) + LOWER(SUBSTRING(b.ENCOUNTERCLASS, 2, LEN(b.ENCOUNTERCLASS))))
				ELSE 'Unknown' 
			END AS encounterclass,
			TRIM(b.CODE) AS encounter_code,
			cd.DESCRIPTION AS encounter_description,
			CASE 
			--check if there are negative or zero base encounter cost values
			--and replace them with 1
				WHEN b.BASE_ENCOUNTER_COST <= 0 THEN 1
				ELSE b.BASE_ENCOUNTER_COST
			END AS base_encounter_cost,
			CASE 
				--check if there are negative or zero total claim cost values
				--and replace them with 1
				WHEN b.TOTAL_CLAIM_COST <= 0 THEN 1
				ELSE b.TOTAL_CLAIM_COST
			END AS total_claim_cost,
			CASE 
				--check if there are negative or zero payer coverage values
				--and replace them with 1
				WHEN b.PAYER_COVERAGE <= 0 THEN 1
				--check if the payer coverage is greater than total claim cost
				-- and replace it with total claim cost
				WHEN b.PAYER_COVERAGE > b.TOTAL_CLAIM_COST THEN b.TOTAL_CLAIM_COST
				ELSE b.PAYER_COVERAGE
			END AS payer_coverage,
			COALESCE(b.REASONCODE, 'Unknown') AS reason_code,
			COALESCE(b.REASONDESCRIPTION, 'Unknown') AS reason_description
		FROM CleanBronzeEncounters b
		INNER JOIN code_description cd ON cd.CODE = b.CODE
		INNER JOIN silver.patients patient ON patient.patient_id = b.PATIENT
		INNER JOIN silver.payers payer ON payer.payer_id = COALESCE(TRIM(b.PAYER), '0000')
	)
	-- 3. Execute the safe incremental insert
	INSERT INTO silver.encounters (
		encounter_id,
		encounter_start,
		encounter_stop,
		date_key,
		encounter_duration_MIN,
		patient_key,
		patient_age_ED,
		organization,
		payer_key,
		encounterclass,
		encounter_code,
		encounter_description,
		base_encounter_cost,
		total_claim_cost,
		payer_coverage,
		reason_code,
		reason_description,
		RecordedAt
	)
	SELECT 
		src.encounter_id,
		src.encounter_start,
		src.encounter_stop,
		src.date_key,
		src.encounter_duration_MIN,
		src.patient_key,
		src.patient_age_ED,
		src.organization,
		src.payer_key,
		src.encounterclass,
		src.encounter_code,
		src.encounter_description,
		src.base_encounter_cost,
		src.total_claim_cost,
		src.payer_coverage,
		src.reason_code,
		src.reason_description,
		GETDATE() AS RecordedAt
	FROM TransformedData AS src
	WHERE NOT EXISTS (
		SELECT 1 
		FROM silver.encounters AS target
		WHERE target.encounter_id = src.encounter_id
	);

		SET @end_time = GETDATE();
		PRINT 'Load Duration : ' + CAST(DATEDIFF(millisecond,@start_time , @end_time) AS VARCHAR) + ' millisecond'
	-------------------------------------------------------------------------------------------------------------------------
	--procedures table
	--Performing truncte then insert in table silver.procedures
	-- 1-Truncate the silver table to ensure a clean refresh
	SET @start_time = GETDATE();
	PRINT '--------------------------------------------------------------------------------------------';
	PRINT '>> Truncating Table: silver.procedures' 
	PRINT '--------------------------------------------------------------------------------------------';
	TRUNCATE TABLE silver.procedures;
	PRINT '--------------------------------------------------------------------------------------------';
	PRINT '>> Inserting data in Table: silver.procedures' 
	PRINT '--------------------------------------------------------------------------------------------';
	-- Calculate the dynamic upper limit variable based on IQR rules
	DECLARE @procedure_duration_upper_limit INT;

	SET @procedure_duration_upper_limit = (
		SELECT CEILING(Q3 + (1.5 * IQR)) AS UpperLimit
		FROM (
			SELECT DISTINCT
				PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY DurationMinutes) OVER() AS Q3,
				PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY DurationMinutes) OVER() -
				PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY DurationMinutes) OVER() AS IQR
			FROM (
				SELECT DATEDIFF(MINUTE, START, STOP) AS DurationMinutes
				FROM bronze.procedures
			) AS sub1
		) AS sub2
	);

	WITH code_description AS (
		SELECT CODE, DESCRIPTION
		FROM (
			SELECT CODE, DESCRIPTION,
				   ROW_NUMBER() OVER(PARTITION BY CODE ORDER BY LEN(DESCRIPTION) ASC) AS r
			FROM (
				SELECT DISTINCT CODE, DESCRIPTION
				FROM bronze.procedures
			) AS sub1
		) AS sub2
		WHERE r = 1
	),
	CleanBronzeProcedures AS (
		-- Deduplicating based on START, PATIENT, and CODE
		--As one patient can't have the same procedure at the same time more than once
		SELECT 
			START,
			STOP,
			PATIENT,
			ENCOUNTER,
			CODE,
			BASE_COST,
			REASONCODE,
			REASONDESCRIPTION,
			DATEDIFF(MINUTE, START, STOP) AS DurationMinutes
		FROM (
			SELECT *, 
			-- Partition by your composite columns to assign a unique increment flag
				   ROW_NUMBER() OVER(
					   PARTITION BY START, PATIENT, CODE 
					   ORDER BY STOP DESC -- Keeps the record with the latest STOP time if duplicates exist
				   ) AS dedupe_flag
			FROM bronze.procedures
			WHERE 
			  -- Referential integrity check for PATIENT
			  TRIM(PATIENT) IN (SELECT patient_id FROM silver.patients)
			  -- Referential integrity check for ENCOUNTERS
			  AND TRIM(ENCOUNTER) IN (SELECT encounter_id FROM silver.encounters)
		) AS sub
		WHERE dedupe_flag = 1 -- Filters out all duplicate rows, keeping only the first one
	),
	TransformedData AS (
		SELECT 
		p.START AS [procedure_start],
		p.STOP AS [procedure_stop],
		CONVERT(INT, FORMAT(p.START, 'yyyyMMdd')) AS date_key,
			CASE 
				WHEN p.DurationMinutes > @procedure_duration_upper_limit THEN @procedure_duration_upper_limit
				WHEN p.DurationMinutes < 0 THEN 1
				ELSE p.DurationMinutes 
			END AS procedure_duration_MIN,
			patient.patient_key AS patient_key,
			DATEDIFF(YEAR, patient.birth_date, p.START) AS patient_age_PD,
			TRIM(p.CODE) AS procedure_code,
			cd.DESCRIPTION AS procedure_description,
			CASE 
				--check if there are negative or zero base procedure cost values
				--and replace them with 1
				WHEN CAST(p.BASE_COST AS INT) <= 0 THEN 1
				ELSE CAST(p.BASE_COST AS INT)
			END AS base_procedure_cost,
		COALESCE(p.REASONCODE, 'Unknown') AS reason_code,
		COALESCE(p.REASONDESCRIPTION, 'Unknown') AS reason_description,
		encounter.encounter_key AS encounter_key
	FROM CleanBronzeProcedures p
	INNER JOIN code_description cd ON cd.CODE = p.CODE
	INNER JOIN silver.patients patient ON patient.patient_id = p.PATIENT
	INNER JOIN silver.encounters encounter ON encounter.encounter_id = TRIM(p.ENCOUNTER)
	)
	-- 4. Execute the safe insert
	INSERT INTO silver.procedures (
		procedure_start,
		procedure_stop,
		date_key,
		procedure_duration_MIN,
		patient_key,
		patient_age_PD,
		encounter_key,
		procedure_code,
		procedure_description,
		base_procedure_cost,
		reason_code,
		reason_description
	)
	SELECT 
		src.[procedure_start],
		src.[procedure_stop],
		src.date_key,
		src.procedure_duration_MIN,
		src.patient_key,
		src.patient_age_PD,
		src.encounter_key,
		src.procedure_code,
		src.procedure_description,
		src.base_procedure_cost,
		src.reason_code,
		src.reason_description
	FROM TransformedData AS src;

	SET @end_time = GETDATE();
	PRINT 'Load Duration : ' + CAST(DATEDIFF(millisecond,@start_time , @end_time) AS VARCHAR) + ' millisecond'


	SET @batch_end_time = GETDATE();
		PRINT '------------------------------------------------------------------';
		PRINT 'batch loading is finished';
		PRINT 'Batch Load Duration : ' + CAST(DATEDIFF(millisecond,@batch_start_time , @batch_end_time) AS VARCHAR) + ' millisecond'
		PRINT '------------------------------------------------------------------'; 
		PRINT '******************************************************************'
		PRINT '******************************************************************'
		PRINT '******************************************************************'
		END TRY
		BEGIN CATCH
		PRINT 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
		PRINT 'Error occured during loading the silver';
		PRINT 'Error Message : ' + ERROR_MESSAGE();
		PRINT 'Error Number : ' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error State : ' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
		END CATCH
END
