#!/usr/bin/env bash
set -euo pipefail
cd /opt/testVPStrade
set -a; source infra/docker/.env; set +a

echo "=== instance state ==="
psql "$POSTGRES_DSN" -c "SELECT hostname, state, host(ip_address) ip, external_id, updated_at FROM vps.instances WHERE hostname='vps-9kpvoz';"

echo "=== outbox / reinstall ==="
psql "$POSTGRES_DSN" -c "SELECT id, event_type, published, created_at, LEFT(payload::text,200) FROM vps.outbox WHERE payload::text LIKE '%9kpvoz%' OR payload::text LIKE '%811%' ORDER BY id DESC LIMIT 10;"

echo "=== probe panel / 443 from back ==="
curl -sS -m 5 -o /dev/null -w "panel_http=%{http_code}\n" http://91.108.247.17:2053/panel/ || echo panel_fail
curl -sS -m 5 -o /dev/null -w "tcp443=%{http_code}\n" https://91.108.247.17:443/ || echo https443_fail
# TLS handshake peek
timeout 5 openssl s_client -connect 91.108.247.17:443 -servername www.5ka.ru </dev/null 2>&1 | head -30 || true

echo "=== via GB HV guest check ==="
SSHPASS="$GB_SSH_PASS" sshpass -e ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 root@212.108.83.47 bash -s <<'GB'
set -euo pipefail
virsh list --all | grep -i 811 || virsh list --all | head -30
# find domain
DOM=$(virsh list --name | while read d; do [[ -z "$d" ]] && continue; virsh domifaddr "$d" 2>/dev/null | grep -q 91.108.247.17 && echo "$d" && break; done || true)
if [[ -z "${DOM:-}" ]]; then
  # try by VF id naming
  DOM=$(virsh list --name | grep -E '811|9kpvoz' | head -1 || true)
fi
echo "DOM=${DOM:-none}"
if [[ -n "${DOM:-}" ]]; then
  virsh dominfo "$DOM" | head -20
  # guest agent exec if available
  virsh qemu-agent-command "$DOM" '{"execute":"guest-exec","arguments":{"path":"/bin/bash","arg":["-lc","ss -tulpn | grep -E \"443|2053|xray|hysteria|x-ui\"; systemctl is-active x-ui hysteria-server 2>/dev/null; free -m; uptime"],"capture-output":true}}' 2>/dev/null || echo no_guest_exec
fi
# also try SSH with known VF password via console? check if we can get password from virtfusion control
GB
