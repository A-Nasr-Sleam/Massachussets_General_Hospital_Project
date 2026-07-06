USE hospital_db;
GO

CREATE OR ALTER PROCEDURE gold.creating_the_views AS
BEGIN
	DECLARE @batch_start_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY
	SET @batch_start_time = GETDATE();
	PRINT '******************************************************************';
	PRINT 'Phase4:Wraping the gold layer tables into views';
	PRINT '******************************************************************';
	PRINT '--------------------------------------------------------------------------------------------';
	PRINT '>> Creating the final views'
	PRINT '--------------------------------------------------------------------------------------------';
--------------------------------------------------------------------------------------------------------
-- 1. View for Payers
DROP VIEW IF EXISTS gold.vw_dim_payers;

EXEC('
	CREATE VIEW gold.vw_dim_payers AS
	SELECT 
		payer_key,
		payer_name,
		payer_city,
		payer_state
	FROM gold.dim_payers;
      ');

-- 2. View for Patients
DROP VIEW IF EXISTS gold.vw_dim_patients;

EXEC('
	CREATE VIEW gold.vw_dim_patients AS
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
	FROM gold.dim_patients;
      ');

-- 3. View for Encounter Dates
DROP VIEW IF EXISTS gold.vw_dim_encounter_date;

EXEC('
	CREATE VIEW gold.vw_dim_encounter_date AS
	SELECT 
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
	FROM gold.dim_encounter_date;

      ');

-- 4. View for Encounters
DROP VIEW IF EXISTS gold.vw_fact_encounters;

EXEC('
	CREATE VIEW gold.vw_fact_encounters AS
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
	FROM gold.fact_encounters;
      ');

-- 5. View for Procedure Dates
DROP VIEW IF EXISTS gold.vw_dim_procedure_date;

EXEC('
	CREATE VIEW gold.vw_dim_procedure_date AS
	SELECT 
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
	FROM gold.dim_procedure_date;

      ');

-- 6. View for Procedures
DROP VIEW IF EXISTS gold.vw_fact_procedures;

EXEC('
	CREATE VIEW gold.vw_fact_procedures AS
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
	FROM gold.fact_procedures;
      ');

	SET @batch_end_time = GETDATE();
	--------------------------------------------------------------------------------------------------------------
		PRINT '------------------------------------------------------------------';
		PRINT 'batch loading is finished';
		PRINT 'Batch Load Duration : ' + CAST(DATEDIFF(millisecond,@batch_start_time , @batch_end_time) AS VARCHAR) + ' millisecond'
		PRINT '------------------------------------------------------------------'; 
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