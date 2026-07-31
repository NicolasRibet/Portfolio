# Governed Marketplace Metric Definitions

## Fact grain

One row per event date, job, device type, and traffic source.

## Certified metrics

| Metric | Definition | Formula |
|---|---|---|
| Active job count | Distinct jobs generating activity in the selected context | `COUNT(DISTINCT job_id)` |
| Total impressions | Job-result displays | `SUM(impressions)` |
| Total clicks | Clicks generated from job impressions | `SUM(clicks)` |
| Total applications | Completed application submissions | `SUM(applications)` |
| Total qualified applications | Applications satisfying the marketplace qualification rule | `SUM(qualified_applications)` |
| Total hires | Recorded hires attributed to marketplace applications | `SUM(hires)` |
| Total sponsored spend | Sponsored marketplace spend in USD | `SUM(sponsored_spend_usd)` |
| Click-through rate | Clicks divided by impressions | `SUM(clicks) / SUM(impressions)` |
| Apply rate | Applications divided by clicks | `SUM(applications) / SUM(clicks)` |
| Qualified-application rate | Qualified applications divided by applications | `SUM(qualified_applications) / SUM(applications)` |
| Hire rate | Hires divided by qualified applications | `SUM(hires) / SUM(qualified_applications)` |
| Cost per application | Sponsored spend divided by applications | `SUM(sponsored_spend_usd) / SUM(applications)` |
| Cost per qualified application | Sponsored spend divided by qualified applications | `SUM(sponsored_spend_usd) / SUM(qualified_applications)` |

## Calculation rules

- Rate and efficiency metrics use aggregated numerators and denominators.
- Daily percentages must not be averaged.
- Division uses `NULLIF(denominator, 0)` to prevent divide-by-zero errors.
- Apply rate means applications divided by clicks, not applications divided by impressions.
- Monetary metrics are denominated in US dollars.

## Governance rules

- Additive semantic facts are private.
- Business consumers use public certified metrics.
- AMER analysts see AMER performance only.
- EMEA analysts see EMEA performance only.
- Executives can see every market.
- Account-manager email addresses are masked for analyst roles.
- Consumers receive semantic-view access without direct access to analytics tables.
- Certified metrics must reconcile to physical SQL before release.
