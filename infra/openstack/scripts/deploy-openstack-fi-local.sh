#!/usr/bin/env bash
# Deploy vps + vps-worker with OpenStack overlay — NO git reset --hard.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
ENV_MAIN="${ENV_FILE:-$ROOT/infra/docker/.env}"
ENV_LOCAL="${ENV_LOCAL:-$ROOT/infra/docker/.env.local}"
COMPOSE="$ROOT/infra/docker/docker-compose.back.yml"
OVERRIDE="$ROOT/infra/openstack/docker-compose.openstack-fi.override.yml"

for f in "$ENV_MAIN" "$OVERRIDE"; do
  if [[ ! -f "$f" ]]; then
    echo "Missing $f" >&2
    exit 1
  fi
done

ENV_ARGS=(--env-file "$ENV_MAIN")
[[ -f "$ENV_LOCAL" ]] && ENV_ARGS+=(--env-file "$ENV_LOCAL")

cd "$ROOT/infra/docker"

echo "=== Build vps image (local) ==="
TAG="${IMAGE_TAG:-latest}"
# Load IMAGE_TAG from env files if not set in shell
if [[ -z "${IMAGE_TAG:-}" ]]; then
  for ef in "$ENV_MAIN" "$ENV_LOCAL"; do
    [[ -f "$ef" ]] || continue
    val="$(grep -E '^IMAGE_TAG=' "$ef" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '\r' || true)"
    [[ -n "$val" ]] && TAG="$val" && break
  done
fi
IMAGE="ghcr.io/borishru-boop/testvps-trade-vps:${TAG}"
docker build -f "$ROOT/services/vps/Dockerfile" -t "$IMAGE" "$ROOT"
# Also tag latest so manual inspect/pull stays predictable
[[ "$TAG" != "latest" ]] && docker tag "$IMAGE" "ghcr.io/borishru-boop/testvps-trade-vps:latest"

echo "=== Restart vps + vps-worker ==="
unset TBANK_PASSWORD JWT_SECRET POSTGRES_DSN 2>/dev/null || true
docker compose "${ENV_ARGS[@]}" -f "$COMPOSE" -f "$OVERRIDE" up -d --force-recreate vps vps-worker

sleep 3
docker compose "${ENV_ARGS[@]}" -f "$COMPOSE" ps vps vps-worker
curl -sf "http://127.0.0.1:${GATEWAY_PORT:-8080}/health" && echo
echo "DEPLOY OPENSTACK-FI OK"
