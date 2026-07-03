
# Business Requirements

## Project Overview

The Enterprise People Analytics Platform is designed to centralize workforce data from multiple operational systems into a single analytics-ready data warehouse. The platform enables HR leaders, Talent Acquisition teams, and executives to make data-driven decisions by providing reliable reporting, interactive dashboards, and self-service analytics.

The solution integrates employee, recruitment, and engagement data using a Medallion Architecture (Bronze, Silver, Gold) and delivers trusted datasets for business intelligence tools such as Power BI and ThoughtSpot.

---

# Business Problem

People-related data is distributed across multiple operational systems, making it difficult to answer strategic workforce questions quickly and consistently.

Current challenges include:

- Employee data stored separately from recruitment data
- Manual reporting processes
- Inconsistent workforce metrics
- Limited visibility into employee retention trends
- Difficulty correlating engagement with attrition
- No centralized analytics platform

---

# Project Objectives

The project aims to:

- Build a centralized People Analytics Data Warehouse
- Consolidate HRIS, ATS, and Employee Survey data
- Improve data quality through standardized ETL pipelines
- Deliver analytics-ready datasets using dimensional modeling
- Enable executive reporting through interactive dashboards
- Support future AI-powered analytics capabilities

---

# Business Stakeholders

| Stakeholder | Business Need |
|-------------|---------------|
| Chief People Officer (CPO) | Executive workforce reporting |
| HR Business Partners | Workforce planning and organizational insights |
| Talent Acquisition | Recruitment pipeline analytics |
| Customer Support Leadership | Employee retention analysis |
| People Operations | Operational reporting and KPI monitoring |

---

# Source Systems

| System | Description |
|---------|-------------|
| HRIS | Employee master records |
| ATS | Recruitment and hiring data |
| Employee Survey | Engagement and employee feedback |

---

# Key Business Questions

## Workforce

- What is the current headcount?
- How has headcount changed over time?
- Which departments are growing?

## Retention

- What is the voluntary attrition rate?
- Which departments experience the highest turnover?
- Which managers have elevated attrition?
- Does declining engagement precede employee exits?

## Recruitment

- What is the average time-to-fill?
- Which recruitment sources produce the highest-quality hires?
- Where are candidates dropping out of the hiring funnel?
- Which departments experience hiring delays?

## Employee Engagement

- What are current engagement scores?
- Which departments show declining engagement?
- How effective are managers based on survey feedback?
- What is the overall employee Net Promoter Score (eNPS)?

---

# Success Criteria

The solution will be considered successful when it:

- Produces a centralized analytics-ready data warehouse
- Eliminates manual reporting across HR datasets
- Delivers trusted executive KPIs
- Supports self-service business intelligence
- Enables scalable reporting for future workforce analytics

---

# Expected Deliverables

- SQL Server Data Warehouse
- Medallion Architecture (Bronze, Silver, Gold)
- Star Schema Data Model
- SQL Views
- Executive Power BI Dashboards
- Data Dictionary
- Technical Documentation
- Business Documentation

---

# Project Scope

## In Scope

- HR Analytics
- Recruitment Analytics
- Employee Engagement Analytics
- Workforce Planning
- Data Warehouse Development
- ETL Pipeline
- Data Modeling
- Executive Dashboards

## Out of Scope

- Payroll Analytics
- Benefits Analytics
- Machine Learning Models
- Real-time Data Streaming
