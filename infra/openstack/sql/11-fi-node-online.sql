-- Keep FI OpenStack node orderable (status must be online).
UPDATE vps.nodes SET
  status = 'online',
  vf_enabled = false,
  maintenance_mode = false,
  updated_at = now()
WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb002';

SELECT name, region, status, external_id, vf_enabled, supported_tiers
FROM vps.nodes WHERE region = 'fi';
