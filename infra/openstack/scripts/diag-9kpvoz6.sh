#!/usr/bin/env bash
set -euo pipefail
cd /opt/testVPStrade
set -a; source infra/docker/.env; set +a
psql "$POSTGRES_DSN" -c "SELECT id, event_type, published, created_at FROM vps.outbox WHERE id=666;"
docker logs docker-vps-worker-1 --since 2h 2>&1 | grep -iE '9kpvoz|14ed08c1|reinstall' | tail -40
