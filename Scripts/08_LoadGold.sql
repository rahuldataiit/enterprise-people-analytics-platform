/*
==============================================================================
Script:      08_LoadGold.sql
Purpose:     Creates gold.load_gold — a stored procedure that populates the
             star schema from Silver: dimensions first, then facts.
Layer:       Gold
Source:      silver.* tables
Target:      gold.Dim* and gold.Fact* tables
Run order:   8th — after 07_CreateGoldTables.sql. Execute with:
                 EXEC gold.load_gold;
==============================================================================
Load order matters: dimensions are loaded before facts because facts join
to dimensions to resolve surrogate keys. Facts that fail to resolve a
dimension key are excluded rather than loaded with a fake key — and the
row counts printed at each step make such exclusions visible.

Key design decisions implemented here:
  - DimDate is generated as a proper calendar (2022-01-01 → 2026-12-31)
    rather than derived only from dates present in the data — a fact
    joining to a missing date should be impossible by construction.
  - FactEmployeeSnapshot is built by joining every employee to every
    month-end date in their employment window (periodic snapshot grain,
    Solution_Architecture.md §7.4). HeadcountFlag = employed on that
    month-end; New hire/termination flags = event occurred that month.
  - An employee terminated mid-month appears in that month's snapshot row
    with TerminationFlag = 1 but HeadcountFlag = 0 — so a month's
    headcount and its terminations reconcile cleanly.
  - TimeToFillDays lives on hired candidate rows only, computed from the
    requisition's opened→closed dates.
  - FactSurvey maps each survey quarter to its quarter-end DateSK, so the
    lagged engagement-vs-attrition analysis is a simple date-key join.
==============================================================================
*/

USE PeopleAnalyticsDW;
GO

CREATE OR ALTER PROCEDURE gold.load_gold
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @batch_start DATETIME2 = SYSDATETIME();
    DECLARE @rows INT;

    BEGIN TRY

        PRINT '==============================================================';
        PRINT 'Loading Gold Layer';
        PRINT '==============================================================';

        -- -----------------------------------------------------------------
        -- Clear facts first, then dimensions (FK order)
        -- -----------------------------------------------------------------
        DELETE FROM gold.FactEmployeeSnapshot;
        DELETE FROM gold.FactRecruitment;
        DELETE FROM gold.FactSurvey;
        DELETE FROM gold.DimEmployee;
        DELETE FROM gold.DimDepartment;
        DELETE FROM gold.DimLocation;
        DELETE FROM gold.DimJobLevel;
        DELETE FROM gold.DimRecruitmentSource;
        DELETE FROM gold.DimDate;

        -- -----------------------------------------------------------------
        -- gold.DimDate — full calendar 2022-01-01 → 2026-12-31
        -- -----------------------------------------------------------------
        PRINT '>> Loading gold.DimDate';

        ;WITH n AS (
            SELECT TOP (DATEDIFF(DAY, '2022-01-01', '2026-12-31') + 1)
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS i
            FROM sys.all_objects a CROSS JOIN sys.all_objects b
        ),
        cal AS (
            SELECT DATEADD(DAY, i, CAST('2022-01-01' AS DATE)) AS d FROM n
        )
        INSERT INTO gold.DimDate (DateSK, FullDate, [Year], [Quarter], QuarterName, [Month], MonthName, IsMonthEnd)
        SELECT
            YEAR(d) * 10000 + MONTH(d) * 100 + DAY(d),
            d,
            YEAR(d),
            DATEPART(QUARTER, d),
            CAST(YEAR(d) AS NVARCHAR(4)) + '-Q' + CAST(DATEPART(QUARTER, d) AS NVARCHAR(1)),
            MONTH(d),
            DATENAME(MONTH, d),
            CASE WHEN d = EOMONTH(d) THEN 1 ELSE 0 END
        FROM cal;

        SET @rows = @@ROWCOUNT;
        PRINT '   Rows loaded: ' + CAST(@rows AS NVARCHAR(20));

        -- -----------------------------------------------------------------
        -- Small dimensions from Silver distincts
        -- -----------------------------------------------------------------
        PRINT '>> Loading gold.DimDepartment';
        INSERT INTO gold.DimDepartment (DepartmentName)
        SELECT DISTINCT department FROM silver.hris_employees WHERE department IS NOT NULL
        UNION
        SELECT DISTINCT department FROM silver.ats_requisitions WHERE department IS NOT NULL
        UNION
        SELECT DISTINCT department FROM silver.ats_candidates WHERE department IS NOT NULL
        UNION
        SELECT DISTINCT department FROM silver.survey_engagement WHERE department IS NOT NULL;
        PRINT '   Rows loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

        PRINT '>> Loading gold.DimLocation';
        INSERT INTO gold.DimLocation (LocationName)
        SELECT DISTINCT location FROM silver.hris_employees WHERE location IS NOT NULL
        UNION
        SELECT DISTINCT location FROM silver.ats_requisitions WHERE location IS NOT NULL;
        PRINT '   Rows loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

        PRINT '>> Loading gold.DimJobLevel';
        INSERT INTO gold.DimJobLevel (LevelName)
        SELECT DISTINCT job_level FROM silver.hris_employees WHERE job_level IS NOT NULL
        UNION
        SELECT DISTINCT level FROM silver.ats_requisitions WHERE level IS NOT NULL;
        PRINT '   Rows loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

        PRINT '>> Loading gold.DimRecruitmentSource';
        INSERT INTO gold.DimRecruitmentSource (SourceName)
        SELECT DISTINCT source FROM silver.ats_candidates WHERE source IS NOT NULL;
        PRINT '   Rows loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

        -- -----------------------------------------------------------------
        -- gold.DimEmployee (SCD2 structure; initial load = one current row)
        -- -----------------------------------------------------------------
        PRINT '>> Loading gold.DimEmployee';
        INSERT INTO gold.DimEmployee (
            EmployeeID, Gender, HireDate, TerminationDate, TerminationReason,
            EmploymentStatus, JobTitle, ManagerID,
            EffectiveFrom, EffectiveTo, IsCurrent
        )
        SELECT
            employee_id, gender, hire_date, termination_date, termination_reason,
            employment_status, job_title, manager_id,
            hire_date,      -- EffectiveFrom: valid from hire on initial load
            NULL,           -- EffectiveTo: open-ended
            1               -- IsCurrent
        FROM silver.hris_employees;
        PRINT '   Rows loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

        -- -----------------------------------------------------------------
        -- gold.FactEmployeeSnapshot — periodic monthly snapshot
        -- Grain: one row per employee per month-end during their tenure,
        -- plus the month of termination (so term events are captured even
        -- when the employee is no longer active at month-end).
        -- -----------------------------------------------------------------
        PRINT '>> Loading gold.FactEmployeeSnapshot';

        INSERT INTO gold.FactEmployeeSnapshot (
            EmployeeSK, DepartmentSK, LocationSK, JobLevelSK, DateSK,
            HeadcountFlag, NewHireFlag, TerminationFlag,
            VoluntaryTerminationFlag, TenureDays
        )
        SELECT
            de.EmployeeSK,
            dd_dept.DepartmentSK,
            dl.LocationSK,
            djl.JobLevelSK,
            d.DateSK,
            -- Employed on this month-end date?
            CASE WHEN e.hire_date <= d.FullDate
                  AND (e.termination_date IS NULL OR e.termination_date > d.FullDate)
                 THEN 1 ELSE 0 END,
            -- Hired during this month?
            CASE WHEN EOMONTH(e.hire_date) = d.FullDate THEN 1 ELSE 0 END,
            -- Terminated during this month?
            CASE WHEN e.termination_date IS NOT NULL
                  AND EOMONTH(e.termination_date) = d.FullDate
                 THEN 1 ELSE 0 END,
            CASE WHEN e.termination_date IS NOT NULL
                  AND EOMONTH(e.termination_date) = d.FullDate
                  AND e.termination_reason LIKE 'Voluntary%'
                 THEN 1 ELSE 0 END,
            -- Tenure as of snapshot (only while employed)
            CASE WHEN e.hire_date <= d.FullDate
                 THEN DATEDIFF(DAY, e.hire_date,
                          CASE WHEN e.termination_date IS NOT NULL
                                AND e.termination_date <= d.FullDate
                               THEN e.termination_date
                               ELSE d.FullDate END)
                 ELSE NULL END
        FROM silver.hris_employees e
        JOIN gold.DimEmployee de        ON de.EmployeeID = e.employee_id AND de.IsCurrent = 1
        JOIN gold.DimDepartment dd_dept ON dd_dept.DepartmentName = e.department
        JOIN gold.DimLocation dl        ON dl.LocationName = e.location
        JOIN gold.DimJobLevel djl       ON djl.LevelName = e.job_level
        JOIN gold.DimDate d
            ON d.IsMonthEnd = 1
           AND d.FullDate >= EOMONTH(e.hire_date)
           AND d.FullDate <= EOMONTH(COALESCE(e.termination_date, CAST(GETDATE() AS DATE)));

        SET @rows = @@ROWCOUNT;
        PRINT '   Rows loaded: ' + CAST(@rows AS NVARCHAR(20));

        -- -----------------------------------------------------------------
        -- gold.FactRecruitment — one row per candidate application
        -- -----------------------------------------------------------------
        PRINT '>> Loading gold.FactRecruitment';

        INSERT INTO gold.FactRecruitment (
            CandidateID, ReqID, DepartmentSK, SourceSK, AppliedDateSK,
            FurthestStage, FinalStatus, RejectionReason,
            HiredFlag, ReachedPhoneScreenFlag, ReachedOnsiteFlag, ReachedOfferFlag,
            TimeToFillDays
        )
        SELECT
            c.candidate_id,
            c.req_id,
            dd.DepartmentSK,
            ds.SourceSK,
            YEAR(c.applied_date) * 10000 + MONTH(c.applied_date) * 100 + DAY(c.applied_date),
            c.furthest_stage,
            c.final_status,
            c.rejection_reason,
            CASE WHEN c.furthest_stage = 'Hired' THEN 1 ELSE 0 END,
            CASE WHEN c.furthest_stage IN ('Phone Screen','Onsite','Offer','Hired') THEN 1 ELSE 0 END,
            CASE WHEN c.furthest_stage IN ('Onsite','Offer','Hired') THEN 1 ELSE 0 END,
            CASE WHEN c.furthest_stage IN ('Offer','Hired') THEN 1 ELSE 0 END,
            CASE WHEN c.furthest_stage = 'Hired'
                 THEN DATEDIFF(DAY, r.opened_date, r.closed_date)
                 ELSE NULL END
        FROM silver.ats_candidates c
        JOIN gold.DimDepartment dd ON dd.DepartmentName = c.department
        JOIN gold.DimRecruitmentSource ds ON ds.SourceName = c.source
        LEFT JOIN silver.ats_requisitions r ON r.req_id = c.req_id;

        SET @rows = @@ROWCOUNT;
        PRINT '   Rows loaded: ' + CAST(@rows AS NVARCHAR(20));

        -- -----------------------------------------------------------------
        -- gold.FactSurvey — one row per response; quarter mapped to
        -- quarter-end DateSK for lagged joins against the snapshot fact
        -- -----------------------------------------------------------------
        PRINT '>> Loading gold.FactSurvey';

        INSERT INTO gold.FactSurvey (
            ResponseID, EmployeeSK, DepartmentSK, SurveyDateSK,
            SurveyQuarter, Category, Score
        )
        SELECT
            s.response_id,
            de.EmployeeSK,
            dd.DepartmentSK,
            -- quarter-end date: Q1→0331, Q2→0630, Q3→0930, Q4→1231
            CAST(LEFT(s.survey_quarter, 4) AS INT) * 10000
              + CASE RIGHT(s.survey_quarter, 1)
                    WHEN '1' THEN 331
                    WHEN '2' THEN 630
                    WHEN '3' THEN 930
                    WHEN '4' THEN 1231
                END,
            s.survey_quarter,
            s.category,
            s.score
        FROM silver.survey_engagement s
        JOIN gold.DimEmployee de ON de.EmployeeID = s.employee_id AND de.IsCurrent = 1
        JOIN gold.DimDepartment dd ON dd.DepartmentName = s.department;

        SET @rows = @@ROWCOUNT;
        PRINT '   Rows loaded: ' + CAST(@rows AS NVARCHAR(20));

        PRINT '==============================================================';
        PRINT 'Gold Layer Load Complete — Total Duration: '
              + CAST(DATEDIFF(SECOND, @batch_start, SYSDATETIME()) AS NVARCHAR(10)) + 's';
        PRINT '==============================================================';

    END TRY
    BEGIN CATCH
        PRINT '==============================================================';
        PRINT 'ERROR LOADING GOLD LAYER';
        PRINT 'Error Message : ' + ERROR_MESSAGE();
        PRINT 'Error Number  : ' + CAST(ERROR_NUMBER() AS NVARCHAR(20));
        PRINT 'Error Line    : ' + CAST(ERROR_LINE() AS NVARCHAR(20));
        PRINT '==============================================================';
        THROW;
    END CATCH
END
GO

PRINT 'Procedure gold.load_gold created successfully. Execute with: EXEC gold.load_gold;';
GO
