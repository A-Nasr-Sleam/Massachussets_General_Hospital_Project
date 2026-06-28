--testing stage.encounters table
SELECT TOP(20) *
FROM stage.encounters
SELECT COUNT(*)
FROM [stage].[encounters]


--testing stage.patients table
SELECT TOP(20) *
FROM stage.patients
SELECT COUNT(*)
FROM stage.patients


--testing stage.patients table
SELECT TOP(20) *
FROM stage.payers
SELECT COUNT(*)
FROM stage.payers


--testing stage.patients table
SELECT TOP(20) *
FROM stage.procedures
SELECT COUNT(*)
FROM stage.procedures
