SELECT i.id, i.hostname, i.state, i.external_id, i.ip_address, i.created_at
FROM vps.instances i
WHERE i.state IN ('creating', 'queued', 'error')
ORDER BY i.created_at DESC
LIMIT 5;
