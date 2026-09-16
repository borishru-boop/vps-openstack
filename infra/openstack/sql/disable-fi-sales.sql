-- Disable FI region from sales until Helsinki public IP routing is fixed.
BEGIN;

UPDATE vps.regions
SET enabled = false, updated_at = now()
WHERE code = 'fi';

UPDATE vps.region_tiers
SET enabled = false, updated_at = now()
WHERE region = 'fi';

UPDATE vps.nodes
SET status = 'offline',
    maintenance_mode = true,
    updated_at = now()
WHERE region = 'fi';

SELECT code, enabled FROM vps.regions WHERE code = 'fi';
SELECT region, tier, enabled FROM vps.region_tiers WHERE region = 'fi' ORDER BY tier;
SELECT name, region, status, maintenance_mode FROM vps.nodes WHERE region = 'fi';

COMMIT;
