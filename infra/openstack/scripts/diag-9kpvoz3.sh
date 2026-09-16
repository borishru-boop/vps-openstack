#!/usr/bin/env bash
set -euo pipefail
cd /opt/testVPStrade
set -a; source infra/docker/.env; set +a

echo "=== which instance is bf68d0ad ==="
psql "$POSTGRES_DSN" -c "SELECT hostname, state, host(ip_address) ip, region, provider_meta->>'software_profile_id' soft FROM vps.instances WHERE id='bf68d0ad-235d-4fd1-a476-67df0b73c9a0' OR hostname='vps-9kpvoz';"

echo "=== full 3x-ui error (last) ==="
docker logs docker-vps-worker-1 --since 30m 2>&1 | grep -A40 'software retry bf68d0ad' | tail -50

echo "=== guest-exec on 9kpvoz domain ==="
SSHPASS="$GB_SSH_PASS" sshpass -e ssh -o StrictHostKeyChecking=no root@212.108.83.47 bash -s <<'GB'
set -euo pipefail
DOM=ae6ac996-a676-40ac-a91b-3771cd119be1
# guest-exec
pid=$(virsh qemu-agent-command "$DOM" '{"execute":"guest-exec","arguments":{"path":"/bin/bash","arg":["-lc","echo ===PORTS===; ss -tulpn 2>/dev/null | grep -E \"443|2053|xray|hysteria|x-ui\" || netstat -tulpn 2>/dev/null | grep -E \"443|2053\"; echo ===SVC===; systemctl is-active x-ui 2>/dev/null; systemctl is-active hysteria-server 2>/dev/null; systemctl is-failed x-ui hysteria-server 2>/dev/null; echo ===MEM===; free -m; echo ===XRAY===; pgrep -a xray | head -3; pgrep -a hysteria | head -3; pgrep -a x-ui | head -3; echo ===UFW===; ufw status 2>/dev/null | head -5 || true; iptables -L INPUT -n 2>/dev/null | head -15"],"capture-output":true}}' | python3 -c 'import sys,json; print(json.load(sys.stdin)["return"]["pid"])')
echo "exec_pid=$pid"
sleep 2
virsh qemu-agent-command "$DOM" "{\"execute\":\"guest-exec-status\",\"arguments\":{\"pid\":$pid}}" | python3 -c '
import sys,json,base64
r=json.load(sys.stdin)["return"]
print("exited", r.get("exited"), "code", r.get("exitcode"))
for k in ("out-data","err-data"):
  if k in r and r[k]:
    print(base64.b64decode(r[k]).decode("utf-8","replace"))
'
GB
