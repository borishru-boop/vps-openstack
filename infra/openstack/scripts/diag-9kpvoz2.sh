#!/usr/bin/env bash
set -euo pipefail
cd /opt/testVPStrade
set -a; source infra/docker/.env; set +a

echo "=== worker logs 9kpvoz/811/3x ==="
docker logs docker-vps-worker-1 --since 3h 2>&1 | grep -iE '9kpvoz|811|3x-ui|reinstall|software' | tail -80

echo "=== VF server 811 ==="
curl -sk "${VIRTFUSION_API_URL}/servers/811" -H "Authorization: Bearer ${VIRTFUSION_API_KEY}" | python3 -c 'import sys,json; d=json.load(sys.stdin).get("data",{}); print("state",d.get("state"),"comm",d.get("commissionStatus"),"buildFailed",d.get("buildFailed")); print("name",d.get("name")); pn=d.get("primaryNetwork") or {}; print("ip",pn); print("hv", (d.get("hypervisor") or {}).get("name"), (d.get("hypervisor") or {}).get("ip"))'

echo "=== GB find VM by MAC/IP ==="
SSHPASS="$GB_SSH_PASS" sshpass -e ssh -o StrictHostKeyChecking=no root@212.108.83.47 bash -s <<'GB'
set -euo pipefail
# list all running domains with IPs
for d in $(virsh list --name); do
  [[ -z "$d" ]] && continue
  addrs=$(virsh domifaddr "$d" --source agent 2>/dev/null || virsh domifaddr "$d" 2>/dev/null || true)
  if echo "$addrs" | grep -q '91.108.247.17'; then
    echo "FOUND $d"
    echo "$addrs"
  fi
done
# also qemu cmdline for 811
pgrep -af qemu-system | grep -i 811 || true
# check which VM owns the IP via bridge/arp
ip neigh | grep 91.108.247.17 || true
bridge fdb show | grep -i "$(ip neigh show 91.108.247.17 | awk '{print $5}')" 2>/dev/null || true
# try nc to guest from HV
nc -zv -w2 91.108.247.17 22 2>&1 || true
nc -zv -w2 91.108.247.17 443 2>&1 || true
nc -zv -w2 91.108.247.17 2053 2>&1 || true
# udp 443
timeout 2 bash -c 'echo | nc -u -w1 91.108.247.17 443' 2>&1 || true
GB
