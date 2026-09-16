#!/usr/bin/env bash
set -euo pipefail
cd /opt/testVPStrade
set -a; source infra/docker/.env; set +a

SSHPASS="$GB_SSH_PASS" sshpass -e ssh -o StrictHostKeyChecking=no root@212.108.83.47 bash -s <<'GB'
set -euo pipefail
DOM=ae6ac996-a676-40ac-a91b-3771cd119be1
run() {
  local cmd="$1"
  local pid
  pid=$(virsh qemu-agent-command "$DOM" "{\"execute\":\"guest-exec\",\"arguments\":{\"path\":\"/bin/bash\",\"arg\":[\"-lc\",$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$cmd")],\"capture-output\":true}}" | python3 -c 'import sys,json; print(json.load(sys.stdin)["return"]["pid"])')
  sleep 2
  virsh qemu-agent-command "$DOM" "{\"execute\":\"guest-exec-status\",\"arguments\":{\"pid\":$pid}}" | python3 -c '
import sys,json,base64
r=json.load(sys.stdin)["return"]
print("exit", r.get("exitcode"))
for k in ("out-data","err-data"):
  if k in r and r[k]:
    print(base64.b64decode(r[k]).decode("utf-8","replace"))
'
}

run 'echo ===UFW===; ufw status numbered; echo ===NGINX===; ls /etc/nginx/sites-enabled 2>/dev/null; nginx -T 2>/dev/null | grep -E "listen|server_name|proxy" | head -40; echo ===HY2===; systemctl status hysteria-server --no-pager -l 2>&1 | head -40; ls -la /etc/hysteria 2>/dev/null; echo ===XRAY_IN===; python3 - <<"PY"
import json
p="bin/config.json"
import os
for cand in ["/usr/local/x-ui/bin/config.json","/etc/x-ui/bin/config.json"]:
  if os.path.isfile(cand):
    p=cand; break
print("cfg",p)
cfg=json.load(open(p))
for ib in cfg.get("inbounds",[]):
  print(ib.get("tag"), ib.get("port"), ib.get("protocol"), ib.get("listen"), (ib.get("streamSettings") or {}).get("security"))
PY
echo ===XUI_DB===; sqlite3 /etc/x-ui/x-ui.db "select id,remark,port,protocol,enable from inbounds;" 2>/dev/null || sqlite3 /usr/local/x-ui/db/x-ui.db "select id,remark,port,protocol,enable from inbounds;" 2>/dev/null
echo ===PS===; ps aux | grep -E "nginx|xray|hysteria|x-ui" | grep -v grep'
GB

echo "=== why reinstalling ==="
psql "$POSTGRES_DSN" -c "SELECT id, hostname, state, updated_at, provider_meta->>'reinstall_os' os, provider_meta->>'reinstall_requested_at' req FROM vps.instances WHERE hostname='vps-9kpvoz';"
psql "$POSTGRES_DSN" -c "SELECT id, event_type, published, created_at, LEFT(payload::text,300) FROM vps.outbox WHERE payload::text LIKE '%9kpvoz%' OR (payload->>'instance_id' IN (SELECT id::text FROM vps.instances WHERE hostname='vps-9kpvoz')) ORDER BY id DESC LIMIT 15;"
