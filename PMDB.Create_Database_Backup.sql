/*=======================================================================+
| Purpose   : Create a backup of the specified database
| Usage     : EXEC admin.Create_Database_Backup @DatabaseName = 'PMDB1_TEST'
| Author    : Amit Patel (SQL DBA)
| Date      : [Insert Date]
| Notes     : Ensure the SQL Server Agent service account has access to
|             the backup folder path. Customize the path logic as needed.
+========================================================================*/

-- SQLCMD mode variables (used if running from SSMS in SQLCMD mode)
:setvar _server "Server1"
:setvar _user "***username***"
:setvar _password "***password***"
:setvar _database "master"

-- Connect to the instance
:connect $(_server) -U $(_user) -P $(_password)

USE [$(_database)];
GO

IF NOT EXISTS (
    SELECT 1 
    FROM sys.schemas 
    WHERE name = 'admin'
)
BEGIN
    EXEC('CREATE SCHEMA admin');
END
GO

CREATE OR ALTER PROCEDURE [admin].[Create_Database_Backup]
(
    @DatabaseName SYSNAME
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Initialize variables
    DECLARE 
        @SourceDB SYSNAME = @DatabaseName,
        @BackupUser NVARCHAR(255),
        @DateStamp CHAR(20),
        @TargetPath NVARCHAR(500),
        @BackupFile NVARCHAR(500),
        @SQL NVARCHAR(MAX);

    PRINT '====================================================================='
    PRINT 'Creating database backup for: ' + @SourceDB
    PRINT '====================================================================='

    -- Extract backup operator's username
    SET @BackupUser = PARSENAME(REPLACE(SUSER_SNAME(), '\', '.'), 1);

    -- Generate timestamp
    SET @DateStamp = FORMAT(GETDATE(), 'yyyyMMdd_HHmmss');

    -- Set default backup path based on server name
    -- TODO: Standardize across environments
    IF @@SERVERNAME = 'Server1'
        SET @TargetPath = 'C:\Temp\';
    ELSE
        SET @TargetPath = 'C:\Backups\'; -- fallback/default

    -- Compose full backup file path
    SET @BackupFile = CONCAT(@TargetPath, @SourceDB, '_', @DateStamp, '_', @BackupUser, '.bak');

    PRINT 'Backup file path: ' + @BackupFile;

    -- Verify database existence
    IF EXISTS (SELECT 1 FROM sys.databases WHERE name = @SourceDB)
    BEGIN
        SET @SQL = '
        BACKUP DATABASE [' + @SourceDB + ']
        TO DISK = N''' + @BackupFile + '''
        WITH FORMAT,
             INIT,
             NAME = N''' + @SourceDB + '_Full_Backup_' + @DateStamp + ''',
             MEDIANAME = N''' + @BackupUser + ''',
             STATS = 10;
        ';

        PRINT 'Executing backup command...';
        PRINT @SQL;
        EXEC (@SQL);
        PRINT 'Backup completed successfully.';
    END
    ELSE
    BEGIN
        RAISERROR('Database "%s" does not exist.', 16, 1, @SourceDB);
    END

    PRINT '====================================================================='
    PRINT 'Backup procedure finished.'
    PRINT '====================================================================='
END
GO
