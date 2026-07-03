# KPI Catalogue

## Purpose

This document defines the Key Performance Indicators (KPIs) used throughout the Enterprise People Analytics Platform.

Each KPI includes its business purpose, calculation logic, and reporting frequency to ensure consistency across dashboards, reports, and ad-hoc analyses.

---

# Workforce KPIs

## Total Headcount

**Description**

Total number of active employees in the organization.

**Formula**

Count of employees where Employment Status = Active

**Business Owner**

People Operations

**Reporting Frequency**

Daily

---

## New Hires

**Description**

Total employees hired during the selected reporting period.

**Formula**

Count of Hire Date within selected period

---

## Employee Exits

**Description**

Total employees who left the organization during the reporting period.

**Formula**

Count of Termination Date within selected period

---

## Average Tenure

**Description**

Average length of employment for active employees.

**Formula**

Average(Current Date - Hire Date)

---

# Attrition KPIs

## Overall Attrition Rate

**Description**

Percentage of employees who left the organization during the reporting period.

**Formula**

(Employee Exits ÷ Average Headcount) × 100

---

## Voluntary Attrition Rate

**Description**

Percentage of employees who resigned voluntarily.

**Formula**

(Voluntary Exits ÷ Average Headcount) × 100

---

## Involuntary Attrition Rate

**Description**

Percentage of employees terminated by the organization.

**Formula**

(Involuntary Exits ÷ Average Headcount) × 100

---

## Attrition by Department

**Description**

Attrition rate calculated separately for each department.

**Formula**

Department Exits ÷ Department Average Headcount

---

## Attrition by Manager

**Description**

Employee turnover grouped by reporting manager.

---

# Recruitment KPIs

## Open Requisitions

**Description**

Number of positions currently open.

---

## Total Applicants

**Description**

Total candidates who applied.

---

## Candidates Interviewed

**Description**

Candidates reaching the interview stage.

---

## Offers Extended

**Description**

Total offers sent to candidates.

---

## Hires

**Description**

Candidates successfully hired.

---

## Offer Acceptance Rate

**Formula**

Accepted Offers ÷ Total Offers × 100

---

## Hiring Conversion Rate

**Formula**

Hired Candidates ÷ Total Applicants × 100

---

## Time to Fill

**Description**

Number of days required to fill a job requisition.

**Formula**

Offer Accepted Date − Requisition Open Date

---

## Time to Hire

**Description**

Number of days between candidate application and accepted offer.

**Formula**

Offer Accepted Date − Application Date

---

## Source Effectiveness

**Description**

Measures hiring success by recruitment source.

Examples:

- LinkedIn
- Employee Referral
- Careers Website
- Agency
- Internal Mobility

---

# Employee Engagement KPIs

## Average Engagement Score

**Description**

Average employee engagement score from survey responses.

---

## Manager Effectiveness Score

**Description**

Average manager effectiveness rating provided by employees.

---

## Employee Net Promoter Score (eNPS)

**Description**

Measures employee willingness to recommend the organization as a workplace.

---

## Survey Response Rate

**Formula**

Survey Responses ÷ Eligible Employees × 100

---

# Workforce Planning KPIs

## Department Headcount

Active employees by department.

---

## Location Headcount

Active employees by office location.

---

## Job Level Distribution

Employees grouped by job level.

---

## Manager Span of Control

**Description**

Average number of direct reports per manager.

---

## Organizational Growth Rate

**Formula**

(Current Headcount − Previous Headcount) ÷ Previous Headcount × 100

---

# Executive KPIs

These KPIs appear on the Executive Dashboard.

- Total Headcount
- New Hires
- Employee Exits
- Overall Attrition Rate
- Voluntary Attrition Rate
- Average Engagement Score
- eNPS
- Time to Fill
- Hiring Conversion Rate
- Open Requisitions

---

# KPI Dimensions

The following dimensions should be available for filtering across dashboards:

- Department
- Manager
- Location
- Job Level
- Employment Status
- Gender
- Recruitment Source
- Recruiter
- Requisition
- Survey Period
- Year
- Quarter
- Month

---

# KPI Refresh Schedule

| KPI Category | Refresh Frequency |
|--------------|-------------------|
| Workforce | Daily |
| Recruitment | Daily |
| Employee Engagement | Quarterly (or when survey data is available) |
| Executive Dashboard | Daily |

---

# KPI Validation Rules

- All KPIs must use Gold Layer tables only.
- Every KPI must have a single approved business definition.
- KPI calculations must remain consistent across dashboards and reports.
- Historical KPI values should be reproducible using archived data.
