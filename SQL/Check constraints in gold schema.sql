USE hospital_db;
GO

SELECT 
    SCHEMA_NAME(t.schema_id) AS [Schema],
    t.name AS [Table Name],
    c.name AS [Constraint Name],
    CASE c.type 
        WHEN 'F' THEN 'Foreign Key'
        WHEN 'PK' THEN 'Primary Key'
        WHEN 'UQ' THEN 'Unique Constraint'
        WHEN 'C' THEN 'Check Constraint'
        ELSE c.type_desc
    END AS [Constraint Type],
    -- Shows if a FK/Check constraint is actively blocking bad inserts
    CASE 
        WHEN OBJECTPROPERTY(c.object_id, 'CnstIsDisabled') = 1 THEN 'Disabled'
        ELSE 'Active'
    END AS [Status],
    -- Shows if the existing data was actually validated (with CHECK)
    CASE 
        WHEN OBJECTPROPERTY(c.object_id, 'CnstIsNotTrusted') = 1 THEN 'Not Trusted (Unverified Data)'
        ELSE 'Trusted (Verified)'
    END AS [Data Integrity]
FROM sys.objects c
INNER JOIN sys.tables t ON c.parent_object_id = t.object_id
WHERE SCHEMA_NAME(t.schema_id) = 'gold'
ORDER BY [Constraint Type] DESC,[Table Name];
GO