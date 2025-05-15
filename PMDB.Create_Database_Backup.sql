/*-------------------------------------------------------------------------------+
| Purpose:    Create a backup of a database
| Example:    EXEC admin.Create_Database_Backup 'PMDB1_TEST'
+--------------------------------------------------------------------------------*/

:setvar _server "Server1"
:setvar _user "***username***"
:setvar _password "***password***"
:setvar _database "master"
:connect $(_server) -U $(_user) -P $(_password)

USE [$(_database)];
GO

-- Create procedure to backup a database
CREATE PROCEDURE [admin].[Create_Database_Backup]
(
    @DatabaseName NVARCHAR(50) -- Use NVARCHAR for Unicode support
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Variable declarations
        DECLARE @SourceDB NVARCHAR(50);
        DECLARE @BackupUser NVARCHAR(255);
        DECLARE @DateStamp NVARCHAR(20);
        DECLARE @TargetPath NVARCHAR(255);
        DECLARE @BackupSQL NVARCHAR(MAX);

        PRINT '====================================================================='
        PRINT 'Starting database backup process...'
        PRINT '====================================================================='

        -- Set the name of the database
        SET @SourceDB = @DatabaseName;

        -- Get the username of the person executing the backup
        SET @BackupUser = SUBSTRING(SUSER_SNAME(), CHARINDEX('\', SUSER_SNAME()) + 1, 
                                    LEN(SUSER_SNAME()) - CHARINDEX('\', SUSER_SNAME()));

        -- Get the current date and time
        SET @DateStamp = '_' + CONVERT(NVARCHAR(20), GETDATE(), 112) + '_' 
                         + REPLACE(CONVERT(NVARCHAR(20), GETDATE(), 108), ':', '');

        -- Set the database backup path
        -- TODO: Standardize the backup folder location for all servers
        IF @@SERVERNAME = 'Server1'
            SET @TargetPath = N'C:\Temp\';
        ELSE
            SET @TargetPath = N'D:\Backups\';

        -- Set the backup file name
        SET @TargetPath = @TargetPath + @SourceDB + @DateStamp + '_' + @BackupUser + '.bak';

        PRINT 'Backup file will be saved at: ' + @TargetPath;

        -- Check if the database exists
        IF EXISTS (SELECT name FROM sys.databases WHERE name = @SourceDB)
        BEGIN
            -- Construct the BACKUP SQL command
            SET @BackupSQL = N'
                BACKUP DATABASE [' + @SourceDB + N']
                TO DISK = ''' + @TargetPath + N'''
                WITH FORMAT,
                     MEDIANAME = ''' + @BackupUser + N''',
                     NAME = ''' + @SourceDB + @DateStamp + N'''';

            PRINT 'Executing backup command...';

            -- Execute the backup command
            EXEC sp_executesql @BackupSQL;

            PRINT '====================================================================='
            PRINT 'Database backup completed successfully!'
            PRINT '====================================================================='
        END
        ELSE
        BEGIN
            PRINT '====================================================================='
            PRINT 'Error: The specified database does not exist!'
            PRINT '====================================================================='
        END
    END TRY
    BEGIN CATCH
        -- Handle errors
        PRINT '====================================================================='
        PRINT 'Error occurred during the database backup process.'
        PRINT ERROR_MESSAGE();
        PRINT '====================================================================='
    END CATCH
END
GO
