BEGIN;

UPDATE vps.instances
SET external_id = 'dbef913f-fa47-4659-bb55-a1f9d4cfae76',
    ip_address = '95.216.1.146',
    state = 'reinstalling',
    updated_at = now()
WHERE id = '4a73bc67-ac56-4e09-940e-17e14f8d1df4';

UPDATE vps.outbox
SET published = false,
    worker_poll_claimed_at = NULL,
    worker_poll_claimed_by = NULL
WHERE id = 622;

SELECT hostname, state, external_id, ip_address FROM vps.instances WHERE id = '4a73bc67-ac56-4e09-940e-17e14f8d1df4';

COMMIT;
