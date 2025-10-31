#!/bin/bash
# Besu Network Health Check Script

RPC_URL="${1:-http://localhost:8545}"

echo "==================================="
echo "Besu Network Health Check"
echo "==================================="
echo "RPC Endpoint: $RPC_URL"
echo ""

# Check if RPC is accessible
if ! curl -s --max-time 5 "$RPC_URL" > /dev/null 2>&1; then
    echo "ERROR: Cannot connect to RPC endpoint"
    exit 1
fi

# Get block number
BLOCK_NUM=$(curl -s -X POST "$RPC_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -z "$BLOCK_NUM" ]; then
    echo "ERROR: Could not retrieve block number"
    exit 1
fi

BLOCK_DEC=$((BLOCK_NUM))
echo "Block Number: $BLOCK_DEC ($BLOCK_NUM)"

# Check if blocks are being produced
sleep 5
BLOCK_NUM_NEW=$(curl -s -X POST "$RPC_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

BLOCK_DEC_NEW=$((BLOCK_NUM_NEW))

if [ "$BLOCK_DEC_NEW" -gt "$BLOCK_DEC" ]; then
    echo "Block Production: OK (new blocks being produced)"
else
    echo "Block Production: WARNING (no new blocks in 5 seconds)"
fi

# Get peer count
PEER_COUNT=$(curl -s -X POST "$RPC_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

PEER_DEC=$((PEER_COUNT))
echo "Connected Peers: $PEER_DEC"

if [ "$PEER_DEC" -lt 2 ]; then
    echo "WARNING: Low peer count (expected 3 for 4-validator network)"
fi

# Check sync status
SYNCING=$(curl -s -X POST "$RPC_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  | grep -o '"result":[^,}]*' | cut -d':' -f2)

if [ "$SYNCING" = "false" ]; then
    echo "Sync Status: Fully synced"
else
    echo "Sync Status: Syncing..."
fi

# Get chain ID
CHAIN_ID=$(curl -s -X POST "$RPC_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

CHAIN_DEC=$((CHAIN_ID))
echo "Chain ID: $CHAIN_DEC"

if [ "$CHAIN_DEC" -ne 10001 ]; then
    echo "WARNING: Unexpected chain ID (expected 10001)"
fi

echo ""
echo "==================================="
echo "Health Check Complete"
echo "==================================="
