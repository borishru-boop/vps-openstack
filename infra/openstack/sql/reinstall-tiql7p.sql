BEGIN;

UPDATE vps.instances
SET state = 'reinstalling',
    updated_at = now(),
    worker_poll_claimed_at = NULL,
    worker_poll_claimed_by = NULL,
    provider_meta = COALESCE(provider_meta, '{}'::jsonb)
        - 'provision_error' - 'provision_failed_at' - 'guest_agent_warmup_at'
        - 'vf_password_reset_at' - 'reinstall_build_started'
WHERE id = '4a73bc67-ac56-4e09-940e-17e14f8d1df4'
  AND state IN ('running', 'stopped', 'error');

INSERT INTO vps.outbox (event_type, payload)
SELECT 'instance.reinstall_requested',
       jsonb_build_object(
         'instance_id', '4a73bc67-ac56-4e09-940e-17e14f8d1df4',
         'os_template_id', COALESCE(
           (SELECT os_template_id FROM vps.orders o JOIN vps.instances i ON i.order_id = o.id WHERE i.id = '4a73bc67-ac56-4e09-940e-17e14f8d1df4'),
           'ubuntu-server-24-04-lts-noble-numbat'
         ),
         'ssh_keys', '[]'::jsonb
       )
WHERE EXISTS (SELECT 1 FROM vps.instances WHERE id = '4a73bc67-ac56-4e09-940e-17e14f8d1df4' AND state = 'reinstalling');

SELECT hostname, state FROM vps.instances WHERE id = '4a73bc67-ac56-4e09-940e-17e14f8d1df4';

COMMIT;
