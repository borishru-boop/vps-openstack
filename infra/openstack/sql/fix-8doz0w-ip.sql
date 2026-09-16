UPDATE vps.instances
SET ip_address = '194.164.216.187'
WHERE hostname = 'vps-8doz0w'
RETURNING hostname, host(ip_address) ip, state;
