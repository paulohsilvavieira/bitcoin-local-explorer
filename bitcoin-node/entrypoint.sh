#!/bin/bash
set -euo pipefail

CONF=/bitcoin/bitcoin.conf

envsubst '${RPC_USER} ${RPC_PASSWORD}' < /bitcoin/bitcoin.conf.template > "$CONF"

bitcoind -conf="$CONF" &
BITCOIND_PID=$!

AUTOMINING_PID=""
shutdown() {
    echo "Received shutdown signal, stopping bitcoind gracefully..."
    [ -n "$AUTOMINING_PID" ] && kill "$AUTOMINING_PID" 2>/dev/null || true
    kill -TERM "$BITCOIND_PID" 2>/dev/null || true
    wait "$BITCOIND_PID" 2>/dev/null || true
    exit 0
}
trap shutdown TERM INT

echo "Waiting for bitcoind RPC to be ready..."
until bitcoin-cli -regtest -conf="$CONF" getblockchaininfo >/dev/null 2>&1; do
    if ! kill -0 "$BITCOIND_PID" 2>/dev/null; then
        echo "bitcoind exited before becoming ready" >&2
        exit 1
    fi
    sleep 1
done
echo "bitcoind RPC is ready."

/scripts/createwallet.sh
/scripts/automining.sh &
AUTOMINING_PID=$!

wait "$BITCOIND_PID"
