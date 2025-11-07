#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "Verifying BesuChain network..."

# Read nodes configuration
if [ -f "nodes.json" ]; then
  NODES_CONFIG="nodes.json"
else
  NODES_CONFIG=".nodes.default.json"
  cat > "$NODES_CONFIG" <<'EOF'
{
  "nodes": {
    "validator1": {"type": "validator", "location": "local", "port": 8545},
    "validator2": {"type": "validator", "location": "local", "port": 8546},
    "validator3": {"type": "validator", "location": "local", "port": 8547},
    "non-validator1": {"type": "non-validator", "location": "local", "port": 8548}
  }
}
EOF
fi

NODE_NAMES=$(jq -r '.nodes | keys[]' "$NODES_CONFIG")

echo ""
echo "=== Peer Counts ==="

for NODE_NAME in $NODE_NAMES; do
  LOCATION=$(jq -r ".nodes[\"$NODE_NAME\"].location" "$NODES_CONFIG")

  if [ "$LOCATION" == "local" ]; then
    PORT=$(jq -r ".nodes[\"$NODE_NAME\"].port" "$NODES_CONFIG")
    RPC_URL="http://localhost:$PORT"
  else
    HOST=$(jq -r ".nodes[\"$NODE_NAME\"].host" "$NODES_CONFIG")
    RPC_URL="http://$HOST:8545"
  fi

  PEER_COUNT=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' "$RPC_URL" | jq -r '.result' || echo "error")

  if [ "$PEER_COUNT" != "error" ] && [ "$PEER_COUNT" != "null" ]; then
    PEER_COUNT_DEC=$((16#${PEER_COUNT#0x}))
    echo "  $NODE_NAME: $PEER_COUNT_DEC peers"
  else
    echo "  $NODE_NAME: Unable to query"
  fi
done

echo ""
echo "=== Block Numbers ==="

for NODE_NAME in $NODE_NAMES; do
  LOCATION=$(jq -r ".nodes[\"$NODE_NAME\"].location" "$NODES_CONFIG")

  if [ "$LOCATION" == "local" ]; then
    PORT=$(jq -r ".nodes[\"$NODE_NAME\"].port" "$NODES_CONFIG")
    RPC_URL="http://localhost:$PORT"
  else
    HOST=$(jq -r ".nodes[\"$NODE_NAME\"].host" "$NODES_CONFIG")
    RPC_URL="http://$HOST:8545"
  fi

  BLOCK_NUM=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' "$RPC_URL" | jq -r '.result' || echo "error")

  if [ "$BLOCK_NUM" != "error" ] && [ "$BLOCK_NUM" != "null" ]; then
    BLOCK_NUM_DEC=$((16#${BLOCK_NUM#0x}))
    echo "  $NODE_NAME: Block #$BLOCK_NUM_DEC"
  else
    echo "  $NODE_NAME: Unable to query"
  fi
done

echo ""
echo "=== Network Health ==="

# Get first available RPC endpoint
FIRST_RPC=""
for NODE_NAME in $NODE_NAMES; do
  LOCATION=$(jq -r ".nodes[\"$NODE_NAME\"].location" "$NODES_CONFIG")

  if [ "$LOCATION" == "local" ]; then
    PORT=$(jq -r ".nodes[\"$NODE_NAME\"].port" "$NODES_CONFIG")
    FIRST_RPC="http://localhost:$PORT"
    break
  else
    HOST=$(jq -r ".nodes[\"$NODE_NAME\"].host" "$NODES_CONFIG")
    FIRST_RPC="http://$HOST:8545"
    break
  fi
done

if [ -n "$FIRST_RPC" ]; then
  BLOCK1=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' "$FIRST_RPC" | jq -r '.result' || echo "0x0")
  BLOCK1_DEC=$((16#${BLOCK1#0x}))

  echo "Waiting 10 seconds to check block production..."
  sleep 10

  BLOCK2=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' "$FIRST_RPC" | jq -r '.result' || echo "0x0")
  BLOCK2_DEC=$((16#${BLOCK2#0x}))

  BLOCKS_PRODUCED=$((BLOCK2_DEC - BLOCK1_DEC))

  if [ $BLOCKS_PRODUCED -gt 0 ]; then
    echo "  ✓ Block production working: $BLOCKS_PRODUCED blocks in 10 seconds"
  else
    echo "  ✗ No blocks produced in 10 seconds"
    echo "    Check that you have configured peers (npm run peers)"
  fi
fi

# Cleanup
if [ -f ".nodes.default.json" ]; then
  rm ".nodes.default.json"
fi

echo ""
echo "Network verification complete!"
