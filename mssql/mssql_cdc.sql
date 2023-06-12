USE master
GO
-- Create the new database if it does not exist already
IF NOT EXISTS (
       SELECT [name]
              FROM sys.databases
              WHERE [name] = N'RedisConnect'
)
CREATE DATABASE RedisConnect
GO
-- Check and enable database for CDC
SELECT is_cdc_enabled
FROM sys.databases
WHERE name = 'RedisConnect'

use RedisConnect
EXEC sys.sp_cdc_enable_db

SELECT is_cdc_enabled
FROM sys.databases
WHERE name = 'RedisConnect'

-- Create emp table (Please note that MSSQL table names are case sensitive so this name must match the table name in Redis Connect Job Config payload)
CREATE TABLE [RedisConnect].[dbo].[emp] (
    [empno] int NOT NULL,
    [fname] varchar(50),
    [lname] varchar(50),
    [job] varchar(50),
    [mgr] int,
    [hiredate] datetime,
    [sal] decimal(8,2),
    [comm] decimal(8,2),
    [dept] int,
    PRIMARY KEY ([empno])
);
-- create non privileged user for redis connect
CREATE LOGIN redisconnectuser WITH PASSWORD = 'Redisconnectpassword1';
CREATE USER redisconnectuser FOR LOGIN redisconnectuser;

-- create a role for tables with CDC
if not exists(select * from sys.sysusers where name = 'cdc_reader' and issqlrole=1)
	create role cdc_reader;

grant select on SCHEMA:: cdc to cdc_reader;
grant select on SCHEMA:: dbo to cdc_reader;
ALTER ROLE cdc_reader ADD MEMBER redisconnectuser;

-- Enable emp table for CDC
EXEC sys.sp_cdc_enable_table @source_schema = 'dbo'
       , @source_name = 'emp'
       , @role_name = cdc_reader
       , @capture_instance = 'cdcauditing_emp'

-- Query and check the CDC setup
-- Use this Stored proc to return the change data capture configuration for each table enabled for change data capture in the current database.
USE RedisConnect;
EXEC sys.sp_cdc_help_change_data_capture;

-- Tune SQL Server
EXEC sys.sp_cdc_change_job
@job_type = N'capture',
--@maxscans = 1000,
--@maxtrans = 1500,
@pollinginterval = 0
--@continuous = 0;
GO

exec sys.sp_cdc_help_jobs
go