BEGIN;

UPDATE vps.outbox
SET published = true
WHERE published = false
  AND payload::text LIKE '%2ed70e4c-b15c-440d-8e1c-bccc425eadc4%';

UPDATE vps.instances
SET state = 'deleted',
    ip_address = NULL,
    external_id = NULL,
    provider_meta = COALESCE(provider_meta, '{}'::jsonb) || '{"force_deleted":true}'::jsonb,
    updated_at = now()
WHERE hostname = 'vps-s8ss8b'
  AND state <> 'deleted';

SELECT id, hostname, state, external_id FROM vps.instances WHERE hostname = 'vps-s8ss8b';

COMMIT;
