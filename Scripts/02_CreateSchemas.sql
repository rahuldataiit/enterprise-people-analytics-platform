/*
==============================================================================
Script:      02_CreateSchemas.sql
Purpose:     Creates the three Medallion Architecture schemas.
Layer:       N/A (database-level setup)
Source:      N/A
Target:      Schemas: bronze, silver, gold
Run order:   2nd — after 01_CreateDatabase.sql.
==============================================================================
Design note: each schema is a hard boundary per Solution_Architecture.md §3 —
silver objects only ever read from bronze.*, gold objects only ever read from
silver.*. No layer reads two layers down.
==============================================================================
*/

USE PeopleAnalyticsDW;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
    EXEC('CREATE SCHEMA bronze');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
    EXEC('CREATE SCHEMA silver');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC('CREATE SCHEMA gold');
GO

PRINT 'Schemas bronze, silver, gold created successfully.';
GO
