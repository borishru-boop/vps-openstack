#!/bin/bash
# Proxies TCP to VM SSH via OVN metadata netns (Sunbeam single-node).
NETNS=ovnmeta-dae6fb0c-c1ad-4f47-94bd-04aa82bfad90
VM_IP=192.168.0.172
PORT=2222

exec ip netns exec "$NETNS" socat STDIO "tcp:${VM_IP}:22"
