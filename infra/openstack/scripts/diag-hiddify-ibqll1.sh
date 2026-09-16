#!/usr/bin/env bash
set -euo pipefail
IP=212.102.227.51
PASS='r4vd5JmYJdybAoXPbun0'

export SSHPASS="$PASS"
ssh_opts=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o PreferredAuthentications=password -o PubkeyAuthentication=no)

echo "=== ports/services ==="
sshpass -e ssh "${ssh_opts[@]}" root@"$IP" 'ss -tulpn | grep -E ":443|:2053" || true; systemctl is-active x-ui hysteria-server 2>/dev/null; free -m | head -2'

echo "=== hy2 config ==="
sshpass -e ssh "${ssh_opts[@]}" root@"$IP" 'cat /etc/hysteria/config.yaml 2>/dev/null; echo ---; openssl x509 -noout -fingerprint -sha256 -in /etc/hysteria/cert.pem 2>/dev/null; openssl x509 -noout -subject -in /etc/hysteria/cert.pem 2>/dev/null'

echo "=== xray inbounds summary ==="
sshpass -e ssh "${ssh_opts[@]}" root@"$IP" 'python3 - <<"PY"
import json,os
p="/usr/local/x-ui/bin/config.json"
cfg=json.load(open(p))
for ib in cfg.get("inbounds",[]):
  ss=ib.get("streamSettings") or {}
  print(ib.get("tag"), ib.get("port"), ib.get("protocol"), ss.get("security"), (ss.get("realitySettings") or {}).get("serverNames"))
PY'

echo "=== DB bundle URIs ==="
cd /opt/testVPStrade && set -a && source infra/docker/.env && set +a
psql "$POSTGRES_DSN" -tAc "SELECT provider_meta->'software_bundle'->'vless'->>'uri' FROM vps.instances WHERE hostname='vps-ibqll1';"
echo '---HY2---'
psql "$POSTGRES_DSN" -tAc "SELECT provider_meta->'software_bundle'->'hysteria2'->>'uri' FROM vps.instances WHERE hostname='vps-ibqll1';"
