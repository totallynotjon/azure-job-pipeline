# Pipeline Processing Notes (local only, gitignored)

## Orchestrator flow

1. Upsert job pipeline status from table using jobtype and id -> status
2. If it doesn't exist then create status and also create job entry
3. If processing or complete then stop
4. Set to processing

## Enrichment

- Enrich with desired company data — pass full job and job url
- Fetch full listing using job_url to populate full description

## Requirement filters (before AI)

- No confirmed contract jobs
- Below salary requirements

## AI filters

- Simple AI agent to give likelihood ranking (1-10 likelihood contract role)
- Simple AI agent to give likelihood ranking (1-10 likelihood remote role)
- Filter contract
- If likelihood remote < 7 && not within long and lat target radius -> reject
- AI agent to assess job for career strategic fit, compare job description and title to information known about user
- Use advanced thinking model and compare against directives

## Company enrichment (later in pipeline — more costly)

- Add company to table, need search agent to look for:
  - Last known layoffs date
  - Approximate employee count
  - Age of company
  - Low glassdoor or culture score rankings
  - Approximate company size
  - Last search date
- Search again if last research was more than n months ago

## Company rejection criteria

- Layoff date cutoff
- Employee count minimum
- Company age minimum
- Culture index score minimum

## Final

- Set status to complete
