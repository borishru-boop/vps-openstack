#!/usr/bin/env bash
set -euo pipefail
cd /opt/testVPStrade
set -a; source infra/docker/.env; set +a

echo "=== reinstall outbox claim ==="
psql "$POSTGRES_DSN" -c "SELECT id, event_type, published, created_at, claimed_at, claim_token IS NOT NULL AS claimed FROM vps.outbox WHERE id=666;"

echo "=== worker reinstall handling ==="
docker logs docker-vps-worker-1 --since 2h 2>&1 | grep -iE '9kpvoz|14ed08c1|reinstall' | tail -40

SSHPASS="$GB_SSH_PASS" sshpass -e ssh -o StrictHostKeyChecking=no root@212.108.83.47 bash -s <<'GB'
DOM=ae6ac996-a676-40ac-a91b-3771cd119be1
pid=$(virsh qemu-agent-command "$DOM" '{"execute":"guest-exec","arguments":{"path":"/bin/bash","arg":["-lc","python3 - <<\"PY\"\nimport json,sqlite3,os\nfor db in (\"/etc/x-ui/x-ui.db\",\"/usr/local/x-ui/db/x-ui.db\"):\n  if os.path.isfile(db):\n    c=sqlite3.connect(db); cur=c.cursor()\n    for row in cur.execute(\"select id,remark,port,protocol,settings,stream_settings from inbounds\"):\n      print(\"INBOUND\",row[0],row[1],row[2],row[3])\n      try:\n        s=json.loads(row[4] or \"{}\")\n        clients=(s.get(\"clients\") or [])\n        for cl in clients[:2]:\n          print(\"  client\", cl.get(\"email\"), cl.get(\"id\"), cl.get(\"password\"))\n      except Exception as e:\n        print(\"  settings err\",e)\n      try:\n        st=json.loads(row[5] or \"{}\")\n        rs=(st.get(\"realitySettings\") or {})\n        print(\"  reality pbk\", (rs.get(\"settings\") or {}).get(\"publicKey\") or rs.get(\"publicKey\"), \"sni\", rs.get(\"serverNames\"), \"sid\", rs.get(\"shortIds\"))\n        print(\"  security\", st.get(\"security\"))\n      except Exception as e:\n        print(\"  stream err\",e)\n    break\nprint(\"--- xray ports ---\")\ncfg=json.load(open(\"/usr/local/x-ui/bin/config.json\"))\nfor ib in cfg.get(\"inbounds\",[]):\n  print(ib.get(\"tag\"), ib.get(\"port\"), ib.get(\"protocol\"))\nPY"],"capture-output":true}}' | python3 -c 'import sys,json; print(json.load(sys.stdin)["return"]["pid"])')
sleep 3
virsh qemu-agent-command "$DOM" "{\"execute\":\"guest-exec-status\",\"arguments\":{\"pid\":$pid}}" | python3 -c '
import sys,json,base64
r=json.load(sys.stdin)["return"]
print("exit", r.get("exitcode"))
for k in ("out-data","err-data"):
  if k in r and r[k]:
    print(base64.b64decode(r[k]).decode("utf-8","replace"))
'
GB
