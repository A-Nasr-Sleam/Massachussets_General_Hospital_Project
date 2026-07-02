--Bulk inserting into bronze schema
USE hospital_db;
GO
CREATE OR ALTER PROCEDURE bronze.bulk_load_csv AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME,@batch_start_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY
	SET @batch_start_time = GETDATE();
		PRINT '------------------------------------------------------------------';
		PRINT 'Loading the CSVs into the bronze';
		PRINT '------------------------------------------------------------------';

		--Bulk inserting encounter.csv
		SET @start_time = GETDATE();
		PRINT '------------------------------------------------------------------';
		PRINT 'Loading the encounter.csv into the bronze';
		PRINT '------------------------------------------------------------------';
		TRUNCATE TABLE bronze.encounters ;
		BULK INSERT bronze.encounters 
		FROM "C:\Users\user\Power BI projects\Massachussets_General_Hospital_Project\CSVs\encounters.csv"
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT 'Load Duration : ' + CAST(DATEDIFF(millisecond,@start_time , @end_time) AS VARCHAR) + ' millisecond'

		--Bulk inserting patients.csv
		SET @start_time = GETDATE();
		PRINT '------------------------------------------------------------------';
		PRINT 'Loading the patients.csv into the bronze';
		PRINT '------------------------------------------------------------------';
		TRUNCATE TABLE bronze.patients ;
		BULK INSERT bronze.patients 
		FROM "C:\Users\user\Power BI projects\Massachussets_General_Hospital_Project\CSVs\patients.csv"
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT 'Load Duration : ' + CAST(DATEDIFF(millisecond,@start_time , @end_time) AS VARCHAR) + ' millisecond'

		--Bulk inserting payers.csv
		SET @start_time = GETDATE();
		PRINT '------------------------------------------------------------------';
		PRINT 'Loading the payers.csv into the bronze';
		PRINT '------------------------------------------------------------------';
		TRUNCATE TABLE bronze.payers ;
		BULK INSERT bronze.payers 
		FROM "C:\Users\user\Power BI projects\Massachussets_General_Hospital_Project\CSVs\payers.csv"
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT 'Load Duration : ' + CAST(DATEDIFF(millisecond,@start_time , @end_time) AS VARCHAR) + ' millisecond'


		--Bulk inserting procedures.csv
		SET @start_time = GETDATE();
		PRINT '------------------------------------------------------------------';
		PRINT 'Loading the procedures.csv into the bronze';
		PRINT '------------------------------------------------------------------';
		TRUNCATE TABLE bronze.procedures ;
		BULK INSERT bronze.procedures
		FROM "C:\Users\user\Power BI projects\Massachussets_General_Hospital_Project\CSVs\procedures.csv"
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT 'Load Duration : ' + CAST(DATEDIFF(millisecond,@start_time , @end_time) AS VARCHAR) + ' millisecond'

		SET @batch_end_time = GETDATE();
		PRINT '------------------------------------------------------------------';
		PRINT 'batch loading is finished';
		PRINT 'Batch Load Duration : ' + CAST(DATEDIFF(millisecond,@batch_start_time , @batch_end_time) AS VARCHAR) + ' millisecond'
		PRINT '------------------------------------------------------------------'; 
		END TRY
		BEGIN CATCH
		PRINT 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
		PRINT 'Error occured during loading the bronze';
		PRINT 'Error Message : ' + ERROR_MESSAGE();
		PRINT 'Error Number : ' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error State : ' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
		END CATCH
END
