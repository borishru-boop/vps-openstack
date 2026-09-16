#!/usr/bin/env bash
set -euo pipefail

HOSTNAME="${1:-vps-82ox77}"
SERVER_ID="${2:-8d0f8896-7bc8-430e-82b1-e05c0ee61664}"

export OS_AUTH_URL="${OS_AUTH_URL:-http://194.164.216.185/openstack-keystone/v3}"
export OS_USERNAME="${OS_USERNAME:-demo}"
export OS_PASSWORD="${OS_PASSWORD:?OPENSTACK_PASSWORD required}"
export OS_PROJECT_NAME="${OS_PROJECT_NAME:-demo}"
export OS_USER_DOMAIN_NAME="${OS_USER_DOMAIN_NAME:-users}"
export OS_PROJECT_DOMAIN_NAME="${OS_PROJECT_DOMAIN_NAME:-users}"
export OS_REGION_NAME="${OS_REGION_NAME:-RegionOne}"
export OS_IDENTITY_API_VERSION=3

echo "=== OpenStack server $SERVER_ID ==="
openstack server show "$SERVER_ID" -f value -c status -c name 2>/dev/null || echo "server not found"

echo "=== Release floating IPs ==="
for fip in $(openstack floating ip list --server "$SERVER_ID" -f value -c ID 2>/dev/null || true); do
  echo "Disassociate $fip"
  openstack server remove floating ip "$SERVER_ID" "$fip" 2>/dev/null || true
  openstack floating ip delete "$fip" 2>/dev/null || true
done

echo "=== Delete server ==="
openstack server delete "$SERVER_ID" 2>/dev/null || true
sleep 3
openstack server show "$SERVER_ID" 2>/dev/null || echo "server deleted"

echo "=== DB force delete hostname=$HOSTNAME ==="
set -a
source /opt/testVPStrade/infra/docker/.env
set +a
psql "$POSTGRES_DSN" <<SQL
BEGIN;
UPDATE vps.outbox SET processed_at = now()
WHERE aggregate_id = (SELECT id::text FROM vps.instances WHERE hostname = '$HOSTNAME' LIMIT 1)
  AND processed_at IS NULL;
UPDATE vps.instances
SET state = 'deleted', ip_address = NULL, external_id = NULL,
    provider_meta = COALESCE(provider_meta, '{}'::jsonb) || '{"force_deleted":true}'::jsonb,
    updated_at = now()
WHERE hostname = '$HOSTNAME' AND state <> 'deleted';
SELECT id, hostname, state FROM vps.instances WHERE hostname = '$HOSTNAME';
COMMIT;
SQL

echo DONE
