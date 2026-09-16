SELECT hostname, state, host(ip_address) ip, region,
       provider_meta->>'software_profile_id' soft,
       LEFT(COALESCE(provider_meta->'software_bundle'->'vless'->>'uri',''), 100) vless,
       LEFT(COALESCE(provider_meta->'software_bundle'->'hysteria2'->>'uri',''), 100) hy2,
       updated_at
FROM vps.instances
WHERE state = 'running'
  AND (
    provider_meta->>'software_profile_id' = '3x-ui'
    OR provider_meta->'software_bundle'->>'profile' = '3x-ui'
  )
ORDER BY updated_at DESC
LIMIT 15;
