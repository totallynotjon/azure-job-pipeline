-- ONE-TIME BOOTSTRAP. Run this ONCE, manually, connected as the SQL AAD admin
-- (the user in var.sql_admin_login). Not part of DACPAC — chicken-and-egg:
-- the CI SP needs DB access to RUN DACPAC, so this can't be in the DACPAC.
--
-- What this does:
--   Grants the GitHub Actions service principal (sp-azure-job-pipeline)
--   db_owner on this database, so DACPAC publishes from CI can create users
--   from external provider, run PreDeploy scripts, apply schema, etc.
--
-- Run once:
--   az account set --subscription <sub>
--   sqlcmd -S sql-jonsjobpipeline.database.windows.net \
--          -d sqldb-jobpipeline \
--          -G \
--          -i db/Bootstrap/GrantCiSpAccess.sql
--
-- (-G uses Entra interactive / default auth; you'll be signed in as the
--  tenant admin you configured in sql_admin_login. `db_owner` is overkill
--  for routine deploys; tighten to db_ddladmin + db_datawriter later if
--  needed.)
--
-- Idempotent: safe to re-run.

IF NOT EXISTS (
    SELECT 1 FROM sys.database_principals
    WHERE name = N'sp-azure-job-pipeline'
)
BEGIN
    CREATE USER [sp-azure-job-pipeline] FROM EXTERNAL PROVIDER;
END;

ALTER ROLE db_owner ADD MEMBER [sp-azure-job-pipeline];
