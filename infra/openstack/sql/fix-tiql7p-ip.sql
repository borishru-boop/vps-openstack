UPDATE vps.instances
SET ip_address = '95.216.1.146', updated_at = now()
WHERE hostname = 'vps-tiql7p' AND state = 'creating';

SELECT id, hostname, state, external_id, ip_address FROM vps.instances WHERE hostname = 'vps-tiql7p';
