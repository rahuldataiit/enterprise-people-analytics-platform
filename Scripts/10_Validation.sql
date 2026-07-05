/*
==============================================================================
Script:      10_Validation.sql
Purpose:     Post-load validation suite: verifies row counts, key integrity,
             business-rule compliance, and KPI reconciliation across the
             Bronze → Silver → Gold pipeline.
Layer:       All (validation)
Source:      bronze.*, silver.*, gold.*
Target:      None (read-only checks; results returned as result sets)
Run order:   10th — after EXEC gold.load_gold.
==============================================================================
How to read the output: every check returns a row with CheckName, Status
('PASS'/'FAIL'/'WARN'), Expected, Actual, and Details. The suite is designed
so a full run with all PASS rows is the evidence that the warehouse can be
trusted — screenshot-worthy for the portfolio README.

Reference values (from source data profile at build time):
  - bronze.hris_employees:     1,400 rows
  - terminated employees:        402
  - bronze.ats_requisitions:     220 rows
  - bronze.ats_candidates:     5,556 rows
  - bronze.survey_engagement: 42,744 rows
==============================================================================
*/

USE PeopleAnalyticsDW;
GO

DECLARE @Results TABLE (
    CheckID    INT IDENTITY(1,1),
    CheckGroup NVARCHAR(50),
    CheckName  NVARCHAR(200),
    Status     NVARCHAR(10),
    Expected   NVARCHAR(100),
    Actual     NVARCHAR(100),
    Details    NVARCHAR(400)
);

-- =========================================================================
-- GROUP 1: Row-count reconciliation across layers
-- Silver may be <= Bronze (rows excluded by validation rules) but a large
-- gap means something is silently eating data.
-- =========================================================================
DECLARE @b INT, @s INT, @g INT;

SELECT @b = COUNT(*) FROM bronze.hris_employees;
SELECT @s = COUNT(*) FROM silver.hris_employees;
INSERT INTO @Results (CheckGroup, CheckName, Status, Expected, Actual, Details)
VALUES ('RowCounts', 'hris_employees: Bronze -> Silver',
        CASE WHEN @s = @b THEN 'PASS' WHEN @s >= @b * 0.98 THEN 'WARN' ELSE 'FAIL' END,
        CAST(@b AS NVARCHAR(20)), CAST(@s AS NVARCHAR(20)),
        'Silver may be slightly lower than Bronze due to validation exclusions; investigate if gap > 2%.');

SELECT @s = COUNT(*) FROM silver.hris_employees;
SELECT @g = COUNT(*) FROM gold.DimEmployee;
INSERT INTO @Results (CheckGroup, CheckName, Status, Expected, Actual, Details)
VALUES ('RowCounts', 'DimEmployee = silver.hris_employees',
        CASE WHEN @g = @s THEN 'PASS' ELSE 'FAIL' END,
        CAST(@s AS NVARCHAR(20)), CAST(@g AS NVARCHAR(20)),
        'Initial SCD2 load: exactly one current row per Silver employee.');

SELECT @b = COUNT(*) FROM bronze.ats_candidates;
SELECT @g = COUNT(*) FROM gold.FactRecruitment;
INSERT INTO @Results (CheckGroup, CheckName, Status, Expected, Actual, Details)
VALUES ('RowCounts', 'FactRecruitment vs bronze.ats_candidates',
        CASE WHEN @g = @b THEN 'PASS' WHEN @g >= @b * 0.98 THEN 'WARN' ELSE 'FAIL' END,
        CAST(@b AS NVARCHAR(20)), CAST(@g AS NVARCHAR(20)),
        'One fact row per candidate application.');

SELECT @b = COUNT(*) FROM bronze.survey_engagement;
SELECT @g = COUNT(*) FROM gold.FactSurvey;
INSERT INTO @Results (CheckGroup, CheckName, Status, Expected, Actual, Details)
VALUES ('RowCounts', 'FactSurvey vs bronze.survey_engagement',
        CASE WHEN @g = @b THEN 'PASS' WHEN @g >= @b * 0.98 THEN 'WARN' ELSE 'FAIL' END,
        CAST(@b AS NVARCHAR(20)), CAST(@g AS NVARCHAR(20)),
        'One fact row per survey response.');

-- =========================================================================
-- GROUP 2: Key integrity
-- =========================================================================
DECLARE @dupes INT;

SELECT @dupes = COUNT(*) FROM (
    SELECT employee_id FROM silver.hris_employees GROUP BY employee_id HAVING COUNT(*) > 1
) x;
INSERT INTO @Results (CheckGroup, CheckName, Status, Expected, Actual, Details)
VALUES ('KeyIntegrity', 'silver.hris_employees: employee_id unique',
        CASE WHEN @dupes = 0 THEN 'PASS' ELSE 'FAIL' END,
        '0', CAST(@dupes AS NVARCHAR(20)), 'Duplicate natural keys after dedup rule.');

SELECT @dupes = COUNT(*) FROM (
    SELECT EmployeeID FROM gold.DimEmployee WHERE IsCurrent = 1
    GROUP BY EmployeeID HAVING COUNT(*) > 1
) x;
INSERT INTO @Results (CheckGroup, CheckName, Status, Expected, Actual, Details)
VALUES ('KeyIntegrity', 'DimEmployee: one current row per EmployeeID',
        CASE WHEN @dupes = 0 THEN 'PASS' ELSE 'FAIL' END,
        '0', CAST(@dupes AS NVARCHAR(20)), 'SCD2 invariant: exactly one IsCurrent=1 row per natural key.');

-- Orphan check: FactSurvey employees that do not resolve to DimEmployee
DECLARE @orphans INT;
SELECT @orphans = COUNT(*)
FROM gold.FactSurvey f
LEFT JOIN gold.DimEmployee e ON e.EmployeeSK = f.EmployeeSK
WHERE e.EmployeeSK IS NULL;
INSERT INTO @Results (CheckGroup, CheckName, Status, Expected, Actual, Details)
VALUES ('KeyIntegrity', 'FactSurvey: no orphaned EmployeeSK',
        CASE WHEN @orphans = 0 THEN 'PASS' ELSE 'FAIL' END,
        '0', CAST(@orphans AS NVARCHAR(20)), 'FK constraints should make this impossible; belt-and-suspenders.');

-- =========================================================================
-- GROUP 3: Business-rule compliance
-- =========================================================================
DECLARE @violations INT;

SELECT @violations = COUNT(*)
FROM silver.hris_employees
WHERE termination_date IS NOT NULL AND termination_date < hire_date;
INSERT INTO @Results (CheckGroup, CheckName, Status, Expected, Actual, Details)
VALUES ('BusinessRules', 'No termination before hire (Silver)',
        CASE WHEN @violations = 0 THEN 'PASS' ELSE 'FAIL' END,
        '0', CAST(@violations AS NVARCHAR(20)), 'Termination Date Validation rule.');

SELECT @violations = COUNT(*)
FROM silver.hris_employees
WHERE (termination_date IS NOT NULL AND employment_status <> 'Terminated')
   OR (termination_date IS NULL AND employment_status <> 'Active');
INSERT INTO @Results (CheckGroup, CheckName, Status, Expected, Actual, Details)
VALUES ('BusinessRules', 'employment_status consistent with dates (Silver)',
        CASE WHEN @violations = 0 THEN 'PASS' ELSE 'FAIL' END,
        '0', CAST(@violations AS NVARCHAR(20)), 'Status is recomputed from dates in load_silver; must never contradict.');

SELECT @violations = COUNT(*)
FROM silver.survey_engagement
WHERE (category = 'eNPS (0-10)' AND score NOT BETWEEN 0 AND 10)
   OR (category <> 'eNPS (0-10)' AND score NOT BETWEEN 1 AND 5);
INSERT INTO @Results (CheckGroup, CheckName, Status, Expected, Actual, Details)
VALUES ('BusinessRules', 'Survey scores within valid ranges (Silver)',
        CASE WHEN @violations = 0 THEN 'PASS' ELSE 'FAIL' END,
        '0', CAST(@violations AS NVARCHAR(20)), 'Score range rule: 1-5 categories, 0-10 eNPS. NULLs excluded by NOT BETWEEN.');

SELECT @violations = COUNT(*)
FROM silver.ats_requisitions
WHERE closed_date IS NOT NULL AND closed_date < opened_date;
INSERT INTO @Results (CheckGroup, CheckName, Status, Expected, Actual, Details)
VALUES ('BusinessRules', 'No requisition closed before opened (Silver)',
        CASE WHEN @violations = 0 THEN 'PASS' ELSE 'FAIL' END,
        '0', CAST(@violations AS NVARCHAR(20)), 'Requisition date logic rule.');

-- =========================================================================
-- GROUP 4: KPI reconciliation — Gold must reproduce independently
-- computed numbers from Silver
-- =========================================================================
DECLARE @gold_terms INT, @silver_terms INT;

SELECT @gold_terms = SUM(TerminationFlag) FROM gold.FactEmployeeSnapshot;
SELECT @silver_terms = COUNT(*) FROM silver.hris_employees WHERE termination_date IS NOT NULL;
INSERT INTO @Results (CheckGroup, CheckName, Status, Expected, Actual, Details)
VALUES ('KPIReconciliation', 'Total terminations: Snapshot fact = Silver',
        CASE WHEN @gold_terms = @silver_terms THEN 'PASS' ELSE 'FAIL' END,
        CAST(@silver_terms AS NVARCHAR(20)), CAST(@gold_terms AS NVARCHAR(20)),
        'Every termination captured exactly once in the snapshot fact.');

DECLARE @gold_hires INT, @silver_hires INT;
SELECT @gold_hires = SUM(NewHireFlag) FROM gold.FactEmployeeSnapshot;
SELECT @silver_hires = COUNT(*) FROM silver.hris_employees;
INSERT INTO @Results (CheckGroup, CheckName, Status, Expected, Actual, Details)
VALUES ('KPIReconciliation', 'Total new hires: Snapshot fact = Silver',
        CASE WHEN @gold_hires = @silver_hires THEN 'PASS' ELSE 'FAIL' END,
        CAST(@silver_hires AS NVARCHAR(20)), CAST(@gold_hires AS NVARCHAR(20)),
        'Every employee has exactly one hire-month row flagged.');

-- Point-in-time headcount: Gold snapshot vs direct Silver calculation
DECLARE @check_date DATE = '2025-12-31';
DECLARE @gold_hc INT, @silver_hc INT;

SELECT @gold_hc = SUM(f.HeadcountFlag)
FROM gold.FactEmployeeSnapshot f
JOIN gold.DimDate d ON d.DateSK = f.DateSK
WHERE d.FullDate = @check_date;

SELECT @silver_hc = COUNT(*)
FROM silver.hris_employees
WHERE hire_date <= @check_date
  AND (termination_date IS NULL OR termination_date > @check_date);

INSERT INTO @Results (CheckGroup, CheckName, Status, Expected, Actual, Details)
VALUES ('KPIReconciliation', 'Headcount 2025-12-31: Snapshot = direct calc',
        CASE WHEN @gold_hc = @silver_hc THEN 'PASS' ELSE 'FAIL' END,
        CAST(@silver_hc AS NVARCHAR(20)), CAST(@gold_hc AS NVARCHAR(20)),
        'The core snapshot-grain guarantee: point-in-time headcount reproducible from the fact table.');

-- Hired candidates: FactRecruitment vs Silver
DECLARE @gold_hired INT, @silver_hired INT;
SELECT @gold_hired = SUM(HiredFlag) FROM gold.FactRecruitment;
SELECT @silver_hired = COUNT(*) FROM silver.ats_candidates WHERE furthest_stage = 'Hired';
INSERT INTO @Results (CheckGroup, CheckName, Status, Expected, Actual, Details)
VALUES ('KPIReconciliation', 'Hired count: FactRecruitment = Silver',
        CASE WHEN @gold_hired = @silver_hired THEN 'PASS' ELSE 'FAIL' END,
        CAST(@silver_hired AS NVARCHAR(20)), CAST(@gold_hired AS NVARCHAR(20)),
        'Funnel top-line reconciles.');

-- =========================================================================
-- GROUP 5: DimDate completeness
-- =========================================================================
DECLARE @date_gaps INT;
SELECT @date_gaps = DATEDIFF(DAY, '2022-01-01', '2026-12-31') + 1 - COUNT(*)
FROM gold.DimDate;
INSERT INTO @Results (CheckGroup, CheckName, Status, Expected, Actual, Details)
VALUES ('DimDate', 'Calendar complete 2022-01-01 to 2026-12-31',
        CASE WHEN @date_gaps = 0 THEN 'PASS' ELSE 'FAIL' END,
        '0 missing days', CAST(@date_gaps AS NVARCHAR(20)) + ' missing days',
        'Full calendar generated, no gaps.');

DECLARE @month_ends INT;
SELECT @month_ends = COUNT(*) FROM gold.DimDate WHERE IsMonthEnd = 1;
INSERT INTO @Results (CheckGroup, CheckName, Status, Expected, Actual, Details)
VALUES ('DimDate', 'Month-end flags: 60 months in range',
        CASE WHEN @month_ends = 60 THEN 'PASS' ELSE 'FAIL' END,
        '60', CAST(@month_ends AS NVARCHAR(20)), '5 years x 12 month-ends.');

-- =========================================================================
-- Final output: summary then detail
-- =========================================================================
SELECT
    Status,
    COUNT(*) AS Checks
FROM @Results
GROUP BY Status;

SELECT
    CheckID,
    CheckGroup,
    CheckName,
    Status,
    Expected,
    Actual,
    Details
FROM @Results
ORDER BY CASE Status WHEN 'FAIL' THEN 1 WHEN 'WARN' THEN 2 ELSE 3 END, CheckID;
GO
