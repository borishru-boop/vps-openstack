UPDATE vps.instances
SET ip_address = '194.164.216.186'
WHERE hostname = 'vps-tiql7p'
RETURNING hostname, ip_address, state;
