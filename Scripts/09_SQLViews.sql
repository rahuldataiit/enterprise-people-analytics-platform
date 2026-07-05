/*
==============================================================================
Script:      09_SQLViews.sql
Purpose:     Creates the Gold-layer reporting views consumed by Power BI.
             Each view maps to a business question from
             Business_Requirements.md / Project Charter success criteria.
Layer:       Gold (views)
Source:      gold.Dim* and gold.Fact* tables
Target:      gold.vw_* views
Run order:   9th — after 08_LoadGold.sql (and EXEC gold.load_gold).
==============================================================================
View catalogue:
  vw_HeadcountTrend          → "What is current headcount / how has it changed"
  vw_AttritionByDepartment   → "Which departments have highest turnover"
  vw_AttritionByManager      → "Which managers have elevated attrition"
  vw_RecruitmentFunnel       → "Where do candidates exit the hiring funnel"
  vw_TimeToFill              → "Average time-to-fill / departments with delays"
  vw_SourceEffectiveness     → "Which sources generate the highest-quality hires"
  vw_EngagementTrend         → "Engagement / manager effectiveness / eNPS trends"
  vw_EngagementVsAttrition   → "Does declining engagement predict attrition"
                               (the lagged join — headline analysis)
==============================================================================
*/

USE PeopleAnalyticsDW;
GO

-- -----------------------------------------------------------------------
-- vw_HeadcountTrend
-- Monthly headcount, hires, and exits by department/location/level.
-- Power BI page: Executive Overview, Workforce Overview.
-- -----------------------------------------------------------------------
CREATE OR ALTER VIEW gold.vw_HeadcountTrend AS
SELECT
    d.FullDate            AS SnapshotDate,
    d.[Year],
    d.QuarterName,
    d.MonthName,
    dep.DepartmentName,
    loc.LocationName,
    jl.LevelName,
    SUM(f.HeadcountFlag)       AS Headcount,
    SUM(f.NewHireFlag)         AS NewHires,
    SUM(f.TerminationFlag)     AS Terminations,
    SUM(f.VoluntaryTerminationFlag) AS VoluntaryTerminations
FROM gold.FactEmployeeSnapshot f
JOIN gold.DimDate d        ON d.DateSK = f.DateSK
JOIN gold.DimDepartment dep ON dep.DepartmentSK = f.DepartmentSK
JOIN gold.DimLocation loc  ON loc.LocationSK = f.LocationSK
JOIN gold.DimJobLevel jl   ON jl.JobLevelSK = f.JobLevelSK
GROUP BY d.FullDate, d.[Year], d.QuarterName, d.MonthName,
         dep.DepartmentName, loc.LocationName, jl.LevelName;
GO

-- -----------------------------------------------------------------------
-- vw_AttritionByDepartment
-- Quarterly voluntary attrition rate per department:
-- terminations in quarter / average monthly headcount in quarter.
-- Power BI page: Employee Attrition.
-- -----------------------------------------------------------------------
CREATE OR ALTER VIEW gold.vw_AttritionByDepartment AS
WITH quarterly AS (
    SELECT
        d.[Year],
        d.QuarterName,
        dep.DepartmentName,
        SUM(f.TerminationFlag)          AS Terminations,
        SUM(f.VoluntaryTerminationFlag) AS VoluntaryTerminations,
        -- 3 month-end snapshots per quarter → avg monthly headcount
        SUM(f.HeadcountFlag) * 1.0 / NULLIF(COUNT(DISTINCT d.DateSK), 0) AS AvgMonthlyHeadcount
    FROM gold.FactEmployeeSnapshot f
    JOIN gold.DimDate d         ON d.DateSK = f.DateSK
    JOIN gold.DimDepartment dep ON dep.DepartmentSK = f.DepartmentSK
    GROUP BY d.[Year], d.QuarterName, dep.DepartmentName
)
SELECT
    [Year],
    QuarterName,
    DepartmentName,
    Terminations,
    VoluntaryTerminations,
    CAST(AvgMonthlyHeadcount AS DECIMAL(10,1)) AS AvgMonthlyHeadcount,
    CAST(VoluntaryTerminations * 100.0 / NULLIF(AvgMonthlyHeadcount, 0) AS DECIMAL(5,1))
        AS QuarterlyVoluntaryAttritionPct
FROM quarterly;
GO

-- -----------------------------------------------------------------------
-- vw_AttritionByManager
-- Voluntary exits under each manager vs team size. Small teams flagged:
-- privacy rule — rates on teams under 5 are suppressed downstream
-- (people-data privacy consideration; see Business_Rules.md).
-- Power BI page: Manager Analytics.
-- -----------------------------------------------------------------------
CREATE OR ALTER VIEW gold.vw_AttritionByManager AS
SELECT
    e.ManagerID,
    dep.DepartmentName,
    COUNT(DISTINCT e.EmployeeID)                                   AS TeamSizeEver,
    SUM(CASE WHEN e.TerminationDate IS NOT NULL THEN 1 ELSE 0 END) AS TotalExits,
    SUM(CASE WHEN e.TerminationReason LIKE 'Voluntary%' THEN 1 ELSE 0 END) AS VoluntaryExits,
    CASE WHEN COUNT(DISTINCT e.EmployeeID) >= 5
         THEN CAST(SUM(CASE WHEN e.TerminationReason LIKE 'Voluntary%' THEN 1 ELSE 0 END) * 100.0
                   / COUNT(DISTINCT e.EmployeeID) AS DECIMAL(5,1))
         ELSE NULL   -- suppressed: team too small to report a rate responsibly
    END AS VoluntaryExitRatePct,
    CASE WHEN COUNT(DISTINCT e.EmployeeID) < 5 THEN 1 ELSE 0 END AS SmallTeamSuppressedFlag
FROM gold.DimEmployee e
JOIN gold.FactEmployeeSnapshot f ON f.EmployeeSK = e.EmployeeSK
JOIN gold.DimDepartment dep      ON dep.DepartmentSK = f.DepartmentSK
WHERE e.ManagerID IS NOT NULL
GROUP BY e.ManagerID, dep.DepartmentName;
GO

-- -----------------------------------------------------------------------
-- vw_RecruitmentFunnel
-- Stage-to-stage conversion by department and quarter.
-- Power BI page: Recruitment Analytics.
-- -----------------------------------------------------------------------
CREATE OR ALTER VIEW gold.vw_RecruitmentFunnel AS
SELECT
    d.[Year],
    d.QuarterName,
    dep.DepartmentName,
    COUNT(*)                        AS Applicants,
    SUM(f.ReachedPhoneScreenFlag)   AS ReachedPhoneScreen,
    SUM(f.ReachedOnsiteFlag)        AS ReachedOnsite,
    SUM(f.ReachedOfferFlag)         AS ReachedOffer,
    SUM(f.HiredFlag)                AS Hired,
    CAST(SUM(f.ReachedPhoneScreenFlag) * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(5,1))                          AS PctApplicantToPhone,
    CAST(SUM(f.ReachedOnsiteFlag) * 100.0 / NULLIF(SUM(f.ReachedPhoneScreenFlag), 0) AS DECIMAL(5,1))          AS PctPhoneToOnsite,
    CAST(SUM(f.ReachedOfferFlag) * 100.0 / NULLIF(SUM(f.ReachedOnsiteFlag), 0) AS DECIMAL(5,1))                AS PctOnsiteToOffer,
    CAST(SUM(f.HiredFlag) * 100.0 / NULLIF(SUM(f.ReachedOfferFlag), 0) AS DECIMAL(5,1))                        AS PctOfferToHire
FROM gold.FactRecruitment f
JOIN gold.DimDate d         ON d.DateSK = f.AppliedDateSK
JOIN gold.DimDepartment dep ON dep.DepartmentSK = f.DepartmentSK
GROUP BY d.[Year], d.QuarterName, dep.DepartmentName;
GO

-- -----------------------------------------------------------------------
-- vw_TimeToFill
-- Requisition-level fill time by department. TimeToFillDays lives on
-- hired candidate rows, so we take it per hired candidate.
-- Power BI page: Recruitment Analytics.
-- -----------------------------------------------------------------------
CREATE OR ALTER VIEW gold.vw_TimeToFill AS
SELECT
    d.[Year],
    d.QuarterName,
    dep.DepartmentName,
    COUNT(*)                                   AS FilledPositions,
    AVG(f.TimeToFillDays * 1.0)                AS AvgTimeToFillDays,
    MIN(f.TimeToFillDays)                      AS MinTimeToFillDays,
    MAX(f.TimeToFillDays)                      AS MaxTimeToFillDays
FROM gold.FactRecruitment f
JOIN gold.DimDate d         ON d.DateSK = f.AppliedDateSK
JOIN gold.DimDepartment dep ON dep.DepartmentSK = f.DepartmentSK
WHERE f.HiredFlag = 1
  AND f.TimeToFillDays IS NOT NULL
GROUP BY d.[Year], d.QuarterName, dep.DepartmentName;
GO

-- -----------------------------------------------------------------------
-- vw_SourceEffectiveness
-- Volume vs conversion per sourcing channel: which channels produce
-- hires, not just applicants.
-- Power BI page: Recruitment Analytics.
-- -----------------------------------------------------------------------
CREATE OR ALTER VIEW gold.vw_SourceEffectiveness AS
SELECT
    src.SourceName,
    dep.DepartmentName,
    COUNT(*)          AS Applicants,
    SUM(f.HiredFlag)  AS Hires,
    CAST(SUM(f.HiredFlag) * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS ApplicantToHirePct
FROM gold.FactRecruitment f
JOIN gold.DimRecruitmentSource src ON src.SourceSK = f.SourceSK
JOIN gold.DimDepartment dep        ON dep.DepartmentSK = f.DepartmentSK
GROUP BY src.SourceName, dep.DepartmentName;
GO

-- -----------------------------------------------------------------------
-- vw_EngagementTrend
-- Quarterly average score per category per department, plus eNPS
-- computed properly: %Promoters(9-10) − %Detractors(0-6), not an average.
-- Power BI page: Employee Engagement.
-- -----------------------------------------------------------------------
CREATE OR ALTER VIEW gold.vw_EngagementTrend AS
SELECT
    f.SurveyQuarter,
    dep.DepartmentName,
    f.Category,
    COUNT(f.Score)                                    AS Responses,
    CAST(AVG(f.Score * 1.0) AS DECIMAL(4,2))          AS AvgScore,
    -- eNPS only meaningful for the eNPS category; NULL elsewhere
    CASE WHEN f.Category = 'eNPS (0-10)'
         THEN CAST(
              (SUM(CASE WHEN f.Score >= 9 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(f.Score), 0))
            - (SUM(CASE WHEN f.Score <= 6 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(f.Score), 0))
              AS DECIMAL(5,1))
         ELSE NULL
    END AS eNPS
FROM gold.FactSurvey f
JOIN gold.DimDepartment dep ON dep.DepartmentSK = f.DepartmentSK
WHERE f.Score IS NOT NULL
GROUP BY f.SurveyQuarter, dep.DepartmentName, f.Category;
GO

-- -----------------------------------------------------------------------
-- vw_EngagementVsAttrition  ← headline analysis
-- "Does declining engagement predict future attrition?"
-- Joins each department-quarter's engagement to the SAME department's
-- attrition 1 and 2 quarters LATER. If engagement is a leading indicator,
-- low engagement scores should line up with elevated attrition at
-- lag +1 / +2 — proving time-order, not just correlation.
-- Power BI page: Executive Overview / Employee Attrition.
-- -----------------------------------------------------------------------
CREATE OR ALTER VIEW gold.vw_EngagementVsAttrition AS
WITH eng AS (
    -- quarterly engagement per department (1-5 categories only)
    SELECT
        f.SurveyQuarter,
        dep.DepartmentName,
        CAST(AVG(f.Score * 1.0) AS DECIMAL(4,2)) AS AvgEngagement,
        CAST(AVG(CASE WHEN f.Category = 'Manager Effectiveness'
                      THEN f.Score * 1.0 END) AS DECIMAL(4,2)) AS AvgManagerEffectiveness
    FROM gold.FactSurvey f
    JOIN gold.DimDepartment dep ON dep.DepartmentSK = f.DepartmentSK
    WHERE f.Category <> 'eNPS (0-10)'
      AND f.Score IS NOT NULL
    GROUP BY f.SurveyQuarter, dep.DepartmentName
),
attr AS (
    -- quarterly voluntary attrition per department, with a sortable index
    SELECT
        d.QuarterName,
        dep.DepartmentName,
        d.[Year] * 4 + d.[Quarter]      AS QuarterIndex,
        SUM(f.VoluntaryTerminationFlag) AS VoluntaryTerminations,
        SUM(f.HeadcountFlag) * 1.0 / NULLIF(COUNT(DISTINCT d.DateSK), 0) AS AvgMonthlyHeadcount
    FROM gold.FactEmployeeSnapshot f
    JOIN gold.DimDate d         ON d.DateSK = f.DateSK
    JOIN gold.DimDepartment dep ON dep.DepartmentSK = f.DepartmentSK
    GROUP BY d.QuarterName, dep.DepartmentName, d.[Year], d.[Quarter]
),
eng_indexed AS (
    SELECT e.*,
           CAST(LEFT(e.SurveyQuarter, 4) AS INT) * 4
             + CAST(RIGHT(e.SurveyQuarter, 1) AS INT) AS QuarterIndex
    FROM eng e
)
SELECT
    e.SurveyQuarter,
    e.DepartmentName,
    e.AvgEngagement,
    e.AvgManagerEffectiveness,
    a0.VoluntaryTerminations AS Attrition_SameQuarter,
    a1.VoluntaryTerminations AS Attrition_NextQuarter,
    a2.VoluntaryTerminations AS Attrition_TwoQuartersLater,
    CAST(a0.VoluntaryTerminations * 100.0 / NULLIF(a0.AvgMonthlyHeadcount, 0) AS DECIMAL(5,1)) AS AttritionPct_SameQuarter,
    CAST(a1.VoluntaryTerminations * 100.0 / NULLIF(a1.AvgMonthlyHeadcount, 0) AS DECIMAL(5,1)) AS AttritionPct_NextQuarter,
    CAST(a2.VoluntaryTerminations * 100.0 / NULLIF(a2.AvgMonthlyHeadcount, 0) AS DECIMAL(5,1)) AS AttritionPct_TwoQuartersLater
FROM eng_indexed e
LEFT JOIN attr a0 ON a0.DepartmentName = e.DepartmentName AND a0.QuarterIndex = e.QuarterIndex
LEFT JOIN attr a1 ON a1.DepartmentName = e.DepartmentName AND a1.QuarterIndex = e.QuarterIndex + 1
LEFT JOIN attr a2 ON a2.DepartmentName = e.DepartmentName AND a2.QuarterIndex = e.QuarterIndex + 2;
GO

PRINT 'Gold reporting views created successfully.';
GO
