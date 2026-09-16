UPDATE vps.nodes SET
  external_id = 'c4c5b18e-967b-463e-9771-f8fb7eee905f',
  vf_enabled = false,
  status = 'online',
  maintenance_mode = false,
  supported_tiers = ARRAY['prosto']::text[],
  updated_at = now()
WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb002';

SELECT name, region, external_id, vf_enabled, supported_tiers
FROM vps.nodes WHERE region = 'fi';
