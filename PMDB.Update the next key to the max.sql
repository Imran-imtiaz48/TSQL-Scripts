/*---------------------------------------------------------------------+
| Purpose:   Update the next key to the max if needed
| Notes:     SQLCmdMode Script - Identifies and fixes key mismatches
+----------------------------------------------------------------------*/

:setvar _server "Server1"
:setvar _user "***username***"
:setvar _password "***password***"
:setvar _database "PMDB_TEST"

:connect $(_server) -U $(_user) -P $(_password)

USE [$(_database)];
GO

--=========================
-- Begin Transaction
--=========================
SET XACT_ABORT ON;
BEGIN TRANSACTION;
GO

PRINT '====================================================================='
PRINT 'Step 1: Checking for key mismatches and suggesting fixes'
PRINT '====================================================================='
GO

DECLARE @S NVARCHAR(MAX) = '';

--==========================================
-- CTE to extract table and column names from key_name
--==========================================
WITH key_table_list AS (
    SELECT 
        key_name,
        key_seq_num,
        table_name = LEFT(key_name, CHARINDEX('_', key_name) - 1),
        column_name = RIGHT(key_name, LEN(key_name) - CHARINDEX('_', key_name))
    FROM NEXTKEY
),
--==========================================
-- CTE to generate dynamic SQL to compare max key and next key
--==========================================
single_script AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY tl.table_name) AS RowNumber,
        script = 
            'SELECT table_name = ''' + tl.table_name + ''', ' +
            'max_key_seq_num = MAX(' + QUOTENAME(tl.column_name) + '), ' +
            'key_seq_num = ' + CAST(tl.key_seq_num AS VARCHAR) + ', ' +
            'KeyError = CASE WHEN MAX(' + QUOTENAME(tl.column_name) + ') > ' + CAST(tl.key_seq_num AS VARCHAR) +
            ' THEN ''EXEC dbo.getnextkeys N'''''+ tl.key_name + ''''', '' + ' +
            'CAST(MAX(' + QUOTENAME(tl.column_name) + ') - ' + CAST(tl.key_seq_num AS VARCHAR) + ' + 1 AS VARCHAR) + '', @NewKeyStart OUTPUT'' ' +
            'ELSE NULL END ' +
            'FROM ' + QUOTENAME(tl.table_name)
    FROM key_table_list tl
    INNER JOIN sys.objects ob ON ob.name = tl.table_name
    WHERE ob.type = 'U' -- User tables only
)
--==========================================
-- Build and execute final dynamic SQL
--==========================================
SELECT @S = @S + CASE WHEN RowNumber != 1 THEN ' UNION ALL ' ELSE '' END + script
FROM single_script;

-- Execute the script to find key mismatches
EXEC('SELECT * FROM (' + @S + ') AS result WHERE KeyError IS NOT NULL');
GO

--=========================
-- Manual Fix Section (Optional)
-- Uncomment & use if automatic correction is needed
--=========================
/*
DECLARE @NewKeyStart INT;
DECLARE @nkeys INT;
DECLARE @tabcol NVARCHAR(100);

-- Example usage:
SET @tabcol = N'task_task_id';
SET @nkeys = (SELECT MAX(task_id) - key_seq_num + 1 FROM task, nextkey WHERE key_name = @tabcol);
EXEC dbo.getnextkeys @tabcol = @tabcol, @nkeys = @nkeys, @startkey = @NewKeyStart OUTPUT;

-- Check results:
SELECT key_seq_num FROM nextkey WHERE key_name = @tabcol;
SELECT MAX(task_id) FROM task;
*/
GO

PRINT '====================================================================='
PRINT 'Finished key mismatch analysis. Review suggested scripts above.'
PRINT '====================================================================='
GO

--=========================
-- Rollback by default
--=========================
ROLLBACK TRANSACTION;
-- Use COMMIT only after verifying the fixes are correct
-- COMMIT TRANSACTION;
