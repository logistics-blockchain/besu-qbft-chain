#!/bin/bash

echo "Starting 4-node Besu QBFT network with contract-based validator management..."

NODE0_PUBKEY=$(cat besu-network/node0/public-key | sed 's/0x//')
NODE0_ENODE="enode://${NODE0_PUBKEY}@127.0.0.1:30303"

echo "Node 0 enode: $NODE0_ENODE"

echo ""
echo "Starting Node 0 (bootnode)..."
besu --data-path=besu-network/node0 \
  --genesis-file=besu-network/genesis.json \
  --rpc-http-enabled \
  --rpc-http-api=ETH,NET,QBFT,ADMIN \
  --rpc-http-host=0.0.0.0 \
  --rpc-http-port=8545 \
  --rpc-http-cors-origins="*" \
  --host-allowlist="*" \
  --p2p-host=127.0.0.1 \
  --p2p-port=30303 \
  --min-gas-price=0 \
  --miner-enabled \
  --miner-coinbase=0xf176465f83bfa22f1057e4353b5a100a1c198507 \
  > besu-network/node0.log 2>&1 &

echo "Node 0 PID: $!"

sleep 5

echo ""
echo "Starting Node 1..."
besu --data-path=besu-network/node1 \
  --genesis-file=besu-network/genesis.json \
  --rpc-http-enabled \
  --rpc-http-api=ETH,NET,QBFT \
  --rpc-http-host=0.0.0.0 \
  --rpc-http-port=8546 \
  --rpc-http-cors-origins="*" \
  --host-allowlist="*" \
  --p2p-host=127.0.0.1 \
  --p2p-port=30304 \
  --bootnodes=$NODE0_ENODE \
  --min-gas-price=0 \
  --miner-enabled \
  --miner-coinbase=0xef832eca2439987697d43917f9d3d0dd1e9410b7 \
  > besu-network/node1.log 2>&1 &

echo "Node 1 PID: $!"

sleep 2

echo ""
echo "Starting Node 2..."
besu --data-path=besu-network/node2 \
  --genesis-file=besu-network/genesis.json \
  --rpc-http-enabled \
  --rpc-http-api=ETH,NET,QBFT \
  --rpc-http-host=0.0.0.0 \
  --rpc-http-port=8547 \
  --rpc-http-cors-origins="*" \
  --host-allowlist="*" \
  --p2p-host=127.0.0.1 \
  --p2p-port=30305 \
  --bootnodes=$NODE0_ENODE \
  --min-gas-price=0 \
  --miner-enabled \
  --miner-coinbase=0x97d2a16f323947b757a4de762e460e6bbace1adc \
  > besu-network/node2.log 2>&1 &

echo "Node 2 PID: $!"

sleep 2

echo ""
echo "Starting Node 3..."
besu --data-path=besu-network/node3 \
  --genesis-file=besu-network/genesis.json \
  --rpc-http-enabled \
  --rpc-http-api=ETH,NET,QBFT \
  --rpc-http-host=0.0.0.0 \
  --rpc-http-port=8548 \
  --rpc-http-cors-origins="*" \
  --host-allowlist="*" \
  --p2p-host=127.0.0.1 \
  --p2p-port=30306 \
  --bootnodes=$NODE0_ENODE \
  --min-gas-price=0 \
  --miner-enabled \
  --miner-coinbase=0x82085d3051fc8c0c90c7908c92382072c8681b2c \
  > besu-network/node3.log 2>&1 &

echo "Node 3 PID: $!"

sleep 3

echo ""
echo "Network started successfully!"
echo ""
echo "RPC Endpoints:"
echo "  Node 0: http://localhost:8545"
echo "  Node 1: http://localhost:8546"
echo "  Node 2: http://localhost:8547"
echo "  Node 3: http://localhost:8548"
echo ""
echo "View logs:"
echo "  tail -f besu-network/node0.log"
echo ""
echo "Check network status:"
echo "  curl -X POST http://localhost:8545 -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}'"
