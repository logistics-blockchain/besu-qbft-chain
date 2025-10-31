#!/bin/bash
# Start 4-node QBFT network with zero gas prices

set -e

# Check if network files exist
if [ ! -f "besu-network/genesis.json" ]; then
    echo "Genesis file not found. Run ./local/scripts/setup.sh first"
    exit 1
fi

echo "Starting 4-node QBFT network..."
echo ""
echo "Network details:"
echo "  Chain ID: 10001"
echo "  Consensus: QBFT (4 validators)"
echo "  RPC: http://localhost:8545 (node 0)"
echo "  Gas Price: 0 (free transactions)"
echo ""

# Get validator addresses
VALIDATORS=($(ls besu-network/keys/))

echo "Validators:"
for i in "${!VALIDATORS[@]}"; do
    echo "  Node $i: ${VALIDATORS[$i]}"
done
echo ""

# Create data directories
mkdir -p besu-data/node{0,1,2,3}

echo "Starting validator nodes..."
echo ""

# Start node 0 (RPC node)
echo "Starting Node 0 (RPC + Validator)..."
besu --genesis-file=besu-network/genesis.json \
  --data-path=besu-data/node0 \
  --node-private-key-file=besu-network/keys/${VALIDATORS[0]}/key \
  --rpc-http-enabled \
  --rpc-http-api=ETH,NET,QBFT,ADMIN,DEBUG,TXPOOL,WEB3 \
  --rpc-http-host=0.0.0.0 \
  --rpc-http-port=8545 \
  --rpc-http-cors-origins="*" \
  --host-allowlist="*" \
  --rpc-ws-enabled \
  --rpc-ws-host=0.0.0.0 \
  --rpc-ws-port=8546 \
  --rpc-ws-api=ETH,NET,QBFT,ADMIN,DEBUG,TXPOOL,WEB3 \
  --p2p-host=127.0.0.1 \
  --p2p-port=30303 \
  --min-gas-price=0 \
  --miner-enabled \
  --miner-coinbase=${VALIDATORS[0]} \
  > besu-data/node0.log 2>&1 &
NODE0_PID=$!
echo "  Node 0 PID: $NODE0_PID"

sleep 5

# Get bootnode enode
BOOTNODE_ENODE=""
for i in {1..10}; do
  BOOTNODE_ENODE=$(grep "Enode URL" besu-data/node0.log | grep -o 'enode://[^[:space:]]*' | head -1)
  if [ -n "$BOOTNODE_ENODE" ]; then
    break
  fi
  echo "  Waiting for bootnode enode..."
  sleep 1
done

if [ -z "$BOOTNODE_ENODE" ]; then
  echo "  ERROR: Could not extract bootnode enode"
  cat besu-data/node0.log
  exit 1
fi

echo "  Bootnode: $BOOTNODE_ENODE"
echo ""

# Start node 1
echo "Starting Node 1 (Validator)..."
besu --genesis-file=besu-network/genesis.json \
  --data-path=besu-data/node1 \
  --node-private-key-file=besu-network/keys/${VALIDATORS[1]}/key \
  --p2p-host=127.0.0.1 \
  --p2p-port=30304 \
  --rpc-http-enabled \
  --rpc-http-api=ETH,NET,QBFT \
  --rpc-http-host=0.0.0.0 \
  --rpc-http-port=8547 \
  --host-allowlist="*" \
  --min-gas-price=0 \
  --miner-enabled \
  --miner-coinbase=${VALIDATORS[1]} \
  --bootnodes=$BOOTNODE_ENODE \
  > besu-data/node1.log 2>&1 &
NODE1_PID=$!
echo "  Node 1 PID: $NODE1_PID"

# Start node 2
echo "Starting Node 2 (Validator)..."
besu --genesis-file=besu-network/genesis.json \
  --data-path=besu-data/node2 \
  --node-private-key-file=besu-network/keys/${VALIDATORS[2]}/key \
  --p2p-host=127.0.0.1 \
  --p2p-port=30305 \
  --rpc-http-enabled \
  --rpc-http-api=ETH,NET,QBFT \
  --rpc-http-host=0.0.0.0 \
  --rpc-http-port=8548 \
  --host-allowlist="*" \
  --min-gas-price=0 \
  --miner-enabled \
  --miner-coinbase=${VALIDATORS[2]} \
  --bootnodes=$BOOTNODE_ENODE \
  > besu-data/node2.log 2>&1 &
NODE2_PID=$!
echo "  Node 2 PID: $NODE2_PID"

# Start node 3
echo "Starting Node 3 (Validator)..."
besu --genesis-file=besu-network/genesis.json \
  --data-path=besu-data/node3 \
  --node-private-key-file=besu-network/keys/${VALIDATORS[3]}/key \
  --p2p-host=127.0.0.1 \
  --p2p-port=30306 \
  --rpc-http-enabled \
  --rpc-http-api=ETH,NET,QBFT \
  --rpc-http-host=0.0.0.0 \
  --rpc-http-port=8549 \
  --host-allowlist="*" \
  --min-gas-price=0 \
  --miner-enabled \
  --miner-coinbase=${VALIDATORS[3]} \
  --bootnodes=$BOOTNODE_ENODE \
  > besu-data/node3.log 2>&1 &
NODE3_PID=$!
echo "  Node 3 PID: $NODE3_PID"

echo ""
echo "Network started successfully!"
echo ""

# Save PIDs
echo "$NODE0_PID" > besu-data/pids.txt
echo "$NODE1_PID" >> besu-data/pids.txt
echo "$NODE2_PID" >> besu-data/pids.txt
echo "$NODE3_PID" >> besu-data/pids.txt
echo "Node PIDs saved to: besu-data/pids.txt"

echo ""
echo "RPC Endpoints:"
echo "  Node 0: http://localhost:8545 (main RPC)"
echo "  Node 1: http://localhost:8547"
echo "  Node 2: http://localhost:8548"
echo "  Node 3: http://localhost:8549"
echo ""
echo "WebSocket:"
echo "  Node 0: ws://localhost:8546"
echo ""
echo "Logs:"
echo "  tail -f besu-data/node0.log"
echo "  tail -f besu-data/node1.log"
echo "  tail -f besu-data/node2.log"
echo "  tail -f besu-data/node3.log"
echo ""
echo "To stop all nodes:"
echo "  ./local/scripts/stop.sh"
echo ""
echo "Waiting for network to reach consensus..."
sleep 5

# Check if blocks are being produced
BLOCK_NUMBER=$(curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -n "$BLOCK_NUMBER" ] && [ "$BLOCK_NUMBER" != "0x0" ]; then
    echo "Network is producing blocks: $BLOCK_NUMBER"
else
    echo "Network starting... Check logs if blocks don't appear soon."
fi

echo ""
echo "Ready to deploy contracts!"
