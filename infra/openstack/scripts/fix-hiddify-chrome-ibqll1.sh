#!/usr/bin/env bash
set -euo pipefail
IP=212.102.227.51
export SSHPASS='r4vd5JmYJdybAoXPbun0'
ssh_opts=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o PreferredAuthentications=password -o PubkeyAuthentication=no)

sshpass -e ssh "${ssh_opts[@]}" root@"$IP" bash -s <<'EOF'
set -euo pipefail
echo "=== sync time ==="
timedatectl set-ntp true 2>/dev/null || true
apt-get install -y chrony >/dev/null 2>&1 || true
systemctl enable --now chrony 2>/dev/null || systemctl enable --now chronyd 2>/dev/null || true
chronyc -a makestep 2>/dev/null || true
date -u
timedatectl | head -6

echo "=== set Reality fingerprint chrome in x-ui db + config ==="
python3 - <<'PY'
import json, sqlite3, os
cfg_path="/usr/local/x-ui/bin/config.json"
cfg=json.load(open(cfg_path))
changed=False
for ib in cfg.get("inbounds",[]):
  if ib.get("protocol")!="vless":
    continue
  ss=ib.setdefault("streamSettings",{})
  rs=ss.setdefault("realitySettings",{})
  if rs.get("fingerprint")!="chrome":
    rs["fingerprint"]="chrome"
    changed=True
  print("fingerprint now", rs.get("fingerprint"), "pbk", rs.get("publicKey"), "sid", rs.get("shortIds"))
if changed:
  open(cfg_path,"w").write(json.dumps(cfg, ensure_ascii=False, indent=2))
  print("config.json updated")

for db in ("/etc/x-ui/x-ui.db","/usr/local/x-ui/db/x-ui.db"):
  if not os.path.isfile(db):
    continue
  conn=sqlite3.connect(db)
  cur=conn.cursor()
  rows=list(cur.execute("select id, stream_settings from inbounds where protocol='vless'"))
  for iid, raw in rows:
    ss=json.loads(raw or "{}")
    rs=ss.setdefault("realitySettings",{})
    rs["fingerprint"]="chrome"
    cur.execute("update inbounds set stream_settings=? where id=?", (json.dumps(ss, ensure_ascii=False), iid))
    print("db", db, "inbound", iid, "fp=chrome")
  conn.commit(); conn.close()
PY

systemctl restart x-ui
sleep 2
systemctl is-active x-ui
ss -tlnp | grep ':443 ' || true
echo "=== watch hint: journal will show REALITY invalid if client fp/key mismatch ==="
EOF

cd /opt/testVPStrade && set -a && source infra/docker/.env && set +a
VLESS='vless://0075b8ee-42b4-440f-9446-54c70cc7a5bf@212.102.227.51:443?type=tcp&encryption=none&flow=xtls-rprx-vision&security=reality&pbk=KHqSPytFlwzeAr3DP-LSFi0aNefqu7AMe3tBC8mFnSw&fp=chrome&sni=www.5ka.ru&sid=085b090e#VLESS-www.5ka.ru'
psql "$POSTGRES_DSN" -v ON_ERROR_STOP=1 -c "UPDATE vps.instances SET provider_meta = jsonb_set(COALESCE(provider_meta,'{}'::jsonb), '{software_bundle,vless,uri}', to_jsonb('$VLESS'::text), true), updated_at=now() WHERE hostname='vps-ibqll1' RETURNING hostname;"
echo "NEW_VLESS=$VLESS"
