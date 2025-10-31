#!/bin/bash
# Check pending validator votes

set -e

RPC_ENDPOINT=${RPC_ENDPOINT:-http://localhost:8545}

echo "=== Pending Validator Votes ==="
echo ""
echo "RPC endpoint: $RPC_ENDPOINT"
echo ""

# Get pending votes
RESPONSE=$(curl -s -X POST "$RPC_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "method":"qbft_getPendingVotes",
    "params":[],
    "id":1
  }')

echo "$RESPONSE" | jq '.'
echo ""

# Parse and display in friendly format
if echo "$RESPONSE" | grep -q '"result"'; then
    VOTES=$(echo "$RESPONSE" | jq -r '.result')

    if [ "$VOTES" = "{}" ]; then
        echo "No pending votes."
    else
        echo "Pending votes:"
        echo "$VOTES" | jq -r 'to_entries[] | "  \(.key): \(if .value then "ADD" else "REMOVE" end)"'
    fi
else
    echo "Error retrieving pending votes."
fi
