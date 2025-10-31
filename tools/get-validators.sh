#!/bin/bash
# Get current list of validators

set -e

RPC_ENDPOINT=${RPC_ENDPOINT:-http://localhost:8545}

echo "=== Current Validators ==="
echo ""
echo "RPC endpoint: $RPC_ENDPOINT"
echo ""

# Get current validators
RESPONSE=$(curl -s -X POST "$RPC_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "method":"qbft_getValidatorsByBlockNumber",
    "params":["latest"],
    "id":1
  }')

echo "$RESPONSE" | jq '.'
echo ""

# Parse and display in friendly format
if echo "$RESPONSE" | grep -q '"result"'; then
    VALIDATORS=$(echo "$RESPONSE" | jq -r '.result[]')
    COUNT=$(echo "$VALIDATORS" | wc -l | tr -d ' ')

    echo "Active validators: $COUNT"
    echo ""
    echo "$VALIDATORS" | nl
else
    echo "Error retrieving validators."
fi
