# Dashboard Specification
**Enterprise People Analytics Platform — Power BI**
Companion to: DAX_Measure_Library.md | Audience mapping from Business_Requirements.md

---

## Design principles

1. **Two-tier structure** (from the BRD): an exec summary page the CPO checks monthly without help, and diagnostic pages the HRBP/TA teams drill into. Don't mix altitudes on one page.
2. **Answer-first layout**: every page leads with the KPI cards that answer its BRD question, trend and breakdown visuals below, detail tables last (or in drill-through only).
3. **Consistent slicer block** on every page: Year/Quarter, Department, Location. Synced across pages.
4. **Privacy rule**: any visual sliced by manager suppresses teams under 5 (`SmallTeamSuppressedFlag` from the view logic / equivalent DAX filter). No exceptions — this is a People Analytics credibility marker.
5. Color: one accent color for "current", muted gray for prior-period comparisons, red reserved exclusively for at-risk flags. Don't rainbow the bar charts.

---

## Page 1 — Executive Overview
**Audience:** CPO (standing BRD request: "one place I check monthly")

| Zone | Visuals |
|---|---|
| KPI row | Current Headcount · Voluntary Attrition % (QTD) · eNPS · Avg Time to Fill · Open Requisitions |
| Trend band | Headcount trend (line, monthly, 8 quarters) with New Hires / Terminations as columns on secondary axis |
| Health strip | Engagement Alert Flag by department (matrix with conditional formatting — the "one number plus segment view" the BRD pushed back for) |
| Callout | Attrition % by department (bar, sorted desc) — Customer Support will visibly lead |

Interaction: clicking any department cross-filters the whole page; right-click drill-through to Attrition Deep Dive.

## Page 2 — Workforce Overview
**Audience:** HRBPs, People Ops

- Headcount by Department (bar) and by Location (map or bar)
- Headcount by Job Level (column) — span-of-control / level distribution
- Headcount trend by department (small multiples line)
- New hires vs terminations by month (clustered column)
- Average tenure by department (bar)

## Page 3 — Employee Attrition (Deep Dive)
**Audience:** CS Leadership (urgent BRD question), HRBPs

- KPI row: Voluntary Attrition % · Voluntary Terminations · Attrition vs PY (pp)
- Quarterly voluntary attrition % by department (line, multi-series) — the "when did it start" answer
- Termination reason breakdown (bar) — "Manager Relationship" dominance in CS shows here
- Attrition by tenure band (histogram: <1yr, 1-2yr, 2-3yr, 3yr+)
- **The leading-indicator visual**: dual-axis line — Voluntary Attrition % and Engagement 2Q Ago, quarterly, filtered default to Customer Support. This is the money chart; title it as the finding, e.g. "Engagement decline preceded the exit wave by two quarters"
- Manager-level table (drill-through target): ManagerID, team size, voluntary exits, rate — suppressed under 5

## Page 4 — Recruitment Analytics
**Audience:** Talent Acquisition

- KPI row: Applicants · Hires · Avg Time to Fill · Offer Acceptance %
- Funnel visual: Applicants → Phone → Onsite → Offer → Hired
- Stage conversion % by department (matrix, conditional formatting) — Engineering's onsite drop-off shows here
- Avg time to fill by department (bar) vs. org average (constant line)
- Source effectiveness scatter: x = Applicants, y = Applicant→Hire %, size = Hires, legend = Source — separates volume channels from quality channels in one visual

## Page 5 — Employee Engagement
**Audience:** People leadership, HRBPs

- KPI row: Avg Engagement Score · eNPS · Manager Effectiveness · Survey Response Rate %
- Engagement trend by quarter (line) with department slicer
- Category breakdown (radar or bar): the five categories side by side, current vs prior quarter
- eNPS trend by quarter (line, −100 to +100 axis, zero line emphasized)
- Department × category heatmap (matrix, conditional formatting) — the "which departments are declining and in what dimension" answer

## Page 6 — Manager Analytics (drill-through)
**Audience:** HRBPs preparing manager conversations

- Reached only via drill-through from Pages 3/5 (not in main nav) — deliberate friction for the most sensitive cuts
- Team size, exits, voluntary exit rate (suppressed <5), team engagement vs department average, team eNPS
- Header text states the suppression rule explicitly so screenshots carry the caveat with them

---

## Build order

1. Model + relationships + DimDate marked (DAX_Measure_Library.md §setup)
2. All measures in _Measures table, verify formats
3. Page 1 first (forces the core measures to be right), then 3, 4, 5, 2, 6
4. Sync slicers, then drill-throughs, then conditional formatting, last
5. Performance check: Performance Analyzer on Page 1; every visual under 300ms at this data volume — if not, something's wrong with a measure

## Screenshot checklist for the repo

- Page 1 full view (the portfolio hero image)
- Page 3 leading-indicator chart, CS filter applied
- Page 4 funnel + source scatter
- 10_Validation.sql all-PASS result grid
