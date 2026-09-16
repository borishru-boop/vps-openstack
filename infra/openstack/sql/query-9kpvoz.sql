SELECT hostname, state, host(ip_address) ip, region, external_id,
       provider_meta->'software_bundle' AS software_bundle,
       provider_meta->'software_profile_id' AS soft,
       LEFT(COALESCE(provider_meta->>'software_error', provider_meta->>'provision_error', ''), 400) err,
       provider_meta
FROM vps.instances
WHERE hostname = 'vps-9kpvoz';
