#!/bin/bash

echo "Generating validator keys..."

for i in {0..3}; do
  echo "Generating keys for node$i..."
  besu --data-path=besu-network/node$i public-key export --to=besu-network/node$i/public-key
  besu --data-path=besu-network/node$i public-key export-address --to=besu-network/node$i/address
done

echo ""
echo "Validator addresses:"
for i in {0..3}; do
  echo "Node $i: $(cat besu-network/node$i/address)"
done
