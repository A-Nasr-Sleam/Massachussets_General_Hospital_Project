USE MASTER;
GO
--To disconnect all users from the database so it can be dropped if exists
ALTER DATABASE hospital_db 
SET SINGLE_USER 
WITH ROLLBACK IMMEDIATE;
GO

DROP DATABASE IF EXISTS hospital_db;
CREATE DATABASE hospital_db;

USE hospital_db;
GO


---------------------------------------------------------------------------------------------------------
--CREATING THE bronze schema;
CREATE SCHEMA bronze;
GO 

--Creating the bronze schema tables
--Creating table bronze.payers
DROP TABLE IF EXISTS bronze.payers;
GO
CREATE TABLE bronze.payers (
    Id CHAR(36) ,
    NAME VARCHAR(100),
    ADDRESS VARCHAR(255),
    CITY VARCHAR(100),
    STATE_HEADQUARTERED CHAR(2),
    ZIP VARCHAR(10),
    PHONE VARCHAR(20)
);

--Creating tacle bronze.patients
DROP TABLE IF EXISTS bronze.patients;
GO
CREATE TABLE bronze.patients (
    Id CHAR(36) ,
    BIRTHDATE DATE,
    DEATHDATE DATE,
    PREFIX VARCHAR(10),
    FIRST VARCHAR(100),
    LAST VARCHAR(100),
    SUFFIX VARCHAR(10),
    MAIDEN VARCHAR(100),
    MARITAL CHAR(1),
    RACE VARCHAR(50),
    ETHNICITY VARCHAR(50),
    GENDER CHAR(1),
    BIRTHPLACE VARCHAR(255),
    ADDRESS VARCHAR(255),
    CITY VARCHAR(100),
    STATE VARCHAR(100),
    COUNTY VARCHAR(100),
    ZIP VARCHAR(10),
    LAT DECIMAL(9,6),
    LON DECIMAL(9,6)
);

--Creating table bronze.procedure
DROP TABLE IF EXISTS bronze.procedures;
GO
CREATE TABLE bronze.procedures (
    START DATETIME,
    STOP DATETIME,
    PATIENT CHAR(36),
    ENCOUNTER CHAR(36),
    CODE VARCHAR(20),
    DESCRIPTION VARCHAR(255),
    BASE_COST INT,
    REASONCODE VARCHAR(20),
    REASONDESCRIPTION VARCHAR(255)
);

--Creating table bronze.encounters
DROP TABLE IF EXISTS bronze.encounters;
GO
CREATE TABLE bronze.encounters (
  Id CHAR(36) ,
  START DATETIME NOT NULL,
  STOP DATETIME NOT NULL,
  PATIENT CHAR(36) NOT NULL,
  ORGANIZATION CHAR(36) NOT NULL,
  PAYER CHAR(36) NOT NULL,
  ENCOUNTERCLASS VARCHAR(50),
  CODE VARCHAR(20),
  DESCRIPTION VARCHAR(255),
  BASE_ENCOUNTER_COST DECIMAL(10,2),
  TOTAL_CLAIM_COST DECIMAL(10,2),
  PAYER_COVERAGE DECIMAL(10,2),
  REASONCODE VARCHAR(20),
  REASONDESCRIPTION VARCHAR(255)
);


-----------------------------------------------------------------------------------------------------
--CREATING THE silver schema;
CREATE SCHEMA silver;
GO 

--Creating the silver schema tables
--Creating table silver.payers
DROP TABLE IF EXISTS silver.payers;
GO
CREATE TABLE silver.payers (
	payer_key INT IDENTITY(1,1) PRIMARY KEY,
    payer_id CHAR(36) ,
    payer_name VARCHAR(100),
    payer_address VARCHAR(255),
    payer_city VARCHAR(100),
    state_headquartered  CHAR(2),
	payer_state VARCHAR(50),
    ZIP VARCHAR(10),
    phone VARCHAR(20),
	UpdatedAt DATETIME
);

--Creating tacle silver.patients
DROP TABLE IF EXISTS silver.patients;
GO
CREATE TABLE silver.patients (
	patient_key INT IDENTITY(1,1) PRIMARY KEY,
    patient_id CHAR(36),
    birth_date DATE,
    death_date DATE,
    patient_name VARCHAR(255),
    suffix VARCHAR(10),
    maiden BIT,
    marital_status CHAR(10),
    race VARCHAR(50),
    ethnicity VARCHAR(50),
    gender CHAR(10),
    birth_place VARCHAR(255),
    patient_address VARCHAR(255),
    patient_city VARCHAR(100),
    patient_state VARCHAR(100),
    patient_county VARCHAR(100),
    ZIP VARCHAR(10),
    LAT DECIMAL(9,6),
    LON DECIMAL(9,6),
	UpdatedAt DATETIME
);

--Creating table silver.encounters
DROP TABLE IF EXISTS silver.encounters;
GO
CREATE TABLE silver.encounters (
  encounter_key INT IDENTITY(1,1) PRIMARY KEY,
  encounter_id CHAR(36) ,
  start DATETIME NOT NULL,
  stop DATETIME NOT NULL,
  encounter_duration_MIN INT,
  patient_key  CHAR(36) NOT NULL,
  organization CHAR(36) NOT NULL,
  payer_key CHAR(36) NOT NULL,
  encounterclass VARCHAR(50),
  encounter_code VARCHAR(20),
  encounter_description VARCHAR(255),
  base_encounter_cost DECIMAL(10,2),
  total_claim_cost DECIMAL(10,2),
  payer_coverage DECIMAL(10,2),
  reason_code VARCHAR(20),
  reason_description VARCHAR(255),
  RecordedAt DATETIME
);


--Creating table silver.procedure
DROP TABLE IF EXISTS silver.procedures;
GO
CREATE TABLE silver.procedures (
	procedure_key INT IDENTITY(1,1) PRIMARY KEY,
    start DATETIME,
    stop DATETIME,
    procedure_duration_MIN INT,
    patient_key INT,
	procedure_code VARCHAR(20),
	procedure_description VARCHAR(255),
    base_procedure_cost INT,
    reason_code VARCHAR(20),
    reason_description VARCHAR(255)
);


