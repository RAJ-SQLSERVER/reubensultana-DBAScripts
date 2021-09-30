/* Source: https://github.com/reubensultana/DBAScripts/blob/master/Audit+Security/ExportPermissions-ToTable.sql */

/* NOTE: This script should be run using SQLCMD mode */
:ON ERROR EXIT

:SETVAR DebugMode "0"
:SETVAR TicketReference "123456789"

:SETVAR TargetSQLServerInstance "localhost,14330"
:SETVAR TargetDatabaseName "msdb"

/* ---------- CONVERT SQLCMD VALUES to TSQL VARIABLES  ---------- */

/* ---------- START HERE  ---------- */
--:CONNECT $(TargetSQLServerInstance)
USE [tempdb]
GO
DECLARE @SqlCmd nvarchar(max);

/* ---------- Create supporting objects ---------- */
IF (OBJECT_ID('[dbo].[CommandLog]') IS NULL)
BEGIN
    SET @SqlCmd = N'
CREATE TABLE [dbo].[CommandLog] (
    [ID] int IDENTITY(1,1) NOT NULL,
    [TicketReference] nvarchar(20) NOT NULL,
    [DatabaseName] nvarchar(128) NOT NULL,
    [CommandType] nvarchar(60) NOT NULL,
    [Command] nvarchar(max) NOT NULL

);';
END
ELSE
BEGIN
    SET @SqlCmd = N'DELETE FROM [dbo].[CommandLog] WHERE [TicketReference] = ''$(TicketReference)''';
END
IF $(DebugMode) = 1 PRINT @SqlCmd;
ELSE EXEC sp_executesql @SqlCmd;
GO


/* ---------- Export User list ---------- */
--:CONNECT $(TargetSQLServerInstance)
USE [master]
GO
SET NOCOUNT ON;
IF EXISTS(SELECT * FROM sys.databases WHERE [name] = '$(TargetDatabaseName)')
BEGIN
    INSERT INTO [tempdb].[dbo].[CommandLog] ([TicketReference], [DatabaseName], [CommandType], [Command])
    SELECT '$(TicketReference)', '$(TargetDatabaseName)', 'USER_LIST',
        CAST('
IF NOT EXISTS(SELECT * FROM sys.database_principals WHERE [name] = ''' + dp.[name] + ''') 
    CREATE USER ' + QUOTENAME(dp.[name], '[') + N' FOR LOGIN ' + QUOTENAME(sp.[name], '[') COLLATE DATABASE_DEFAULT + N' WITH DEFAULT_SCHEMA = dbo;
ELSE
    ALTER USER ' + QUOTENAME(dp.[name], '[') + N' WITH LOGIN ' + QUOTENAME(sp.[name], '[') COLLATE DATABASE_DEFAULT + N' WITH DEFAULT_SCHEMA = dbo;' AS nvarchar(max))
    FROM [$(TargetDatabaseName)].sys.database_principals dp
        INNER JOIN sys.server_principals sp ON dp.principal_id = sp.principal_id
    -- limit to Groups, Users and SQL Logins
    WHERE dp.[type] LIKE '[GUS]'
    -- exclude "sa" and "guest"
    AND dp.[sid] NOT IN (0x00, 0x01)
    -- exclude unlinked/orphaned users
    AND dp.[sid] IS NOT NULL
    -- exclude those who are already members of the "sysadmins" fixed server role
    AND IS_SRVROLEMEMBER('sysadmin', sp.[name]) = 0
    -- exclude Microsoft Built-In accounts (will eventually need maintaining...)
    AND sp.[name] NOT LIKE '##MS%'
    AND sp.[name] NOT LIKE 'NT SERVICE%'
    -- exclude computer accounts
    AND sp.[name] NOT LIKE '%$'
    ORDER BY dp.[name] ASC
END
GO

/* ---------- Export User permissions ---------- */
--:CONNECT $(TargetSQLServerInstance)
USE [master]
GO
SET NOCOUNT ON;
IF EXISTS(SELECT * FROM sys.databases WHERE [name] = '$(TargetDatabaseName)')
BEGIN
    /* 1. Role membership */
    INSERT INTO [tempdb].[dbo].[CommandLog] ([TicketReference], [DatabaseName], [CommandType], [Command])
    SELECT
        'S(TicketReference)', '$(TargetDatabaseName)', 'ROLE_MEMBERSHIP',
        CAST('ALTER ROLE ' + QUOTENAME([g].[name], '[') + ' ADD MEMBER ' + QUOTENAME([u].[name], '[') + ';' AS nvarchar (max))
    FROM [$(TargetDatabaseName)].[sys].[database_role_members] [m]
        INNER JOIN [$(TargetDatabaseName)].[sys].[database_principals] [u] ON [u].[principal_id] = [m].[member_principal_id]
        INNER JOIN [$(TargetDatabaseName)].[sys].[database_principals] [g] ON [g].[principal_id] = [m].[role_principal_id]
    -- exclude Microsoft Built-In roles (will eventually need maintaining...)
    WHERE [u].[name] NOT IN (
        'dbo'
        ,'public'
        ,'TargetServersRole'
        ,'SQLAgentUserRole'
        ,'SQLAgentReaderRole'
        ,'SQLAgentOperatorRole'
        ,'DatabaseMailUserRole'
        ,'db_ssisadmin'
        ,'db_ssisltduser'
        ,'db_ssisoperator'
        ,'dc_operator'
        ,'dc_admin'
        ,'dc_proxy'
        ,'PolicyAdministratorRole'
        ,'ServerGroupAdministratorRole'
        ,'ServerGroupReaderRole'
        ,'UtilityCMRReader'
        ,'UtilityIMRWriter'
        ,'UtilityIMRReader'
        ,'db_owner'
        ,'db_accessadmin'
        ,'db_securityadmin'
        ,'db_ddladmin'
        ,'db_backupoperator'
        ,'db_datareader'
        ,'db_datawriter'
        ,'db_denydatareader'
        ,'db_denydatawriter'
    ) 
    -- exclude Microsoft Built-In accounts (will eventually need maintaining...)
    AND u.[name] NOT LIKE '##MS%'
    AND u.[name] NOT LIKE 'NT SERVICE%'
    ORDER BY [u].[name], [g].[name];

    /* 2. Extra permissions */
    INSERT INTO [tempdb].[dbo].[CommandLog] ([TicketReference], [DatabaseName], [CommandType], [Command])
    SELECT
        '$(TicketReference)', '$(TargetDatabaseName)', 'EXTRA PERMISSIONS', 
        CAST ([sec].[state_desc] COLLATE DATABASE_DEFAULT + ' ' + [sec].[permission_name] COLLATE DATABASE_DEFAULT +
            CASE WHEN [obj].[name] IS NULL THEN ''
                ELSE ' ON ' + ISNULL(QUOTENAME([sch].[name], '[') COLLATE DATABASE_DEFAULT + '.' + QUOTENAME([obj].[name], '['), 'N/A') COLLATE DATABASE_DEFAULT
            END + 
            ' TO ' + QUOTENAME([prin].[name], '[') COLLATE DATABASE_DEFAULT AS nvarchar(max))
    FROM [$(TargetDatabaseName)].[sys].[database_permissions] [sec]
        INNER JOIN [$(TargetDatabaseName)].[sys].[database_principals] [prin] ON [sec].[grantee_principal_id] = [prin].[principal_id]
        LEFT OUTER JOIN [$(TargetDatabaseName)].[sys].[objects] [obj]
            INNER JOIN [$(TargetDatabaseName)].[sys].[schemas] [sch] ON [sch].[schema_id] = [obj].[schema_id]
        ON [obj].[object_id] = [sec].[major_id]
    WHERE [sec]. [class] IN (0, 1)
    -- exclude Microsoft Built-In roles (will eventually need maintaining...)
    AND [prin].[name] NOT IN (
        'dbo'
        ,'public'
        ,'TargetServersRole'
        ,'SQLAgentUserRole'
        ,'SQLAgentReaderRole'
        ,'SQLAgentOperatorRole'
        ,'DatabaseMailUserRole'
        ,'db_ssisadmin'
        ,'db_ssisltduser'
        ,'db_ssisoperator'
        ,'dc_operator'
        ,'dc_admin'
        ,'dc_proxy'
        ,'PolicyAdministratorRole'
        ,'ServerGroupAdministratorRole'
        ,'ServerGroupReaderRole'
        ,'UtilityCMRReader'
        ,'UtilityIMRWriter'
        ,'UtilityIMRReader'
        ,'db_owner'
        ,'db_accessadmin'
        ,'db_securityadmin'
        ,'db_ddladmin'
        ,'db_backupoperator'
        ,'db_datareader'
        ,'db_datawriter'
        ,'db_denydatareader'
        ,'db_denydatawriter'
    )
    AND [sec].[permission_name] != 'CONNECT'
    -- exclude Microsoft Built-In accounts (will eventually need maintaining...)
    AND [prin].[name] NOT LIKE '##MS%'
    AND [prin].[name] NOT LIKE 'NT SERVICE%'
    ORDER BY [sch].[name], [obj].[name], [obj].[type_desc], [prin].[name], [sec].[state_desc], [sec]. [permission_name];
END
GO
