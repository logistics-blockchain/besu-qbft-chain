#!/bin/bash
# Vote to add a new validator to the QBFT network

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <validator-address>"
    echo ""
    echo "Example:"
    echo "  $0 0x1234567890abcdef1234567890abcdef12345678"
    exit 1
fi

VALIDATOR_ADDRESS=$1
RPC_ENDPOINT=${RPC_ENDPOINT:-http://localhost:8545}

echo "=== Vote to Add Validator ==="
echo ""
echo "Validator address: $VALIDATOR_ADDRESS"
echo "RPC endpoint: $RPC_ENDPOINT"
echo ""

# Propose to add validator
RESPONSE=$(curl -s -X POST "$RPC_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "{
    \"jsonrpc\":\"2.0\",
    \"method\":\"qbft_proposeValidatorVote\",
    \"params\":[\"$VALIDATOR_ADDRESS\", true],
    \"id\":1
  }")

echo "Response: $RESPONSE"
echo ""

# Check if successful
if echo "$RESPONSE" | grep -q '"result":true'; then
    echo "✓ Vote submitted successfully!"
    echo ""
    echo "The proposal will be included in blocks produced by this validator."
    echo "Once >50% of validators have voted, the new validator will be added."
    echo ""
    echo "Check pending votes: ./tools/check-pending-votes.sh"
else
    echo "✗ Vote failed. Check the response above for errors."
    exit 1
fi
