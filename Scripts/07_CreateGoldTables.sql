/*
==============================================================================
Script:      07_CreateGoldTables.sql
Purpose:     Creates the Gold-layer star schema: 6 dimensions + 3 facts,
             per Solution_Architecture.md §7.
Layer:       Gold
Source:      silver.* tables
Target:      gold.DimDate, gold.DimEmployee, gold.DimDepartment,
             gold.DimLocation, gold.DimJobLevel, gold.DimRecruitmentSource,
             gold.FactEmployeeSnapshot, gold.FactRecruitment, gold.FactSurvey
Run order:   7th — after 06_LoadSilver.sql (and EXEC silver.load_silver).
==============================================================================
Design notes:
  - Surrogate keys are IDENTITY(1,1) INTs; natural keys are retained on
    dimensions for traceability (Solution_Architecture.md §4).
  - DateSK uses the YYYYMMDD integer convention (e.g. 20240315) — human
    readable in query results and standard in Kimball-style warehouses.
  - DimEmployee carries SCD Type 2 plumbing (EffectiveFrom/EffectiveTo/
    IsCurrent). The source extract has no change history, so the initial
    load produces one current row per employee — but the structure is in
    place so future loads can expire and re-version rows when an
    employee's department/manager changes.
  - Facts are dropped before dimensions (FK dependency order).
==============================================================================
*/

USE PeopleAnalyticsDW;
GO

-- Drop facts first (they reference dimensions)
IF OBJECT_ID('gold.FactEmployeeSnapshot', 'U') IS NOT NULL DROP TABLE gold.FactEmployeeSnapshot;
IF OBJECT_ID('gold.FactRecruitment', 'U') IS NOT NULL DROP TABLE gold.FactRecruitment;
IF OBJECT_ID('gold.FactSurvey', 'U') IS NOT NULL DROP TABLE gold.FactSurvey;
GO

-- Then dimensions
IF OBJECT_ID('gold.DimEmployee', 'U') IS NOT NULL DROP TABLE gold.DimEmployee;
IF OBJECT_ID('gold.DimDepartment', 'U') IS NOT NULL DROP TABLE gold.DimDepartment;
IF OBJECT_ID('gold.DimLocation', 'U') IS NOT NULL DROP TABLE gold.DimLocation;
IF OBJECT_ID('gold.DimJobLevel', 'U') IS NOT NULL DROP TABLE gold.DimJobLevel;
IF OBJECT_ID('gold.DimRecruitmentSource', 'U') IS NOT NULL DROP TABLE gold.DimRecruitmentSource;
IF OBJECT_ID('gold.DimDate', 'U') IS NOT NULL DROP TABLE gold.DimDate;
GO

-- -----------------------------------------------------------------------
-- Dimensions
-- -----------------------------------------------------------------------

CREATE TABLE gold.DimDate (
    DateSK      INT          NOT NULL PRIMARY KEY,   -- YYYYMMDD
    FullDate    DATE         NOT NULL,
    [Year]      INT          NOT NULL,
    [Quarter]   INT          NOT NULL,
    QuarterName NVARCHAR(10) NOT NULL,               -- e.g. '2024-Q3'
    [Month]     INT          NOT NULL,
    MonthName   NVARCHAR(20) NOT NULL,
    IsMonthEnd  BIT          NOT NULL DEFAULT 0
);
GO

CREATE TABLE gold.DimEmployee (
    EmployeeSK        INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    EmployeeID        NVARCHAR(20)  NOT NULL,        -- natural key
    Gender            NVARCHAR(30)  NULL,
    HireDate          DATE          NOT NULL,
    TerminationDate   DATE          NULL,
    TerminationReason NVARCHAR(100) NULL,
    EmploymentStatus  NVARCHAR(30)  NOT NULL,
    JobTitle          NVARCHAR(150) NULL,
    ManagerID         NVARCHAR(20)  NULL,
    -- SCD Type 2 plumbing
    EffectiveFrom     DATE          NOT NULL,
    EffectiveTo       DATE          NULL,
    IsCurrent         BIT           NOT NULL DEFAULT 1
);
GO

CREATE TABLE gold.DimDepartment (
    DepartmentSK   INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    DepartmentName NVARCHAR(100) NOT NULL
);
GO

CREATE TABLE gold.DimLocation (
    LocationSK   INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    LocationName NVARCHAR(100) NOT NULL
);
GO

CREATE TABLE gold.DimJobLevel (
    JobLevelSK INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    LevelName  NVARCHAR(50) NOT NULL
);
GO

CREATE TABLE gold.DimRecruitmentSource (
    SourceSK   INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    SourceName NVARCHAR(50) NOT NULL
);
GO

-- -----------------------------------------------------------------------
-- Facts
-- -----------------------------------------------------------------------

-- Periodic snapshot: one row per employee per month-end date they were
-- employed (or hired/terminated within that month).
CREATE TABLE gold.FactEmployeeSnapshot (
    EmployeeSK      INT NOT NULL FOREIGN KEY REFERENCES gold.DimEmployee(EmployeeSK),
    DepartmentSK    INT NOT NULL FOREIGN KEY REFERENCES gold.DimDepartment(DepartmentSK),
    LocationSK      INT NOT NULL FOREIGN KEY REFERENCES gold.DimLocation(LocationSK),
    JobLevelSK      INT NOT NULL FOREIGN KEY REFERENCES gold.DimJobLevel(JobLevelSK),
    DateSK          INT NOT NULL FOREIGN KEY REFERENCES gold.DimDate(DateSK),
    HeadcountFlag   INT NOT NULL,   -- 1 if actively employed on this snapshot date
    NewHireFlag     INT NOT NULL,   -- 1 if hired during this snapshot month
    TerminationFlag INT NOT NULL,   -- 1 if terminated during this snapshot month
    VoluntaryTerminationFlag INT NOT NULL,  -- subset of TerminationFlag
    TenureDays      INT NULL        -- days employed as of snapshot date
);
GO

-- One row per candidate application.
CREATE TABLE gold.FactRecruitment (
    CandidateID     NVARCHAR(20) NOT NULL,          -- degenerate dimension
    ReqID           NVARCHAR(20) NULL,              -- degenerate dimension
    DepartmentSK    INT NOT NULL FOREIGN KEY REFERENCES gold.DimDepartment(DepartmentSK),
    SourceSK        INT NOT NULL FOREIGN KEY REFERENCES gold.DimRecruitmentSource(SourceSK),
    AppliedDateSK   INT NOT NULL FOREIGN KEY REFERENCES gold.DimDate(DateSK),
    FurthestStage   NVARCHAR(30) NOT NULL,
    FinalStatus     NVARCHAR(30) NOT NULL,
    RejectionReason NVARCHAR(100) NULL,
    HiredFlag       INT NOT NULL,
    ReachedPhoneScreenFlag INT NOT NULL,
    ReachedOnsiteFlag      INT NOT NULL,
    ReachedOfferFlag       INT NOT NULL,
    TimeToFillDays  INT NULL     -- populated on hired rows: requisition opened -> closed
);
GO

-- One row per employee per survey category per quarter.
CREATE TABLE gold.FactSurvey (
    ResponseID    NVARCHAR(20) NOT NULL,            -- degenerate dimension
    EmployeeSK    INT NOT NULL FOREIGN KEY REFERENCES gold.DimEmployee(EmployeeSK),
    DepartmentSK  INT NOT NULL FOREIGN KEY REFERENCES gold.DimDepartment(DepartmentSK),
    SurveyDateSK  INT NOT NULL FOREIGN KEY REFERENCES gold.DimDate(DateSK),  -- quarter-end date
    SurveyQuarter NVARCHAR(10) NOT NULL,
    Category      NVARCHAR(50) NOT NULL,
    Score         INT NULL
);
GO

PRINT 'Gold star schema created successfully.';
GO
