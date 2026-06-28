--Bulk inserting into stage schema
CREATE OR ALTER PROCEDURE stage.bulk_load_csv AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME,@batch_start_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY
	SET @batch_start_time = GETDATE();
		PRINT '------------------------------------------------------------------';
		PRINT 'Loading the CSVs into the stage';
		PRINT '------------------------------------------------------------------';

		--Bulk inserting encounter.csv
		SET @start_time = GETDATE();
		PRINT '------------------------------------------------------------------';
		PRINT 'Loading the encounter.csv into the stage';
		PRINT '------------------------------------------------------------------';
		TRUNCATE TABLE stage.encounters ;
		BULK INSERT stage.encounters 
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
		PRINT 'Loading the patients.csv into the stage';
		PRINT '------------------------------------------------------------------';
		TRUNCATE TABLE stage.patients ;
		BULK INSERT stage.patients 
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
		PRINT 'Loading the payers.csv into the stage';
		PRINT '------------------------------------------------------------------';
		TRUNCATE TABLE stage.payers ;
		BULK INSERT stage.payers 
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
		PRINT 'Loading the procedures.csv into the stage';
		PRINT '------------------------------------------------------------------';
		TRUNCATE TABLE stage.procedures ;
		BULK INSERT stage.procedures
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
		PRINT 'Erro occured during loading the stage';
		PRINT 'Erro Message : ' + ERROR_MESSAGE();
		PRINT 'Erro Number : ' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Erro State : ' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
		END CATCH
END
