# Data Dictionary

## Purpose

The Data Dictionary defines the structure, meaning, and business usage of all analytical datasets within the Enterprise People Analytics Platform.

It serves as the single source of truth for developers, analysts, and business stakeholders by documenting every table, column, data type, and business definition used throughout the data warehouse.

---

# Naming Conventions

| Standard | Description |
|----------|-------------|
| Dim | Dimension Table |
| Fact | Fact Table |
| PK | Primary Key |
| FK | Foreign Key |
| NK | Natural Key |
| SK | Surrogate Key |

---

# Gold Layer Tables

## DimEmployee

### Purpose

Stores employee master information used for workforce analytics.

| Column | Data Type | Description |
|---------|----------|-------------|
| EmployeeKey | INT | Surrogate key generated in the warehouse |
| EmployeeID | VARCHAR | Employee identifier from HRIS |
| FirstName | VARCHAR | Employee first name |
| LastName | VARCHAR | Employee last name |
| Gender | VARCHAR | Employee gender |
| Department | VARCHAR | Employee department |
| JobTitle | VARCHAR | Employee job title |
| JobLevel | VARCHAR | Employee job level |
| ManagerID | VARCHAR | Reporting manager |
| Location | VARCHAR | Office location |
| HireDate | DATE | Employee hire date |
| TerminationDate | DATE | Employee termination date |
| EmploymentStatus | VARCHAR | Active or Terminated |

---

## DimDepartment

### Purpose

Stores department information.

| Column | Data Type | Description |
|---------|----------|-------------|
| DepartmentKey | INT | Surrogate key |
| DepartmentName | VARCHAR | Department name |

---

## DimLocation

### Purpose

Stores office locations.

| Column | Data Type | Description |
|---------|----------|-------------|
| LocationKey | INT | Surrogate key |
| Location | VARCHAR | Office location |

---

## DimDate

### Purpose

Standard calendar dimension used across all fact tables.

| Column | Data Type | Description |
|---------|----------|-------------|
| DateKey | INT | YYYYMMDD format |
| Date | DATE | Calendar date |
| Day | INT | Day of month |
| Month | INT | Month number |
| MonthName | VARCHAR | Month name |
| Quarter | INT | Quarter |
| Year | INT | Calendar year |

---

## FactEmployee

### Purpose

Stores workforce events for employee reporting.

| Column | Data Type | Description |
|---------|----------|-------------|
| EmployeeKey | INT | Employee dimension key |
| DateKey | INT | Date dimension key |
| DepartmentKey | INT | Department dimension key |
| LocationKey | INT | Location dimension key |
| ActiveFlag | BIT | Employee active status |
| HireFlag | BIT | Indicates new hire |
| TerminationFlag | BIT | Indicates employee exit |
| VoluntaryAttritionFlag | BIT | Voluntary resignation |
| InvoluntaryAttritionFlag | BIT | Involuntary termination |

---

## FactRecruitment

### Purpose

Stores recruitment lifecycle metrics.

| Column | Data Type | Description |
|---------|----------|-------------|
| CandidateKey | INT | Candidate dimension key |
| RequisitionKey | INT | Job requisition |
| RecruiterKey | INT | Recruiter dimension |
| DateKey | INT | Date dimension |
| Source | VARCHAR | Recruitment source |
| CurrentStage | VARCHAR | Current hiring stage |
| DaysToHire | INT | Days required to hire |
| HireFlag | BIT | Candidate hired |

---

## FactSurvey

### Purpose

Stores employee engagement survey responses.

| Column | Data Type | Description |
|---------|----------|-------------|
| EmployeeKey | INT | Employee dimension |
| SurveyDateKey | INT | Survey date |
| EngagementScore | DECIMAL | Overall engagement score |
| ManagerEffectiveness | DECIMAL | Manager effectiveness rating |
| ENPS | INT | Employee Net Promoter Score |

---

# Business Definitions

| Metric | Definition |
|---------|------------|
| Headcount | Number of active employees |
| Voluntary Attrition | Employees leaving voluntarily |
| Involuntary Attrition | Employees terminated by the organization |
| Time to Fill | Days between requisition opening and accepted offer |
| Time to Hire | Days between candidate application and accepted offer |
| Engagement Score | Average employee engagement survey score |
| eNPS | Employee Net Promoter Score |
| Offer Acceptance Rate | Accepted Offers / Total Offers |
| Hiring Conversion Rate | Hired Candidates / Total Applicants |

---

# Source Systems

| Source | Description |
|--------|-------------|
| HRIS | Employee records |
| ATS | Recruitment records |
| Survey Platform | Employee engagement surveys |

---

# Data Refresh

| Layer | Refresh Frequency |
|--------|-------------------|
| Bronze | Daily |
| Silver | Daily |
| Gold | Daily |
| Power BI Dataset | Daily Scheduled Refresh |

---

# Data Ownership

| Dataset | Owner |
|---------|-------|
| HRIS | Human Resources |
| ATS | Talent Acquisition |
| Survey | People Operations |
| Data Warehouse | Data Engineering |
| Dashboards | Business Intelligence Team |
