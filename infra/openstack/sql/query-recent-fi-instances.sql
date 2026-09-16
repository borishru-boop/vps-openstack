SELECT id, hostname, state, external_id, ip_address, region, provider, created_at
FROM vps.instances
WHERE hostname LIKE '%82ox77%' OR hostname LIKE '%5468%'
ORDER BY created_at DESC;

SELECT id, event_type, status, payload->>'external_id' AS ext, created_at
FROM vps.outbox
WHERE aggregate_id IN (
  SELECT id::text FROM vps.instances WHERE hostname LIKE '%82ox77%'
)
ORDER BY created_at DESC
LIMIT 10;
