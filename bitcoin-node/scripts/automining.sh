#!/bin/bash
set -uo pipefail

CONF=/bitcoin/bitcoin.conf
WALLET_NAME="${WALLET_NAME:-bitcoin-wallet-regtest}"
MINING_INTERVAL="${MINING_INTERVAL:-10}"

# Faixa de valor (BTC) e fee rate (sat/vB) das transações internas simuladas a cada ciclo.
TX_MIN_AMOUNT="${TX_MIN_AMOUNT:-0.0001}"
TX_MAX_AMOUNT="${TX_MAX_AMOUNT:-0.01}"
TX_MIN_FEE_RATE="${TX_MIN_FEE_RATE:-1}"
TX_MAX_FEE_RATE="${TX_MAX_FEE_RATE:-20}"

# Saldo mínimo (BTC) pra tentar enviar tx nesse ciclo; abaixo disso só minera bloco vazio.
TX_MIN_BALANCE="${TX_MIN_BALANCE:-0.01}"

cli() {
    bitcoin-cli -regtest -conf="$CONF" "$@"
}

wcli() {
    bitcoin-cli -regtest -conf="$CONF" -rpcwallet="$WALLET_NAME" "$@"
}

random_amount() {
    awk -v min="$TX_MIN_AMOUNT" -v max="$TX_MAX_AMOUNT" -v seed="$RANDOM$$" \
        'BEGIN { srand(seed); printf "%.8f", min + rand() * (max - min) }'
}

random_fee_rate() {
    echo $(( (RANDOM % (TX_MAX_FEE_RATE - TX_MIN_FEE_RATE + 1)) + TX_MIN_FEE_RATE ))
}

echo "start mining..."

while true; do
    isLoaded=$(cli listwallets | jq -e --arg w "$WALLET_NAME" 'index($w) != null' 2>/dev/null || echo false)

    if [ "$isLoaded" = "true" ]; then
        balance=$(wcli getbalance)

        if awk -v b="$balance" -v min="$TX_MIN_BALANCE" 'BEGIN { exit !(b >= min) }'; then
            address=$(wcli getnewaddress)
            amount=$(random_amount)
            feeRate=$(random_fee_rate)

            if wcli -named sendtoaddress address="$address" amount="$amount" fee_rate="$feeRate" >/dev/null 2>&1; then
                echo "sent ${amount} BTC to ${address} (fee_rate=${feeRate} sat/vB)"
            else
                echo "tx send failed this round, mining an empty block instead"
            fi
        else
            echo "balance (${balance} BTC) below TX_MIN_BALANCE, mining an empty block"
        fi

        wcli -generate 1
    else
        echo "wallet '$WALLET_NAME' not loaded yet, skipping this round..."
    fi

    sleep "$MINING_INTERVAL"
done
