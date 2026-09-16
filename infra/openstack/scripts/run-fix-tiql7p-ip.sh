#!/usr/bin/env bash
set -euo pipefail
cd /opt/testVPStrade
set -a; source infra/docker/.env; set +a
psql "$POSTGRES_DSN" -f /tmp/fix-tiql7p-ip-186.sql
psql "$POSTGRES_DSN" -c "SELECT hostname, host(ip_address) ip, state, LEFT(COALESCE(root_password,''),3) pwd_prefix FROM vps.instances WHERE hostname='vps-tiql7p';"
