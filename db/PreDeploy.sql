-- Grant the Entra group "sql-data-writers-jobpipeline" data-plane access to
-- this database. The Function App's MI is a member of the group (see
-- infra/entra.tf), so read/write access flows via group membership.
--
-- Idempotent: CREATE USER is guarded by an existence check; ALTER ROLE ADD
-- MEMBER no-ops if the principal is already a member.

IF NOT EXISTS (
    SELECT 1 FROM sys.database_principals
    WHERE name = N'sql-data-writers-jobpipeline'
)
BEGIN
    CREATE USER [sql-data-writers-jobpipeline] FROM EXTERNAL PROVIDER;
END;

ALTER ROLE db_datareader ADD MEMBER [sql-data-writers-jobpipeline];
ALTER ROLE db_datawriter ADD MEMBER [sql-data-writers-jobpipeline];
