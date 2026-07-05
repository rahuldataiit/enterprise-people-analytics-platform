/*
==============================================================================
Script:      03_CreateBronzeTables.sql
Purpose:     Creates the four Bronze landing tables, one per source CSV.
Layer:       Bronze
Source:      hris_employees.csv, ats_requisitions.csv, ats_candidates.csv,
             survey_engagement.csv
Target:      bronze.hris_employees, bronze.ats_requisitions,
             bronze.ats_candidates, bronze.survey_engagement
Run order:   3rd — after 02_CreateSchemas.sql.
==============================================================================
Design note (Solution_Architecture.md §5): Bronze columns are typed as
NVARCHAR wherever the source could plausibly contain a dirty value (blank,
malformed date, stray whitespace). This is deliberate — Bronze's only job is
a faithful, load-tolerant copy of the source; type enforcement and validation
belong to Silver (Business_Rules.md), not here. Every table also carries two
load-metadata columns not present in the source file.
==============================================================================
*/

USE PeopleAnalyticsDW;
GO

-- -----------------------------------------------------------------------
-- bronze.hris_employees
-- -----------------------------------------------------------------------
IF OBJECT_ID('bronze.hris_employees', 'U') IS NOT NULL
    DROP TABLE bronze.hris_employees;
GO

CREATE TABLE bronze.hris_employees (
    employee_id         NVARCHAR(20),
    hire_date           NVARCHAR(20),
    termination_date    NVARCHAR(20),
    termination_reason  NVARCHAR(100),
    department          NVARCHAR(100),
    job_title           NVARCHAR(150),
    job_level           NVARCHAR(50),
    location             NVARCHAR(100),
    gender              NVARCHAR(30),
    manager_id          NVARCHAR(20),
    employment_status   NVARCHAR(30),
    dw_load_date        DATETIME2 DEFAULT SYSDATETIME(),
    dw_source_file      NVARCHAR(255)
);
GO

-- -----------------------------------------------------------------------
-- bronze.ats_requisitions
-- -----------------------------------------------------------------------
IF OBJECT_ID('bronze.ats_requisitions', 'U') IS NOT NULL
    DROP TABLE bronze.ats_requisitions;
GO

CREATE TABLE bronze.ats_requisitions (
    req_id              NVARCHAR(20),
    department          NVARCHAR(100),
    level               NVARCHAR(50),
    location            NVARCHAR(100),
    opened_date         NVARCHAR(20),
    closed_date         NVARCHAR(20),
    hiring_manager_id   NVARCHAR(20),
    status              NVARCHAR(30),
    dw_load_date        DATETIME2 DEFAULT SYSDATETIME(),
    dw_source_file      NVARCHAR(255)
);
GO

-- -----------------------------------------------------------------------
-- bronze.ats_candidates
-- -----------------------------------------------------------------------
IF OBJECT_ID('bronze.ats_candidates', 'U') IS NOT NULL
    DROP TABLE bronze.ats_candidates;
GO

CREATE TABLE bronze.ats_candidates (
    candidate_id         NVARCHAR(20),
    req_id               NVARCHAR(20),
    department           NVARCHAR(100),
    source               NVARCHAR(50),
    applied_date         NVARCHAR(20),
    furthest_stage       NVARCHAR(30),
    furthest_stage_date  NVARCHAR(20),
    final_status         NVARCHAR(30),
    rejection_reason     NVARCHAR(100),
    dw_load_date         DATETIME2 DEFAULT SYSDATETIME(),
    dw_source_file       NVARCHAR(255)
);
GO

-- -----------------------------------------------------------------------
-- bronze.survey_engagement
-- -----------------------------------------------------------------------
IF OBJECT_ID('bronze.survey_engagement', 'U') IS NOT NULL
    DROP TABLE bronze.survey_engagement;
GO

CREATE TABLE bronze.survey_engagement (
    response_id     NVARCHAR(20),
    employee_id     NVARCHAR(20),
    department      NVARCHAR(100),
    survey_quarter  NVARCHAR(10),
    category        NVARCHAR(50),
    score           NVARCHAR(10),
    dw_load_date    DATETIME2 DEFAULT SYSDATETIME(),
    dw_source_file  NVARCHAR(255)
);
GO

PRINT 'Bronze tables created successfully.';
GO
