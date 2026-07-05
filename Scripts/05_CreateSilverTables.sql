/*
==============================================================================
Script:      05_CreateSilverTables.sql
Purpose:     Creates the four Silver tables with enforced types.
Layer:       Silver
Source:      bronze.hris_employees, bronze.ats_requisitions,
             bronze.ats_candidates, bronze.survey_engagement
Target:      silver.hris_employees, silver.ats_requisitions,
             silver.ats_candidates, silver.survey_engagement
Run order:   5th — after 04_LoadBronze.sql.
==============================================================================
Design note: unlike Bronze, Silver columns are properly typed (DATE, INT)
because by this point Business_Rules.md validation has already run — the
load procedure (06_LoadSilver.sql) uses TRY_CONVERT so a malformed source
value becomes a clean NULL here rather than a failed load.
==============================================================================
*/

USE PeopleAnalyticsDW;
GO

IF OBJECT_ID('silver.hris_employees', 'U') IS NOT NULL DROP TABLE silver.hris_employees;
GO
CREATE TABLE silver.hris_employees (
    employee_id         NVARCHAR(20)  NOT NULL,
    hire_date           DATE          NOT NULL,
    termination_date    DATE          NULL,
    termination_reason  NVARCHAR(100) NULL,
    department          NVARCHAR(100) NULL,
    job_title           NVARCHAR(150) NULL,
    job_level           NVARCHAR(50)  NULL,
    location            NVARCHAR(100) NULL,
    gender              NVARCHAR(30)  NULL,
    manager_id          NVARCHAR(20)  NULL,
    employment_status   NVARCHAR(30)  NOT NULL,
    dw_load_date        DATETIME2     DEFAULT SYSDATETIME()
);
GO

IF OBJECT_ID('silver.ats_requisitions', 'U') IS NOT NULL DROP TABLE silver.ats_requisitions;
GO
CREATE TABLE silver.ats_requisitions (
    req_id              NVARCHAR(20)  NOT NULL,
    department          NVARCHAR(100) NULL,
    level               NVARCHAR(50)  NULL,
    location            NVARCHAR(100) NULL,
    opened_date         DATE          NOT NULL,
    closed_date         DATE          NULL,
    hiring_manager_id   NVARCHAR(20)  NULL,
    status              NVARCHAR(30)  NOT NULL,
    dw_load_date        DATETIME2     DEFAULT SYSDATETIME()
);
GO

IF OBJECT_ID('silver.ats_candidates', 'U') IS NOT NULL DROP TABLE silver.ats_candidates;
GO
CREATE TABLE silver.ats_candidates (
    candidate_id         NVARCHAR(20)  NOT NULL,
    req_id               NVARCHAR(20)  NULL,
    department           NVARCHAR(100) NULL,
    source               NVARCHAR(50)  NULL,
    applied_date         DATE          NOT NULL,
    furthest_stage       NVARCHAR(30)  NOT NULL,
    furthest_stage_date  DATE          NULL,
    final_status         NVARCHAR(30)  NOT NULL,
    rejection_reason     NVARCHAR(100) NULL,
    dw_load_date         DATETIME2     DEFAULT SYSDATETIME()
);
GO

IF OBJECT_ID('silver.survey_engagement', 'U') IS NOT NULL DROP TABLE silver.survey_engagement;
GO
CREATE TABLE silver.survey_engagement (
    response_id     NVARCHAR(20) NOT NULL,
    employee_id     NVARCHAR(20) NOT NULL,
    department      NVARCHAR(100) NULL,
    survey_quarter  NVARCHAR(10) NOT NULL,
    category        NVARCHAR(50) NOT NULL,
    score           INT          NULL,
    dw_load_date    DATETIME2    DEFAULT SYSDATETIME()
);
GO

PRINT 'Silver tables created successfully.';
GO
