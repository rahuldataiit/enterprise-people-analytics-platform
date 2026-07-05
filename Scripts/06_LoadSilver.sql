/*
==============================================================================
Script:      06_LoadSilver.sql
Purpose:     Creates silver.load_silver — a reusable stored procedure that
             cleans, standardizes, deduplicates, and validates Bronze data
             into Silver, applying the rules defined in Business_Rules.md.
Layer:       Silver
Source:      bronze.hris_employees, bronze.ats_requisitions,
             bronze.ats_candidates, bronze.survey_engagement
Target:      silver.hris_employees, silver.ats_requisitions,
             silver.ats_candidates, silver.survey_engagement
Run order:   6th — after 05_CreateSilverTables.sql. Execute with:
                 EXEC silver.load_silver;
==============================================================================
Why a stored procedure instead of a plain script (unlike Bronze):
Silver is where actual business logic lives — deduplication, date validation,
derived status fields. That logic needs to be re-run every time Bronze
refreshes, and packaging it as a procedure makes it a single, re-executable,
testable unit rather than a script that has to be manually re-run top to
bottom. It also mirrors how this would actually be scheduled/orchestrated
in a real warehouse (a SQL Agent job or ADF pipeline would call the
procedure, not paste in the script).

Business rules applied here (see Business_Rules.md for full definitions):
  - Employee ID / Requisition ID / Candidate ID / Response ID uniqueness:
    deduplicated via ROW_NUMBER(), keeping the most recently loaded row.
  - Hire Date Validation: rows with an unparseable hire_date are excluded
    (hire_date is the grain of DimEmployee — a row without it is unusable).
  - Termination Date Validation: a termination_date earlier than hire_date
    is treated as bad data and nulled out, rather than dropping the whole
    employee record.
  - Active vs Terminated Employee: recomputed here from termination_date
    rather than trusting the raw source flag, so it's always internally
    consistent with the date fields — single source of truth.
  - Recruitment stage / status standardization: values outside the known
    stage list are normalized to 'Unknown' rather than silently passed
    through, so Gold-layer funnel counts can't be silently corrupted by
    an unexpected source value.
  - Survey score range validation: category scores must be 1-5, eNPS must
    be 0-10; anything outside range becomes NULL rather than skewing
    averages.
  - Missing values / blank strings: standardized to NULL via NULLIF, so
    downstream logic only ever has to check for NULL, not empty string.
==============================================================================
*/

USE PeopleAnalyticsDW;
GO

CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @batch_start DATETIME2 = SYSDATETIME();
    DECLARE @step_start  DATETIME2;
    DECLARE @rows_loaded INT;
    DECLARE @rows_flagged INT;

    BEGIN TRY

        PRINT '==============================================================';
        PRINT 'Loading Silver Layer';
        PRINT '==============================================================';

        -- -----------------------------------------------------------------
        -- silver.hris_employees
        -- -----------------------------------------------------------------
        SET @step_start = SYSDATETIME();
        PRINT '>> Truncating: silver.hris_employees';
        TRUNCATE TABLE silver.hris_employees;

        PRINT '>> Inserting: silver.hris_employees';
        ;WITH deduped AS (
            SELECT *,
                   ROW_NUMBER() OVER (
                       PARTITION BY TRIM(employee_id)
                       ORDER BY dw_load_date DESC
                   ) AS rn
            FROM bronze.hris_employees
            WHERE employee_id IS NOT NULL AND TRIM(employee_id) <> ''
        )
        INSERT INTO silver.hris_employees (
            employee_id, hire_date, termination_date, termination_reason,
            department, job_title, job_level, location, gender, manager_id,
            employment_status
        )
        SELECT
            TRIM(employee_id),
            TRY_CONVERT(DATE, hire_date),
            CASE
                WHEN TRY_CONVERT(DATE, termination_date) IS NOT NULL
                     AND TRY_CONVERT(DATE, termination_date) >= TRY_CONVERT(DATE, hire_date)
                THEN TRY_CONVERT(DATE, termination_date)
                ELSE NULL
            END,
            CASE
                WHEN TRY_CONVERT(DATE, termination_date) IS NOT NULL
                     AND TRY_CONVERT(DATE, termination_date) >= TRY_CONVERT(DATE, hire_date)
                THEN NULLIF(TRIM(termination_reason), '')
                ELSE NULL
            END,
            NULLIF(TRIM(department), ''),
            NULLIF(TRIM(job_title), ''),
            NULLIF(TRIM(job_level), ''),
            NULLIF(TRIM(location), ''),
            NULLIF(TRIM(gender), ''),
            NULLIF(TRIM(manager_id), ''),
            CASE
                WHEN TRY_CONVERT(DATE, termination_date) IS NOT NULL
                     AND TRY_CONVERT(DATE, termination_date) >= TRY_CONVERT(DATE, hire_date)
                THEN 'Terminated'
                ELSE 'Active'
            END
        FROM deduped
        WHERE rn = 1
          AND TRY_CONVERT(DATE, hire_date) IS NOT NULL;

        SET @rows_loaded = @@ROWCOUNT;
        PRINT '   Rows loaded: ' + CAST(@rows_loaded AS NVARCHAR(20))
              + '  |  Duration: ' + CAST(DATEDIFF(SECOND, @step_start, SYSDATETIME()) AS NVARCHAR(10)) + 's';

        -- -----------------------------------------------------------------
        -- silver.ats_requisitions
        -- -----------------------------------------------------------------
        SET @step_start = SYSDATETIME();
        PRINT '>> Truncating: silver.ats_requisitions';
        TRUNCATE TABLE silver.ats_requisitions;

        PRINT '>> Inserting: silver.ats_requisitions';
        ;WITH deduped AS (
            SELECT *,
                   ROW_NUMBER() OVER (
                       PARTITION BY TRIM(req_id)
                       ORDER BY dw_load_date DESC
                   ) AS rn
            FROM bronze.ats_requisitions
            WHERE req_id IS NOT NULL AND TRIM(req_id) <> ''
        )
        INSERT INTO silver.ats_requisitions (
            req_id, department, level, location, opened_date, closed_date,
            hiring_manager_id, status
        )
        SELECT
            TRIM(req_id),
            NULLIF(TRIM(department), ''),
            NULLIF(TRIM(level), ''),
            NULLIF(TRIM(location), ''),
            TRY_CONVERT(DATE, opened_date),
            CASE
                WHEN TRY_CONVERT(DATE, closed_date) IS NOT NULL
                     AND TRY_CONVERT(DATE, closed_date) >= TRY_CONVERT(DATE, opened_date)
                THEN TRY_CONVERT(DATE, closed_date)
                ELSE NULL
            END,
            NULLIF(TRIM(hiring_manager_id), ''),
            CASE
                WHEN UPPER(TRIM(status)) IN ('OPEN', 'FILLED') THEN TRIM(status)
                ELSE 'Unknown'
            END
        FROM deduped
        WHERE rn = 1
          AND TRY_CONVERT(DATE, opened_date) IS NOT NULL;

        SET @rows_loaded = @@ROWCOUNT;
        PRINT '   Rows loaded: ' + CAST(@rows_loaded AS NVARCHAR(20))
              + '  |  Duration: ' + CAST(DATEDIFF(SECOND, @step_start, SYSDATETIME()) AS NVARCHAR(10)) + 's';

        -- -----------------------------------------------------------------
        -- silver.ats_candidates
        -- -----------------------------------------------------------------
        SET @step_start = SYSDATETIME();
        PRINT '>> Truncating: silver.ats_candidates';
        TRUNCATE TABLE silver.ats_candidates;

        PRINT '>> Inserting: silver.ats_candidates';
        ;WITH deduped AS (
            SELECT *,
                   ROW_NUMBER() OVER (
                       PARTITION BY TRIM(candidate_id)
                       ORDER BY dw_load_date DESC
                   ) AS rn
            FROM bronze.ats_candidates
            WHERE candidate_id IS NOT NULL AND TRIM(candidate_id) <> ''
        )
        INSERT INTO silver.ats_candidates (
            candidate_id, req_id, department, source, applied_date,
            furthest_stage, furthest_stage_date, final_status, rejection_reason
        )
        SELECT
            TRIM(candidate_id),
            NULLIF(TRIM(req_id), ''),
            NULLIF(TRIM(department), ''),
            NULLIF(TRIM(source), ''),
            TRY_CONVERT(DATE, applied_date),
            CASE
                WHEN TRIM(furthest_stage) IN ('Applied', 'Phone Screen', 'Onsite', 'Offer', 'Hired')
                THEN TRIM(furthest_stage)
                ELSE 'Unknown'
            END,
            TRY_CONVERT(DATE, furthest_stage_date),
            CASE
                WHEN TRIM(final_status) IN ('Hired', 'Rejected', 'In Process')
                THEN TRIM(final_status)
                ELSE 'Unknown'
            END,
            NULLIF(TRIM(rejection_reason), '')
        FROM deduped
        WHERE rn = 1
          AND TRY_CONVERT(DATE, applied_date) IS NOT NULL;

        SET @rows_loaded = @@ROWCOUNT;
        PRINT '   Rows loaded: ' + CAST(@rows_loaded AS NVARCHAR(20))
              + '  |  Duration: ' + CAST(DATEDIFF(SECOND, @step_start, SYSDATETIME()) AS NVARCHAR(10)) + 's';

        -- -----------------------------------------------------------------
        -- silver.survey_engagement
        -- -----------------------------------------------------------------
        SET @step_start = SYSDATETIME();
        PRINT '>> Truncating: silver.survey_engagement';
        TRUNCATE TABLE silver.survey_engagement;

        PRINT '>> Inserting: silver.survey_engagement';
        ;WITH deduped AS (
            SELECT *,
                   ROW_NUMBER() OVER (
                       PARTITION BY TRIM(response_id)
                       ORDER BY dw_load_date DESC
                   ) AS rn
            FROM bronze.survey_engagement
            WHERE response_id IS NOT NULL AND TRIM(response_id) <> ''
        )
        INSERT INTO silver.survey_engagement (
            response_id, employee_id, department, survey_quarter, category, score
        )
        SELECT
            TRIM(response_id),
            TRIM(employee_id),
            NULLIF(TRIM(department), ''),
            TRIM(survey_quarter),
            TRIM(category),
            CASE
                WHEN TRIM(category) = 'eNPS (0-10)'
                     AND TRY_CONVERT(INT, score) BETWEEN 0 AND 10
                THEN TRY_CONVERT(INT, score)
                WHEN TRIM(category) <> 'eNPS (0-10)'
                     AND TRY_CONVERT(INT, score) BETWEEN 1 AND 5
                THEN TRY_CONVERT(INT, score)
                ELSE NULL
            END
        FROM deduped
        WHERE rn = 1
          AND employee_id IS NOT NULL AND TRIM(employee_id) <> '';

        SET @rows_loaded = @@ROWCOUNT;

        SELECT @rows_flagged = COUNT(*)
        FROM silver.survey_engagement
        WHERE score IS NULL;

        PRINT '   Rows loaded: ' + CAST(@rows_loaded AS NVARCHAR(20))
              + '  |  Duration: ' + CAST(DATEDIFF(SECOND, @step_start, SYSDATETIME()) AS NVARCHAR(10)) + 's';
        PRINT '   Rows flagged with out-of-range score (set to NULL): ' + CAST(@rows_flagged AS NVARCHAR(20));

        PRINT '==============================================================';
        PRINT 'Silver Layer Load Complete — Total Duration: '
              + CAST(DATEDIFF(SECOND, @batch_start, SYSDATETIME()) AS NVARCHAR(10)) + 's';
        PRINT '==============================================================';

    END TRY
    BEGIN CATCH
        PRINT '==============================================================';
        PRINT 'ERROR LOADING SILVER LAYER';
        PRINT 'Error Message : ' + ERROR_MESSAGE();
        PRINT 'Error Number  : ' + CAST(ERROR_NUMBER() AS NVARCHAR(20));
        PRINT 'Error Line    : ' + CAST(ERROR_LINE() AS NVARCHAR(20));
        PRINT '==============================================================';
        THROW;
    END CATCH
END
GO

PRINT 'Procedure silver.load_silver created successfully. Execute with: EXEC silver.load_silver;';
GO
