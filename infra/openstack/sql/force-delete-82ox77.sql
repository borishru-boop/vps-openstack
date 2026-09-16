BEGIN;

UPDATE vps.outbox
SET published = true
WHERE published = false
  AND payload->>'instance_id' = '02ef5270-f628-4c4a-a512-657b0f95f602';

UPDATE vps.instances
SET state = 'deleted',
    ip_address = NULL,
    external_id = NULL,
    provider_meta = COALESCE(provider_meta, '{}'::jsonb) || '{"force_deleted":true}'::jsonb,
    updated_at = now()
WHERE id = '02ef5270-f628-4c4a-a512-657b0f95f602'
  AND state <> 'deleted';

SELECT id, hostname, state, external_id, ip_address FROM vps.instances WHERE hostname = 'vps-82ox77';

COMMIT;
