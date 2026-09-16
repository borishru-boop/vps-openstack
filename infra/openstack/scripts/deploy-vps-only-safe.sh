#!/usr/bin/env bash
# Deploy only vps + vps-worker from current tree. NO git reset.
set -euo pipefail
ROOT=/opt/testVPStrade
cd "$ROOT"
set -a
source infra/docker/.env
[[ -f infra/docker/.env.local ]] && source infra/docker/.env.local
set +a

TAG="${IMAGE_TAG:-latest}"
IMAGE="ghcr.io/borishru-boop/testvps-trade-vps:${TAG}"
echo "Building $IMAGE"
docker build -f services/vps/Dockerfile -t "$IMAGE" .
docker tag "$IMAGE" "ghcr.io/borishru-boop/testvps-trade-vps:latest" || true

COMPOSE=(docker compose --env-file infra/docker/.env)
[[ -f infra/docker/.env.local ]] && COMPOSE+=(--env-file infra/docker/.env.local)
COMPOSE+=(-f infra/docker/docker-compose.back.yml)
if [[ -f infra/openstack/docker-compose.openstack-fi.override.yml ]]; then
  COMPOSE+=(-f infra/openstack/docker-compose.openstack-fi.override.yml)
fi

echo "Recreate vps + vps-worker"
"${COMPOSE[@]}" up -d --force-recreate --no-deps vps vps-worker
sleep 3
"${COMPOSE[@]}" ps vps vps-worker
docker logs docker-vps-worker-1 --since 1m 2>&1 | tail -15 || true
echo DEPLOY_OK
