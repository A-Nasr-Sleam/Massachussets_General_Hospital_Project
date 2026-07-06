USE hospital_db;
GO

CREATE OR ALTER PROCEDURE gold.load_gold AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME,@batch_start_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY
	SET @batch_start_time = GETDATE();
	PRINT '******************************************************************';
	PRINT 'Phase3:Data transformation and inserting in the gold schema';
	PRINT '******************************************************************';
	--------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------
	 -- Drop Encounter Foreign Keys if they exist
	SET @start_time = GETDATE();
	PRINT '--------------------------------------------------------------------------------------------';
	PRINT '>> DROP FOREIGN KEY CONSTRAINTS'
	PRINT '--------------------------------------------------------------------------------------------';
        IF OBJECT_ID('gold.FK_encounters_date', 'F') IS NOT NULL
            ALTER TABLE gold.fact_encounters DROP CONSTRAINT FK_encounters_date;
            
        IF OBJECT_ID('gold.FK_encounters_patient', 'F') IS NOT NULL
            ALTER TABLE gold.fact_encounters DROP CONSTRAINT FK_encounters_patient;
            
        IF OBJECT_ID('gold.FK_encounters_payer', 'F') IS NOT NULL
            ALTER TABLE gold.fact_encounters DROP CONSTRAINT FK_encounters_payer;

        -- Drop Procedure Foreign Keys if they exist
        IF OBJECT_ID('gold.FK_procedures_date', 'F') IS NOT NULL
            ALTER TABLE gold.fact_procedures DROP CONSTRAINT FK_procedures_date;
            
        IF OBJECT_ID('gold.FK_procedures_patient', 'F') IS NOT NULL
            ALTER TABLE gold.fact_procedures DROP CONSTRAINT FK_procedures_patient;

		IF OBJECT_ID('gold.FK_procedures_encounter', 'F') IS NOT NULL
            ALTER TABLE gold.fact_procedures DROP CONSTRAINT FK_procedures_encounter;

	--------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------
	--truncate and load the gold.dim_payers table from silver.payers
	SET @start_time = GETDATE();
	PRINT '--------------------------------------------------------------------------------------------';
	PRINT '>> Truncate and load the gold.dim_payers table from silver.payers'
	PRINT '--------------------------------------------------------------------------------------------';
	TRUNCATE TABLE gold.dim_payers;
	--insert into gold.dim_payers from silver.payers
	INSERT INTO gold.dim_payers (
		payer_key,
		payer_name,
		payer_city,
		payer_state
	)
	SELECT
		payer_key,
		payer_name,
		payer_city,
		payer_state
	FROM silver.payers;

	SET @end_time = GETDATE();
	PRINT 'Load Duration : ' + CAST(DATEDIFF(millisecond,@start_time , @end_time) AS VARCHAR) + ' millisecond'

	-----------------------------------------------------------------------------------
	--truncate and load the gold.dim_patients table from silver.patients
	SET @start_time = GETDATE();
	PRINT '--------------------------------------------------------------------------------------------';
	PRINT '>> Truncate and load the gold.dim_patients table from silver.patients' 
	PRINT '--------------------------------------------------------------------------------------------';
	TRUNCATE TABLE gold.dim_patients;
	---insert into gold.dim_patients from silver.patients
	INSERT INTO gold.dim_patients (
		patient_key,
		birth_date,
		death_date,
		patient_name,
		suffix,
		maiden,
		marital_status,
		race,
		ethnicity,
		gender,
		patient_city,
		patient_state,
		patient_county
	)
	SELECT
		patient_key,
		birth_date,
		death_date,
		patient_name,
		suffix,
		maiden,
		marital_status,
		race,
		ethnicity,
		gender,
		patient_city,
		patient_state,
		patient_county
	FROM silver.patients;

		SET @end_time = GETDATE();
		PRINT 'Load Duration : ' + CAST(DATEDIFF(millisecond,@start_time , @end_time) AS VARCHAR) + ' millisecond'

	-------------------------------------------------------------------------------------
	--populating table gold.dim_encounter_date
	PRINT '--------------------------------------------------------------------------------------------';
	PRINT '>> Populating table gold.dim_encounter_date' 
	PRINT '--------------------------------------------------------------------------------------------';
	TRUNCATE TABLE gold.dim_encounter_date;
	SET @start_time = GETDATE();
	--Populate the table dynamically based on silver.encounters
	DECLARE @MinDate DATE, @MaxDate DATE;

	SELECT 
		@MinDate = DATEFROMPARTS(YEAR(MIN(encounter_start)), 1, 1),
		@MaxDate = DATEFROMPARTS(YEAR(MAX(encounter_start)), 12, 31)
	FROM silver.encounters;

	WITH DateDimension AS (
		SELECT @MinDate AS CurrentDate
		UNION ALL
		SELECT DATEADD(day, 1, CurrentDate)
		FROM DateDimension
		WHERE CurrentDate < @MaxDate
	)
	INSERT INTO gold.dim_encounter_date (
		date_key,
		full_date,
		calendar_year,
		calendar_quarter,
		calendar_month,
		calendar_day,
		day_of_week,
		day_name,
		is_weekend,
		fiscal_year,
		fiscal_quarter,
		fiscal_month
	)
	SELECT 
		CONVERT(INT, CONVERT(VARCHAR(8), CurrentDate, 112)) AS date_key,
		CurrentDate AS full_date,
		YEAR(CurrentDate) AS calendar_year,
		DATEPART(QUARTER, CurrentDate) AS calendar_quarter,
		MONTH(CurrentDate) AS calendar_month,
		DAY(CurrentDate) AS calendar_day,
		DATEPART(weekday, CurrentDate) AS day_of_week,
		DATENAME(weekday, CurrentDate) AS day_name,
		CASE WHEN DATEPART(weekday, CurrentDate) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend,
    
		-- Fiscal Year Rules (US Federal/Hospital): Starts October 1st and ends September 30th.
		-- Dates from October through December shift forward to the next calendar year's fiscal year designation.
		CASE 
			WHEN MONTH(CurrentDate) >= 10 THEN YEAR(CurrentDate) + 1 
			ELSE YEAR(CurrentDate) 
		END AS fiscal_year,
    
		-- Fiscal Quarter Rules: Q1 (Oct-Dec), Q2 (Jan-Mar), Q3 (Apr-Jun), Q4 (Jul-Sep).
		CASE 
			WHEN MONTH(CurrentDate) IN (10, 11, 12) THEN 1
			WHEN MONTH(CurrentDate) IN (1, 2, 3)    THEN 2
			WHEN MONTH(CurrentDate) IN (4, 5, 6)    THEN 3
			ELSE 4 
		END AS fiscal_quarter,
    
		-- Fiscal Month Rules: Month 1 begins in October, scaling sequentially to Month 12 in September.
		CASE 
			WHEN MONTH(CurrentDate) >= 10 THEN MONTH(CurrentDate) - 9
			ELSE MONTH(CurrentDate) + 3
		END AS fiscal_month
	FROM DateDimension
	OPTION (MAXRECURSION 0);


	SET @end_time = GETDATE();
	PRINT 'Load Duration : ' + CAST(DATEDIFF(millisecond,@start_time , @end_time) AS VARCHAR) + ' millisecond'

	----------------------------------------------------------------------------------------------
	--truncate and load the gold.fact_encounters table from silver.encounters

	SET @start_time = GETDATE();
	PRINT '--------------------------------------------------------------------------------------------';
	PRINT '>> Truncate and load the gold.fact_encounters table from silver.encounters' 
	PRINT '--------------------------------------------------------------------------------------------';
	TRUNCATE TABLE gold.fact_encounters;
	--insert into gold.fact_encounters from silver.encounters
	INSERT INTO gold.fact_encounters (
		encounter_key,
		encounter_start,
		encounter_stop,
		date_key,
		encounter_duration_MIN,
		patient_key,
		patient_age_ED,
		payer_key,
		encounterclass,
		encounter_code,
		encounter_description,
		base_encounter_cost,
		total_claim_cost,
		payer_coverage,
		reason_code,
		reason_description
	)
	SELECT 
		encounter_key,
		encounter_start,
		encounter_stop,
		date_key,
		encounter_duration_MIN,
		patient_key,
		patient_age_ED,
		payer_key,
		encounterclass,
		encounter_code,
		encounter_description,
		base_encounter_cost,
		total_claim_cost,
		payer_coverage,
		reason_code,
		reason_description
	FROM silver.encounters;


	SET @end_time = GETDATE();
	PRINT 'Load Duration : ' + CAST(DATEDIFF(millisecond,@start_time , @end_time) AS VARCHAR) + ' millisecond'
	---------------------------------------------------------------------------------------
	--populating table gold.dim_procedure_date
	TRUNCATE TABLE gold.dim_procedure_date;
	SET @start_time = GETDATE();
	PRINT '--------------------------------------------------------------------------------------------';
	PRINT '>> Populating table gold.dim_procedure_date' 
	PRINT '--------------------------------------------------------------------------------------------';
	--Populate the table dynamically based on silver.procedures
	-- Find the start of the year for the first procedure and the end of the year for the last procedure

	SELECT 
		@MinDate = DATEFROMPARTS(YEAR(MIN(procedure_start)), 1, 1),
		@MaxDate = DATEFROMPARTS(YEAR(MAX(procedure_start)), 12, 31)
	FROM silver.procedures;

	WITH DateDimension AS (
		SELECT @MinDate AS CurrentDate
		UNION ALL
		SELECT DATEADD(day, 1, CurrentDate)
		FROM DateDimension
		WHERE CurrentDate < @MaxDate
	)
	INSERT INTO gold.dim_procedure_date (
		date_key,
		full_date,
		calendar_year,
		calendar_quarter,
		calendar_month,
		calendar_day,
		day_of_week,
		day_name,
		is_weekend,
		fiscal_year,
		fiscal_quarter,
		fiscal_month
	)
	SELECT 
		CONVERT(INT, CONVERT(VARCHAR(8), CurrentDate, 112)) AS date_key,
		CurrentDate AS full_date,
		YEAR(CurrentDate) AS calendar_year,
		DATEPART(QUARTER, CurrentDate) AS calendar_quarter,
		MONTH(CurrentDate) AS calendar_month,
		DAY(CurrentDate) AS calendar_day,
		DATEPART(weekday, CurrentDate) AS day_of_week,
		DATENAME(weekday, CurrentDate) AS day_name,
		CASE WHEN DATEPART(weekday, CurrentDate) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend,
    
		-- Fiscal Year Rules (US Federal/Hospital): Starts October 1st and ends September 30th.
		-- Dates from October through December shift forward to the next calendar year's fiscal year designation.
		CASE 
			WHEN MONTH(CurrentDate) >= 10 THEN YEAR(CurrentDate) + 1 
			ELSE YEAR(CurrentDate) 
		END AS fiscal_year,
    
		-- Fiscal Quarter Rules: Q1 (Oct-Dec), Q2 (Jan-Mar), Q3 (Apr-Jun), Q4 (Jul-Sep).
		CASE 
			WHEN MONTH(CurrentDate) IN (10, 11, 12) THEN 1
			WHEN MONTH(CurrentDate) IN (1, 2, 3)    THEN 2
			WHEN MONTH(CurrentDate) IN (4, 5, 6)    THEN 3
			ELSE 4 
		END AS fiscal_quarter,
    
		-- Fiscal Month Rules: Month 1 begins in October, scaling sequentially to Month 12 in September.
		CASE 
			WHEN MONTH(CurrentDate) >= 10 THEN MONTH(CurrentDate) - 9
			ELSE MONTH(CurrentDate) + 3
		END AS fiscal_month
	FROM DateDimension
	OPTION (MAXRECURSION 0);


	
	SET @end_time = GETDATE();
	PRINT 'Load Duration : ' + CAST(DATEDIFF(millisecond,@start_time , @end_time) AS VARCHAR) + ' millisecond'
	-----------------------------------------------------------------------------------------------
	--truncate and load the gold.fact_procedures table from silver.procedures
	SET @start_time = GETDATE();
	PRINT '--------------------------------------------------------------------------------------------';
	PRINT '>> Truncate and load the gold.fact_procedures table from silver.procedures' 
	PRINT '--------------------------------------------------------------------------------------------';
	TRUNCATE TABLE gold.fact_procedures;
	--insert into gold.fact_procedures from silver.procedures
	INSERT INTO gold.fact_procedures (
		procedure_key,
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
		procedure_key,
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
	FROM silver.procedures;


	--------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------
	SET @start_time = GETDATE();
	PRINT '--------------------------------------------------------------------------------------------';
	PRINT '>> RE-CREATE FOREIGN KEY CONSTRAINTS WITH CHECK'
	PRINT '--------------------------------------------------------------------------------------------';
	 -- Rebuild Encounters constraints
        ALTER TABLE gold.fact_encounters WITH CHECK ADD CONSTRAINT FK_encounters_date 
            FOREIGN KEY (date_key) REFERENCES gold.dim_encounter_date (date_key);
            
        ALTER TABLE gold.fact_encounters WITH CHECK ADD CONSTRAINT FK_encounters_patient 
            FOREIGN KEY (patient_key) REFERENCES gold.dim_patients (patient_key);
            
        ALTER TABLE gold.fact_encounters WITH CHECK ADD CONSTRAINT FK_encounters_payer 
            FOREIGN KEY (payer_key) REFERENCES gold.dim_payers (payer_key);

        -- Rebuild Procedures constraints
        ALTER TABLE gold.fact_procedures WITH CHECK ADD CONSTRAINT FK_procedures_date 
            FOREIGN KEY (date_key) REFERENCES gold.dim_procedure_date (date_key);
            
        ALTER TABLE gold.fact_procedures WITH CHECK ADD CONSTRAINT FK_procedures_patient 
            FOREIGN KEY (patient_key) REFERENCES gold.dim_patients (patient_key);

		ALTER TABLE gold.fact_procedures WITH CHECK ADD CONSTRAINT FK_procedures_encounter 
            FOREIGN KEY (encounter_key) REFERENCES gold.fact_encounters (encounter_key);

        -- Validate that all loaded rows conform to the constraints
        ALTER TABLE gold.fact_encounters CHECK CONSTRAINT ALL;
        ALTER TABLE gold.fact_procedures CHECK CONSTRAINT ALL;

	SET @end_time = GETDATE();
	PRINT 'Load Duration : ' + CAST(DATEDIFF(millisecond,@start_time , @end_time) AS VARCHAR) + ' millisecond'
	SET @batch_end_time = GETDATE();
	--------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------
		PRINT '------------------------------------------------------------------';
		PRINT 'batch loading is finished';
		PRINT 'Batch Load Duration : ' + CAST(DATEDIFF(millisecond,@batch_start_time , @batch_end_time) AS VARCHAR) + ' millisecond'
		PRINT '------------------------------------------------------------------'; 
		PRINT '******************************************************************';
		PRINT '******************************************************************';
		PRINT '******************************************************************';
	END TRY
	BEGIN CATCH
		PRINT 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
		PRINT 'Error occured during loading the gold';
		PRINT 'Error Message : ' + ERROR_MESSAGE();
		PRINT 'Error Number : ' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error State : ' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
	END CATCH
END