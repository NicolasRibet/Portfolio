# Data Tab Auto Refresh

Portfolio tab: `Excel / Google Sheets`

## Overview

Built an automated Google Sheet for scalable segmentation progress tracking. The spreadsheet refreshed weekly and surfaced key metrics such as **% of total jobs**, **% of total apply starts**, and **weekly active job seekers**, giving senior stakeholders self-service access to current segmentation performance.

## What I built

- Automated a recurring Google Sheets reporting workflow instead of relying on manual refreshes.
- Combined **Sheets IQL**, **Python cronjobs on ORC**, **Kerberos authentication**, and the **Google Sheets API** to refresh and publish the data.
- Structured the output for fast comparison across country / segment combinations, certification status, job share, apply-start share, and weekly active job-seeker volume.
- Scheduled the workflow to refresh on a weekly cadence.

## Business impact

The automated sheet provided self-service segmentation data to:

- 1 Senior Manager
- 3 Directors
- 1 Senior Director
- 1 VP

I also documented the ORC cronjob implementation in a step-by-step internal guide and released reusable cronjob templates in a shared BI repository, lowering the barrier to automating similar recurring workflows.

## Tech stack

`Google Sheets` · `Sheets IQL` · `Python` · `Google Sheets API` · `Kerberos` · `ORC` · `GitLab`

## Screenshots

### Automated segmentation tracking sheet

![Automated segmentation tracking sheet — 1](screenshots/automated-segmentation-tracking-sheet-01.jpg)
![Automated segmentation tracking sheet — 2](screenshots/automated-segmentation-tracking-sheet-02.jpg)
![Automated segmentation tracking sheet — 3](screenshots/automated-segmentation-tracking-sheet-03.jpg)
![Automated segmentation tracking sheet — 4](screenshots/automated-segmentation-tracking-sheet-04.jpg)

### ORC Cronjob Guide

![ORC Cronjob Guide — 1](screenshots/orc-cronjob-guide-01.jpg)
![ORC Cronjob Guide — 2](screenshots/orc-cronjob-guide-02.jpg)
![ORC Cronjob Guide — 3](screenshots/orc-cronjob-guide-03.jpg)
![ORC Cronjob Guide — 4](screenshots/orc-cronjob-guide-04.jpg)

## Public portfolio note

The original ticket, spreadsheet, wiki, and GitLab repository lived on internal Indeed systems. This public portfolio version intentionally excludes proprietary source code, credentials, and private internal links.
