SELECT hostname, state, external_id, ip_address FROM vps.instances WHERE hostname = 'vps-tiql7p';
SELECT id, event_type, published, payload::text FROM vps.outbox WHERE payload::text LIKE '%4a73bc67%' ORDER BY id DESC LIMIT 5;
