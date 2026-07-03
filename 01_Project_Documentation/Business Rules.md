# Business Rules

## Purpose

This document defines the business rules governing data transformation, validation, and reporting within the Enterprise People Analytics Platform. These rules ensure that workforce metrics are calculated consistently and that reporting remains accurate across all dashboards and analytical models.

---

# Employee Rules

### BR-001 Active Employee

An employee is considered **Active** when the employment status is "Active" and no termination date exists.

---

### BR-002 Terminated Employee

An employee is considered **Terminated** when a valid termination date exists.

---

### BR-003 Hire Date Validation

Hire Date cannot be NULL and cannot occur after the current date.

---

### BR-004 Termination Date Validation

Termination Date must be greater than or equal to Hire Date.

---

### BR-005 Department Assignment

Every employee must belong to one and only one department.

---

### BR-006 Manager Assignment

Every employee must have one reporting manager.

Executives without managers are allowed.

---

### BR-007 Employee Identifier

Employee ID must be unique across the organization.

Duplicate Employee IDs are rejected during ETL.

---

# Recruitment Rules

### BR-008 Requisition Identifier

Each requisition must have a unique Requisition ID.

---

### BR-009 Candidate Identifier

Each candidate must have a unique Candidate ID.

---

### BR-010 Hiring Stages

Candidates must progress through the recruitment pipeline in the following order:

Applied

↓

Phone Screen

↓

Interview

↓

Offer

↓

Hired

Skipped stages should be flagged during validation.

---

### BR-011 Time to Fill

Time to Fill is calculated as:

Offer Accepted Date − Requisition Open Date

---

### BR-012 Source Attribution

Every hired candidate must have a recruitment source assigned.

Examples:

- LinkedIn
- Referral
- Careers Website
- Recruiter
- Agency

---

# Employee Engagement Rules

### BR-013 Engagement Score

Engagement Score must be between 1 and 5.

Values outside this range are considered invalid.

---

### BR-014 eNPS Score

Employee Net Promoter Score must be between -100 and +100.

---

### BR-015 Survey Responses

Employees may submit only one survey response per survey period.

Duplicate responses are removed during ETL.

---

# Attrition Rules

### BR-016 Voluntary Attrition

Voluntary Attrition includes employees who resigned voluntarily.

---

### BR-017 Involuntary Attrition

Involuntary Attrition includes dismissals, layoffs, and performance-related exits.

---

### BR-018 Attrition Rate

Attrition Rate =

(Number of Employee Exits ÷ Average Headcount)

×100

---

# Headcount Rules

### BR-019 Current Headcount

Current Headcount includes only Active Employees.

---

### BR-020 Historical Headcount

Historical headcount is calculated using employee hire and termination dates.

---

# Data Quality Rules

### BR-021 Duplicate Records

Duplicate Employee IDs are removed.

Duplicate Candidate IDs are removed.

Duplicate Survey Responses are removed.

---

### BR-022 Missing Critical Values

The following fields cannot be NULL:

- Employee ID
- Department
- Hire Date
- Candidate ID
- Requisition ID

---

### BR-023 Department Standardization

Department names must follow a standardized naming convention.

Example:

Customer Support

NOT

Customer Support Team

Support

Customer Service

---

### BR-024 Location Standardization

Office locations must use standardized names.

Example:

Toronto

Vancouver

Montreal

Remote

---

### BR-025 Date Format

All dates will use the ISO 8601 standard.

YYYY-MM-DD

---

# ETL Rules

### BR-026 Bronze Layer

Raw data is loaded exactly as received.

No transformations are applied.

---

### BR-027 Silver Layer

Data is cleaned and standardized.

Typical transformations include:

- Remove duplicates
- Trim whitespace
- Correct data types
- Standardize values
- Handle NULL values

---

### BR-028 Gold Layer

Business-ready tables are created using a Star Schema.

Fact and Dimension tables are optimized for reporting and dashboard performance.

---

# Reporting Rules

### BR-029 Single Source of Truth

All reports must use Gold Layer tables.

Bronze and Silver tables are not used directly for reporting.

---

### BR-030 KPI Consistency

Every KPI displayed across reports must follow a single business definition.

For example:

Attrition Rate

Headcount

Time to Fill

Engagement Score

must always use the same calculation logic regardless of report or dashboard.
