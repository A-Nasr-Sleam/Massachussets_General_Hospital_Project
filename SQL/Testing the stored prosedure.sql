USE hospital_db;
GO
EXEC bronze.bulk_load_csv;

EXEC silver.load_silver;