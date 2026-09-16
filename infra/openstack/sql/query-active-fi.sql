SELECT id, hostname, state, external_id, ip_address, created_at
FROM vps.instances
WHERE region = 'fi' AND state NOT IN ('deleted', 'error')
ORDER BY created_at DESC
LIMIT 10;
