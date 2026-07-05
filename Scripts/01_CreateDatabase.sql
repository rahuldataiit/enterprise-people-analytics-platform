/*
==============================================================================
Script:      01_CreateDatabase.sql
Purpose:     Creates the People Analytics data warehouse database.
Layer:       N/A (database-level setup)
Source:      N/A
Target:      Database: PeopleAnalyticsDW
Run order:   1st — must run before any other script in this project.
==============================================================================
*/

USE master;
GO

-- Drop and recreate for a clean rebuild during development.
-- Remove this IF EXISTS block once the warehouse is in a stable, shared environment.
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'PeopleAnalyticsDW')
BEGIN
    ALTER DATABASE PeopleAnalyticsDW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE PeopleAnalyticsDW;
END
GO

CREATE DATABASE PeopleAnalyticsDW;
GO

USE PeopleAnalyticsDW;
GO

PRINT 'PeopleAnalyticsDW database created successfully.';
GO
