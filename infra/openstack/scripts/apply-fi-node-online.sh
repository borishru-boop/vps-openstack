#!/usr/bin/env bash
set -euo pipefail
set -a
source /opt/testVPStrade/infra/docker/.env
set +a
docker run --rm --network docker_default \
  -v /tmp/11-fi-node-online.sql:/q.sql \
  postgres:16-alpine psql "$POSTGRES_DSN" -f /q.sql
