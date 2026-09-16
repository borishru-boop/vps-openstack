SELECT i.id, i.hostname, i.state, host(i.ip_address) ip, i.external_id, i.region,
       o.order_number
FROM vps.instances i
LEFT JOIN vps.orders o ON o.id = i.order_id
WHERE i.hostname = 'vps-s8ss8b';
