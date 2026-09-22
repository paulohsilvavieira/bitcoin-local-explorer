#!/bin/sh
set -eu

# O bitcoind exige Basic Auth (RPC_USER/RPC_PASSWORD). Quem chama /rpc só
# precisa do X-RPC-Token — o proxy injeta a credencial real do bitcoind,
# que nunca é exposta a quem consome a API.
export RPC_BASIC_AUTH="$(printf '%s' "${RPC_USER}:${RPC_PASSWORD}" | base64 | tr -d '\n')"

exec /docker-entrypoint.sh "$@"
