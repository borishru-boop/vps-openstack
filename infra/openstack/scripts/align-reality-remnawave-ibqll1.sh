#!/usr/bin/env bash
set -euo pipefail
IP=212.102.227.51
export SSHPASS='r4vd5JmYJdybAoXPbun0'
ssh_opts=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20 -o PreferredAuthentications=password -o PubkeyAuthentication=no)

NEW_SID=$(openssl rand -hex 8)
NEW_SNI=nu.nl
NEW_FP=firefox

META=$(sshpass -e ssh "${ssh_opts[@]}" root@"$IP" "NEW_SID=$NEW_SID NEW_SNI=$NEW_SNI NEW_FP=$NEW_FP bash -s" <<'EOF'
set -euo pipefail
python3 <<'PY'
import json, sqlite3, os
sid=os.environ["NEW_SID"]
sni=os.environ["NEW_SNI"]
fp=os.environ["NEW_FP"]
cfg_path="/usr/local/x-ui/bin/config.json"
cfg=json.load(open(cfg_path))
pbk=""
uuid=""
for ib in cfg.get("inbounds",[]):
  if ib.get("protocol")!="vless": continue
  ss=ib.setdefault("streamSettings",{})
  rs=ss.setdefault("realitySettings",{})
  rs["fingerprint"]=fp
  rs["dest"]=f"{sni}:443"
  rs["serverNames"]=[sni]
  rs["shortIds"]=[sid]
  pbk=rs.get("publicKey") or ""
  clients=((ib.get("settings") or {}).get("clients") or [])
  if clients: uuid=clients[0].get("id") or ""
open(cfg_path,"w").write(json.dumps(cfg, ensure_ascii=False, indent=2))
for db in ("/etc/x-ui/x-ui.db","/usr/local/x-ui/db/x-ui.db"):
  if not os.path.isfile(db): continue
  conn=sqlite3.connect(db)
  cur=conn.cursor()
  for iid, raw in list(cur.execute("select id, stream_settings from inbounds where protocol='vless'")):
    ss=json.loads(raw or "{}")
    rs=ss.setdefault("realitySettings",{})
    rs["fingerprint"]=fp
    rs["dest"]=f"{sni}:443"
    rs["serverNames"]=[sni]
    rs["shortIds"]=[sid]
    cur.execute("update inbounds set stream_settings=? where id=?", (json.dumps(ss, ensure_ascii=False), iid))
  conn.commit(); conn.close()
print(f"UUID={uuid}")
print(f"PBK={pbk}")
print(f"SID={sid}")
print(f"SNI={sni}")
print(f"FP={fp}")
PY
systemctl restart x-ui
sleep 2
systemctl is-active x-ui >/dev/null && echo XUI=active
EOF
)

echo "$META"
UUID=$(echo "$META" | sed -n 's/^UUID=//p' | tail -1)
PBK=$(echo "$META" | sed -n 's/^PBK=//p' | tail -1)
SID=$(echo "$META" | sed -n 's/^SID=//p' | tail -1)
SNI=$(echo "$META" | sed -n 's/^SNI=//p' | tail -1)
FP=$(echo "$META" | sed -n 's/^FP=//p' | tail -1)

VLESS="vless://${UUID}@${IP}:443?type=tcp&encryption=none&flow=xtls-rprx-vision&security=reality&pbk=${PBK}&fp=${FP}&sni=${SNI}&sid=${SID}#VLESS-${SNI}"
echo "VLESS_URI=$VLESS"

cd /opt/testVPStrade && set -a && source infra/docker/.env && set +a
# escape for SQL: replace ' 
VLESS_SQL=${VLESS//\'/\'\'}
psql "$POSTGRES_DSN" -v ON_ERROR_STOP=1 -c "UPDATE vps.instances SET provider_meta = jsonb_set(jsonb_set(COALESCE(provider_meta,'{}'::jsonb), '{software_bundle,vless,uri}', to_jsonb('${VLESS_SQL}'::text), true), '{software_bundle,vless,sni}', to_jsonb('${SNI}'::text), true), updated_at=now() WHERE hostname='vps-ibqll1';"
echo DONE
