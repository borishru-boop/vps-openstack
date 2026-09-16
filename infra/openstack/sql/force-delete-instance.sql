-- Force-delete stuck instance by hostname (ops). Replace :hostname before run.
-- Usage: psql ... -v hostname=vps-82ox77 -f force-delete-instance.sql

\set hostname 'vps-82ox77'

BEGIN;

UPDATE vps.outbox
SET status = 'done', updated_at = now()
WHERE aggregate_id = (SELECT id::text FROM vps.instances WHERE hostname = :'hostname' LIMIT 1)
  AND status IN ('pending', 'processing');

UPDATE vps.instances
SET state = 'deleted',
    ip_address = NULL,
    external_id = NULL,
    provider_meta = COALESCE(provider_meta, '{}'::jsonb) || '{"delete_pending":true,"force_deleted":true}'::jsonb,
    updated_at = now()
WHERE hostname = :'hostname'
  AND state <> 'deleted';

SELECT id, hostname, state, external_id FROM vps.instances WHERE hostname = :'hostname';

COMMIT;
