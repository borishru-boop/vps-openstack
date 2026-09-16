SELECT i.hostname, i.state, host(i.ip_address) ip, i.external_id, i.region,
       n.name node_name, i.created_at, i.updated_at,
       LEFT(COALESCE(i.provider_meta->>'provision_error',''), 200) err
FROM vps.instances i
LEFT JOIN vps.nodes n ON n.id = i.node_id
WHERE i.hostname = 'vps-8doz0w' OR i.hostname LIKE '%8doz0w%';
