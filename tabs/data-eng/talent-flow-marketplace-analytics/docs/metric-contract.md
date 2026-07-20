Grain Matrix

Business process	Fact grain								Primary identifier

Search				One row per search request				search_id
Impression			One row per job shown in one search		impression_id
Click				One row per job impression clicked		click_id
Application			One row per application attempt			application_id
Sponsored spend		One row per campaign, job, and date		composite key


Metric definitions

Metric						Definition

Searches					Count of search records
Zero-result searches		Searches where results_count = 0
Zero-result rate			Zero-result searches ÷ searches
Impressions					Count of jobs displayed
Clicks						Count of clicked impressions
CTR							Clicks ÷ impressions
Applications started		Count of application records
Submitted applications		Applications with a non-null submitted_at
Click-to-apply rate			Submitted applications ÷ clicks
Impression-to-apply rate	Submitted applications ÷ impressions
CPC							Sponsored spend ÷ sponsored clicks
CPA							Sponsored spend ÷ sponsored submitted applications


Ratios must be calculated after aggregating their numerators and denominators.

Do not average row-level CTR, apply-rate, CPC, or CPA values.