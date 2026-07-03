# Project Charter

## Project Information

| Item | Details |
|------|---------|
| Project Name | Enterprise People Analytics Platform |
| Project Type | End-to-End Data Warehouse & Business Intelligence Solution |
| Domain | Human Resources / People Analytics |
| Architecture | Medallion Architecture (Bronze, Silver, Gold) |
| Technology Stack | SQL Server, SSMS, Power BI, GitHub |
| Status | In Progress |

---

# Project Vision

To design and develop an enterprise-grade People Analytics Platform that transforms raw HR, recruitment, and employee engagement data into trusted business intelligence, enabling data-driven workforce decisions through scalable data engineering, dimensional modeling, and executive dashboards.

---

# Business Background

Organizations often store workforce data across multiple operational systems, making it difficult to generate consistent and timely business insights.

Employee information is managed in Human Resource Information Systems (HRIS), recruitment activities are tracked within Applicant Tracking Systems (ATS), and employee feedback is collected through survey platforms. These disconnected systems result in fragmented reporting, inconsistent business metrics, and significant manual effort to produce executive reports.

This project addresses these challenges by integrating data from multiple sources into a centralized data warehouse using industry-standard ETL practices and dimensional modeling.

---

# Problem Statement

The People Operations team currently faces several reporting challenges:

- Workforce data is distributed across multiple systems.
- Reporting requires significant manual effort.
- Business metrics are calculated inconsistently.
- Employee engagement cannot easily be correlated with attrition.
- Recruitment analytics lack end-to-end visibility.
- Executives do not have access to centralized, self-service reporting.

---

# Project Objectives

The project aims to:

- Build a centralized People Analytics Data Warehouse.
- Integrate HRIS, ATS, and Survey datasets.
- Implement Medallion Architecture (Bronze, Silver, Gold).
- Apply data cleansing and standardization through ETL pipelines.
- Design an analytics-ready Star Schema.
- Develop reusable SQL views for business reporting.
- Deliver executive dashboards using Power BI.
- Create comprehensive project documentation following enterprise best practices.

---

# Project Scope

## Included

- HR Analytics
- Recruitment Analytics
- Employee Engagement Analytics
- Workforce Planning
- SQL Data Warehouse
- ETL Pipeline Development
- Star Schema Design
- Executive Dashboards
- Business Documentation
- Technical Documentation

---

## Excluded

- Payroll Analytics
- Compensation Analytics
- Benefits Administration
- Machine Learning Models
- Real-time Streaming
- Cloud Deployment

---

# Business Stakeholders

| Stakeholder | Responsibility |
|-------------|---------------|
| Chief People Officer (CPO) | Executive workforce reporting |
| HR Business Partners | Workforce planning |
| Talent Acquisition | Recruitment analytics |
| Customer Support Leadership | Retention analysis |
| People Operations | Operational reporting |
| Business Intelligence Team | Dashboard development |

---

# Source Systems

| System | Description |
|--------|-------------|
| HRIS | Employee master data |
| ATS | Recruitment lifecycle data |
| Employee Survey Platform | Engagement survey responses |

---

# Expected Deliverables

## Data Engineering

- SQL Server Database
- Bronze Layer
- Silver Layer
- Gold Layer
- ETL Pipeline
- Data Validation Scripts
- SQL Views

---

## Data Modeling

- Star Schema
- Fact Tables
- Dimension Tables
- Relationship Model

---

## Business Intelligence

- Executive Dashboard
- Workforce Dashboard
- Attrition Dashboard
- Recruitment Dashboard
- Employee Engagement Dashboard

---

## Documentation

- Business Requirements
- Solution Architecture
- Data Dictionary
- Business Rules
- KPI Catalogue
- ETL Design
- Testing & Validation
- README

---

# Success Criteria

The project will be considered successful when it:

- Integrates data from multiple source systems into a centralized warehouse.
- Produces clean, analytics-ready datasets.
- Delivers consistent KPI calculations across reports.
- Reduces manual reporting effort.
- Supports executive decision-making through interactive dashboards.
- Demonstrates enterprise data engineering and business intelligence best practices.

---

# Project Architecture

```
Source Systems
     │
     ▼
 Bronze Layer
(Raw Data Landing)
     │
     ▼
 Silver Layer
(Cleansed & Standardized Data)
     │
     ▼
 Gold Layer
(Analytics-Ready Data Model)
     │
     ▼
 SQL Views
     │
     ▼
 Power BI Dashboards
     │
     ▼
 Executive Insights
```

---

# Assumptions

- Source datasets accurately represent HR, recruitment, and survey information.
- Employee identifiers can be used to integrate data across systems.
- Source files are refreshed periodically.
- Business definitions are standardized before reporting begins.

---

# Risks

- Incomplete or inconsistent source data.
- Missing values affecting KPI calculations.
- Duplicate employee or candidate records.
- Changes to business definitions during development.
- Data quality issues across multiple source systems.

---

# Future Enhancements

- ThoughtSpot Integration
- Azure Data Factory ETL
- dbt Transformations
- Microsoft Fabric
- Predictive Attrition Modeling
- AI-powered Workforce Insights
- Natural Language Querying
- Cloud Data Warehouse Deployment

---

# Project Repository Structure

```
Enterprise-People-Analytics-Platform/
│
├── Documentation
├── Source Data
├── SQL Scripts
├── Power BI
├── Architecture
├── Screenshots
└── README.md
```

---

# Project Timeline

| Phase | Status |
|--------|--------|
| Business Understanding | ✅ Completed |
| Solution Design | ⏳ In Progress |
| Data Warehouse Development | ⏳ Planned |
| ETL Development | ⏳ Planned |
| Gold Layer Modeling | ⏳ Planned |
| Dashboard Development | ⏳ Planned |
| Documentation | ⏳ Ongoing |
