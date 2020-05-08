USE [master];
SET NOCOUNT ON;
DECLARE @FileNumber int = 0; -- ERRORLOG File Number
CREATE TABLE #logexclusions ([TextWildcard] nvarchar(250));
/* ********** START: VALUES TO EXCLUDE ********** */
INSERT INTO #logexclusions
/* ... */ SELECT SUBSTRING(@@VERSION, 1, 30) + '%'
UNION ALL SELECT N'%This is an informational message%'
UNION ALL SELECT N'%transactions rolled back in database%'
UNION ALL SELECT N'%transactions rolled forward in database%'
UNION ALL SELECT N'(c) Microsoft Corporation%'
UNION ALL SELECT N'A new instance of the full-text filter daemon host process%'
UNION ALL SELECT N'A self-generated certificate was%'
UNION ALL SELECT N'All rights reserved%'
UNION ALL SELECT N'Authentication mode is%'
UNION ALL SELECT N'BACKUP DATABASE%'
UNION ALL SELECT N'CHECKDB for database % finished without errors%'
UNION ALL SELECT N'Clearing tempdb database%'
UNION ALL SELECT N'CLR version v%'
UNION ALL SELECT N'Command Line Startup Parameters%'
UNION ALL SELECT N'Common language runtime%'
UNION ALL SELECT N'Configuration option % Run the RECONFIGURE statement to install%'
UNION ALL SELECT N'Database backed up%'
UNION ALL SELECT N'Database differential changes were backed up%'
UNION ALL SELECT N'Database was restored: Database:%'
UNION ALL SELECT N'DBCC CHECKDB%'
UNION ALL SELECT N'Dedicated admin connection support was established%'
UNION ALL SELECT N'Default collation:%'
UNION ALL SELECT N'Error: %' -- remove error message numbers
UNION ALL SELECT N'FILESTREAM: effective level = 3, configured level = 3%'
UNION ALL SELECT N'Informational: No full-text supported languages found%'
UNION ALL SELECT N'Length specified in network packet payload did not match number of bytes read; the connection has been closed%'
UNION ALL SELECT N'Log was backed up%'
UNION ALL SELECT N'Logging SQL Server messages in file%'
UNION ALL SELECT N'Login [fs]%d for user%'
UNION ALL SELECT N'Recovery is writing a checkpoint in database%'
UNION ALL SELECT N'Registry startup parameters%'
UNION ALL SELECT N'RESTORE DATABASE successfully processed%'
UNION ALL SELECT N'Restore is complete on database%'
UNION ALL SELECT N'Server is listening on%'
UNION ALL SELECT N'Server local connection provider is ready to accept connection on%'
UNION ALL SELECT N'Server named pipe provider is ready to accept connection on%'
UNION ALL SELECT N'Server process ID is%'
UNION ALL SELECT N'Service Broker manager has shut down%'
UNION ALL SELECT N'Service Broker manager has started%'
UNION ALL SELECT N'Setting database option%'
UNION ALL SELECT N'Software Usage Metrics is enabled.%'
UNION ALL SELECT N'SQL Server cannot accept new connections, because it is shutting down%'
UNION ALL SELECT N'SQL Server is not ready to accept new client connections%'
UNION ALL SELECT N'SQL Trace ID 1 was started by login%'
UNION ALL SELECT N'Starting up database %'
UNION ALL SELECT N'Synchronize Database % with Resource Database.%'
UNION ALL SELECT N'System Manufacturer%'
UNION ALL SELECT N'The client was unable to reuse a session with SPID%'
UNION ALL SELECT N'The database % is marked RESTORING and is in a state that does not allow recovery to be run.%'
UNION ALL SELECT N'The Database Mirroring endpoint is in%'
UNION ALL SELECT N'The Database Mirroring protocol transport is disabled or not configured%'
UNION ALL SELECT N'The error log has been reinitialized%'
UNION ALL SELECT N'The maximum number of dedicated administrator connections%'
UNION ALL SELECT N'The Service Broker endpoint is in%'
UNION ALL SELECT N'The Service Broker protocol transport is disabled or not configured%'
UNION ALL SELECT N'The SQL Server Network Interface library successfully registered the%'
UNION ALL SELECT N'The tempdb database has % data file(s).%'
UNION ALL SELECT N'This instance of SQL Server has been using a process ID%'
UNION ALL SELECT N'Transparent Data Encryption is not available in the edition of this SQL Server instance%'
UNION ALL SELECT N'Using conventional memory in the memory manager%'
UNION ALL SELECT N'Using locked pages in the memory manager%'
UNION ALL SELECT N'UTC adjustment%';
/* ********** END: VALUES TO EXCLUDE ********** */
DECLARE @SQLcmd nvarchar(max) = N'';
SELECT @SQLcmd = @SQLcmd + N'AND [Text] NOT LIKE N''' + [TextWildcard] + N''' ' /* <-- [note extra space] */ FROM #logexclusions;
--PRINT @SQLcmd;
CREATE TABLE #readerrorlog ( [LogDate] datetime, [ProcessInfo] varchar(10), [Text] nvarchar(4000) );
INSERT INTO #readerrorlog EXEC sp_readerrorlog @FileNumber;
SET @SQLcmd = N'SELECT [LogDate], [Text] FROM #readerrorlog WHERE 1=1 AND LTRIM(RTRIM([Text])) != '''' ' + @SQLcmd + N'ORDER BY [LogDate] ASC;';
--PRINT @SQLcmd;
EXEC sp_executesql @SQLcmd;
DROP TABLE #logexclusions;
DROP TABLE #readerrorlog;
