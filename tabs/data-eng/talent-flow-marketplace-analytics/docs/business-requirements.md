Project objective

Talent Flow needs an analytics system that explains how job seekers move through the marketplace funnel:

Search → Job impression → Job click → Application

The model must support both organic and sponsored job listings.


Business users

Define the four audiences:

User					Primary need
Marketplace leadership		Understand overall search-to-apply health
Product managers		Find funnel breakdowns by device, category, and location
Search quality team		Monitor zero-result searches and relevance
Advertising team		Measure sponsored spend, clicks, applications, CPC, and CPA


Core questions

The model must answer:

How many searches, impressions, clicks, and applications occurred?
What is the click-through rate?
What is the impression-to-application rate?
What percentage of searches returned zero results?
Which job categories and locations generate the most applications?
How do mobile and desktop funnels compare?
How do sponsored listings compare with organic listings?
What is the cost per sponsored click?
What is the cost per sponsored application?
Which employers, jobs, or campaigns are receiving spend but few applications?


Out of scope

Exclusions:

• Personally identifiable job-seeker information
• Résumés and application documents
• Employer billing and invoicing
• Machine-learning ranking implementation
• Real Indeed data
• Causal claims about sponsored listing performance
• Production-scale infrastructure

The last point about causal claims matters. The dashboard can compare sponsored and organic conversion, but it should not call the difference “sponsored lift” without an experiment.