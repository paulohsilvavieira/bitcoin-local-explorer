#!/bin/bash
set -euo pipefail

CONF=/bitcoin/bitcoin.conf
WALLET_NAME="${WALLET_NAME:-bitcoin-wallet-regtest}"

hasWallet=$(bitcoin-cli -regtest -conf="$CONF" listwallets | jq -e '.[]' || true)
if [ -z "$hasWallet" ]; then
    echo "Create wallet..."
    bitcoin-cli -regtest -conf="$CONF" -named createwallet wallet_name="$WALLET_NAME" load_on_startup=true
else
    echo "Already created wallet!"
fi
