#!/bin/bash

echo "Stopping Besu network..."

pkill -f "besu.*node0"
pkill -f "besu.*node1"
pkill -f "besu.*node2"
pkill -f "besu.*node3"

sleep 2

echo "Network stopped."
echo ""
echo "To clean up data (WARNING: This will delete all blockchain data):"
echo "  rm -rf besu-network/node{0,1,2,3}/database"
