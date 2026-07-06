USE hospital_db;
GO
EXEC bronze.bulk_load_csv;

EXEC silver.load_silver;

EXEC gold.load_gold;

EXEC gold.creating_the_views;