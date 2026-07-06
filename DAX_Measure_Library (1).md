# DAX Measure Library
**Enterprise People Analytics Platform — Power BI**
Companion to: KPI_Catalogue.md | Source: gold layer views/tables

---

## Model setup (before writing measures)

**Connection:** Import mode against `PeopleAnalyticsDW`, loading the three fact tables and six dimensions from the `gold` schema (not the views — views are for ad-hoc SQL consumers; Power BI gets the star schema directly so relationships and slicers work naturally).

**Relationships** (all single-direction, dimension → fact, 1:many):

| From | To |
|---|---|
| DimDate[DateSK] | FactEmployeeSnapshot[DateSK] |
| DimDate[DateSK] | FactRecruitment[AppliedDateSK] |
| DimDate[DateSK] | FactSurvey[SurveyDateSK] |
| DimEmployee[EmployeeSK] | FactEmployeeSnapshot[EmployeeSK] |
| DimEmployee[EmployeeSK] | FactSurvey[EmployeeSK] |
| DimDepartment[DepartmentSK] | all three facts |
| DimLocation[LocationSK] | FactEmployeeSnapshot[LocationSK] |
| DimJobLevel[JobLevelSK] | FactEmployeeSnapshot[JobLevelSK] |
| DimRecruitmentSource[SourceSK] | FactRecruitment[SourceSK] |

Mark `DimDate` as the model's date table (Table tools → Mark as date table → FullDate).

Create a dedicated **_Measures** table (Home → Enter data, single dummy column, hide it) so all measures live in one place.

---

## 1. Workforce measures

```dax
Headcount =
SUM ( FactEmployeeSnapshot[HeadcountFlag] )
```
Grain note: because the snapshot fact has one row per employee per month-end, this only gives sensible numbers when the visual is filtered to a single date/month. For "current" cards, use the latest-snapshot pattern:

```dax
Current Headcount =
VAR LatestSnapshot =
    CALCULATE ( MAX ( DimDate[FullDate] ), FactEmployeeSnapshot )
RETURN
    CALCULATE (
        SUM ( FactEmployeeSnapshot[HeadcountFlag] ),
        DimDate[FullDate] = LatestSnapshot
    )
```

```dax
New Hires =
SUM ( FactEmployeeSnapshot[NewHireFlag] )
```

```dax
Terminations =
SUM ( FactEmployeeSnapshot[TerminationFlag] )
```

```dax
Voluntary Terminations =
SUM ( FactEmployeeSnapshot[VoluntaryTerminationFlag] )
```

```dax
Average Tenure (Years) =
VAR LatestSnapshot =
    CALCULATE ( MAX ( DimDate[FullDate] ), FactEmployeeSnapshot )
RETURN
    DIVIDE (
        CALCULATE (
            AVERAGE ( FactEmployeeSnapshot[TenureDays] ),
            DimDate[FullDate] = LatestSnapshot,
            FactEmployeeSnapshot[HeadcountFlag] = 1
        ),
        365.25
    )
```

```dax
Headcount Growth % =
VAR CurrentHC = [Current Headcount]
VAR PriorHC =
    CALCULATE (
        [Current Headcount],
        DATEADD ( DimDate[FullDate], -12, MONTH )
    )
RETURN
    DIVIDE ( CurrentHC - PriorHC, PriorHC )
```

## 2. Attrition measures

```dax
Avg Monthly Headcount =
AVERAGEX (
    VALUES ( DimDate[DateSK] ),
    CALCULATE ( SUM ( FactEmployeeSnapshot[HeadcountFlag] ) )
)
```

```dax
Voluntary Attrition % =
DIVIDE (
    [Voluntary Terminations],
    [Avg Monthly Headcount]
)
```
Definition note (matches KPI_Catalogue.md): terminations in period ÷ average monthly headcount in period. Format as percentage. Works at any time grain because both numerator and denominator respect the date filter.

```dax
Attrition % PY =
CALCULATE (
    [Voluntary Attrition %],
    SAMEPERIODLASTYEAR ( DimDate[FullDate] )
)
```

```dax
Attrition vs PY (pp) =
( [Voluntary Attrition %] - [Attrition % PY] ) * 100
```

## 3. Recruitment measures

```dax
Applicants =
COUNTROWS ( FactRecruitment )
```

```dax
Hires =
SUM ( FactRecruitment[HiredFlag] )
```

```dax
Reached Phone Screen = SUM ( FactRecruitment[ReachedPhoneScreenFlag] )
Reached Onsite       = SUM ( FactRecruitment[ReachedOnsiteFlag] )
Reached Offer        = SUM ( FactRecruitment[ReachedOfferFlag] )
```

```dax
Applicant → Phone % = DIVIDE ( [Reached Phone Screen], [Applicants] )
Phone → Onsite %    = DIVIDE ( [Reached Onsite], [Reached Phone Screen] )
Onsite → Offer %    = DIVIDE ( [Reached Offer], [Reached Onsite] )
Offer → Hire %      = DIVIDE ( [Hires], [Reached Offer] )
```

```dax
Offer Acceptance % =
DIVIDE ( [Hires], [Reached Offer] )
```
(Same as Offer → Hire % — kept as a named alias because the KPI Catalogue lists it separately and execs ask for it by this name.)

```dax
Avg Time to Fill (Days) =
AVERAGEX (
    FILTER ( FactRecruitment, FactRecruitment[HiredFlag] = 1 ),
    FactRecruitment[TimeToFillDays]
)
```

```dax
Source Hire Rate % =
DIVIDE ( [Hires], [Applicants] )
```
(Slice by DimRecruitmentSource[SourceName] for source effectiveness.)

## 4. Engagement measures

```dax
Avg Engagement Score =
CALCULATE (
    AVERAGE ( FactSurvey[Score] ),
    FactSurvey[Category] <> "eNPS (0-10)"
)
```

```dax
Manager Effectiveness Score =
CALCULATE (
    AVERAGE ( FactSurvey[Score] ),
    FactSurvey[Category] = "Manager Effectiveness"
)
```

```dax
eNPS =
VAR eNPSResponses =
    CALCULATETABLE ( FactSurvey, FactSurvey[Category] = "eNPS (0-10)" )
VAR Total = COUNTROWS ( eNPSResponses )
VAR Promoters =
    COUNTROWS ( FILTER ( eNPSResponses, FactSurvey[Score] >= 9 ) )
VAR Detractors =
    COUNTROWS ( FILTER ( eNPSResponses, FactSurvey[Score] <= 6 ) )
RETURN
    DIVIDE ( Promoters - Detractors, Total ) * 100
```
CRITICAL: eNPS is %Promoters − %Detractors on the 0–10 question, expressed as a number from −100 to +100. It is NOT the average of the scores — averaging is the classic eNPS mistake and an interviewer trap.

```dax
Survey Response Rate % =
VAR Respondents =
    CALCULATE ( DISTINCTCOUNT ( FactSurvey[EmployeeSK] ) )
VAR ActiveEmployees = [Avg Monthly Headcount]
RETURN
    DIVIDE ( Respondents, ActiveEmployees )
```
Caveat: denominator is approximate (avg headcount over the filtered period vs. eligible population at survey time). Fine for a trend indicator; documented in KPI_Catalogue.md.

## 5. Leading-indicator measures (engagement vs. future attrition)

```dax
Engagement 2Q Ago =
CALCULATE (
    [Avg Engagement Score],
    DATEADD ( DimDate[FullDate], -6, MONTH )
)
```
Plotting [Voluntary Attrition %] against [Engagement 2Q Ago] on the same quarterly axis overlays each quarter's attrition with the engagement score from two quarters earlier — the visual version of the lagged analysis (correlation strengthens from −0.31 at lag 0 to −0.63 at lag 2 in this dataset).

```dax
Engagement Alert Flag =
IF ( [Avg Engagement Score] < 3.0, "⚠ At Risk", "Healthy" )
```
Threshold rationale: in this dataset, Customer Support crossed below 3.0 in 2024-Q3 — two quarters before the exit peak. A 3.0 alert would have fired in time to intervene. This is the "early warning" the CPO asked for in the BRD.

---

## Formatting standards

| Measure type | Format |
|---|---|
| Counts (Headcount, Hires, Applicants) | Whole number, thousands separator |
| Percentages | Percentage, 1 decimal |
| eNPS | Whole number (−100 to +100), no % sign |
| Scores | Decimal, 2 places |
| Days | Whole number |

All measures use DIVIDE() rather than the / operator — silent BLANK() on divide-by-zero instead of an error.
