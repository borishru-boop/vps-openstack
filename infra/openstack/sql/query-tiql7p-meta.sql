SELECT hostname, state, provider_meta::text
FROM vps.instances
WHERE hostname = 'vps-tiql7p';
