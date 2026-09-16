#!/usr/bin/env bash
set -euo pipefail
IP=212.102.227.51
export SSHPASS='r4vd5JmYJdybAoXPbun0'
ssh_opts=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o PreferredAuthentications=password -o PubkeyAuthentication=no)

sshpass -e ssh "${ssh_opts[@]}" root@"$IP" bash -s <<'EOF'
set -euo pipefail
XRAY=$(ls /usr/local/x-ui/bin/xray-linux-* 2>/dev/null | head -1)
echo "XRAY=$XRAY"
python3 - <<'PY'
import json
cfg=json.load(open("/usr/local/x-ui/bin/config.json"))
for ib in cfg.get("inbounds",[]):
  if ib.get("protocol")!="vless":
    continue
  ss=ib.get("streamSettings") or {}
  rs=ss.get("realitySettings") or {}
  print("port", ib.get("port"))
  print("security", ss.get("security"))
  print("dest", rs.get("dest"))
  print("serverNames", rs.get("serverNames"))
  print("shortIds", rs.get("shortIds"))
  print("privateKey", rs.get("privateKey"))
  print("publicKey_field", rs.get("publicKey"))
  settings=rs.get("settings") or {}
  print("settings.publicKey", settings.get("publicKey"))
  print("fingerprint", rs.get("fingerprint") or ss.get("realitySettings",{}).get("fingerprint"))
  clients=((ib.get("settings") or {}).get("clients") or [])
  for c in clients:
    print("client", c.get("email"), c.get("id"), c.get("flow"))
PY
echo "=== derive public from private ==="
PRIV=$(python3 -c 'import json; cfg=json.load(open("/usr/local/x-ui/bin/config.json"));
rs=next((ib.get("streamSettings",{}).get("realitySettings",{}) for ib in cfg["inbounds"] if ib.get("protocol")=="vless"),{});
print(rs.get("privateKey",""))')
echo "PRIV=$PRIV"
"$XRAY" x25519 -i "$PRIV" 2>&1 || "$XRAY" x25519 --i "$PRIV" 2>&1 || true
echo "=== raw x25519 help ==="
"$XRAY" x25519 -h 2>&1 | head -20 || true
echo "=== from back connectivity already known; local curl ==="
timeout 3 bash -c 'echo >/dev/tcp/127.0.0.1/443' && echo local443_ok
EOF
