#!/bin/bash
# Besu QBFT Network Setup Script
# Generates validator keys and genesis file for a 4-node QBFT network

set -e

echo "=== Besu QBFT Network Setup ==="
echo ""

# Check if Besu is installed
if ! command -v besu &> /dev/null; then
    echo "Besu not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew tap hyperledger/besu
        brew install hyperledger/besu/besu
    else
        echo "Homebrew not found. Please install Besu manually:"
        echo "  https://besu.hyperledger.org/stable/public-networks/get-started/install/binary-distribution"
        exit 1
    fi
fi

echo "Besu found: $(besu --version | head -n 1)"
echo ""

# Generate network files
echo "Generating validator keys and genesis file..."
besu operator generate-blockchain-config \
  --config-file=local/config/besu-config.json \
  --to=besu-network \
  --private-key-file-name=key

echo "Network files generated in ./besu-network/"
echo ""

# Display validator addresses
echo "Validator addresses:"
for dir in besu-network/keys/*/; do
    addr=$(basename "$dir")
    echo "  $addr"
done
echo ""

echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Start network: ./local/scripts/start.sh"
echo "  2. Verify setup: ./local/scripts/verify.sh"
echo ""
echo "IMPORTANT: The besu-network/ directory contains private keys."
echo "Never commit this directory to version control."
