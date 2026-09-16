#!/usr/bin/env bash
set -euo pipefail
cd /opt/testVPStrade
set -a; source infra/docker/.env; set +a

VLESS='vless://0075b8ee-42b4-440f-9446-54c70cc7a5bf@212.102.227.51:443?type=tcp&encryption=none&flow=xtls-rprx-vision&security=reality&pbk=KHqSPytFlwzeAr3DP-LSFi0aNefqu7AMe3tBC8mFnSw&fp=firefox&sni=www.5ka.ru&sid=085b090e#VLESS-www.5ka.ru'
HY2='hysteria2://24886d5826d1bf6354310378@212.102.227.51:443/?sni=www.wikipedia.org&insecure=1&pinSHA256=556125437087696413370d955ee16086053e806738e67ce042667172ae5b159e#HY2-www.wikipedia.org'

psql "$POSTGRES_DSN" -v ON_ERROR_STOP=1 <<SQL
UPDATE vps.instances
SET provider_meta = jsonb_set(
      jsonb_set(
        COALESCE(provider_meta, '{}'::jsonb),
        '{software_bundle,vless,uri}',
        to_jsonb('$VLESS'::text),
        true
      ),
      '{software_bundle,hysteria2,uri}',
      to_jsonb('$HY2'::text),
      true
    ),
    updated_at = now()
WHERE hostname = 'vps-ibqll1'
RETURNING hostname,
  provider_meta->'software_bundle'->'vless'->>'uri' AS vless,
  provider_meta->'software_bundle'->'hysteria2'->>'uri' AS hy2;
SQL

echo "=== UDP/TCP 443 from back ==="
timeout 3 bash -c 'echo >/dev/tcp/212.102.227.51/443' && echo tcp443_ok || echo tcp443_fail
# quick hy2 TLS peek with SNI
timeout 5 openssl s_client -connect 212.102.227.51:443 -servername www.wikipedia.org </dev/null 2>/dev/null | openssl x509 -noout -subject -fingerprint -sha256 2>/dev/null | head -5 || echo 'openssl_hy2_note: may fail if only UDP hysteria (expected for TCP peek on shared 443 - xray answers TCP)'
timeout 5 openssl s_client -connect 212.102.227.51:443 -servername www.5ka.ru </dev/null 2>&1 | head -20 || true
