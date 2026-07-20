Important design decisions

- Surrogate primary keys

The operational tables use generated numeric identifiers such as job_id and employer_id.

- Nullable job seeker on sessions

Anonymous users may search without signing in, so: search_sessions.job_seeker_id is nullable.

- Applications require an identified job seeker, so: applications.job_seeker_id is not nullable.

- Nullable click on applications

An application might originate from:

A search click
A saved job
An email
A direct job URL

Therefore applications.click_id is nullable.

- One click per impression

The unique constraint on: job_clicks.impression_id means one displayed result can generate at most one recorded click.

- Many-to-many job skills

One job may require several skills, and one skill may appear on many jobs. The job_skills bridge resolves that relationship.

- Many-to-many campaign jobs

One campaign may sponsor several jobs. A job may also appear in different campaigns over its lifetime.