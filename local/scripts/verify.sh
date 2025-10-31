#!/bin/bash
# Verify Besu network configuration

echo "=== Besu Configuration Verification ==="
echo ""

# Check if genesis file exists
if [ ! -f "besu-network/genesis.json" ]; then
    echo "Genesis file not found. Run ./local/scripts/setup.sh first"
    exit 1
fi
echo "Genesis file exists"

# Check validator keys
VALIDATOR_COUNT=$(ls -d besu-network/keys/*/ 2>/dev/null | wc -l)
echo "Found $VALIDATOR_COUNT validator keys"

if [ "$VALIDATOR_COUNT" -ne 4 ]; then
    echo "WARNING: Expected 4 validators, found $VALIDATOR_COUNT"
fi

echo ""
echo "Genesis Configuration:"
if command -v jq &> /dev/null; then
    echo "  Chain ID: $(cat besu-network/genesis.json | jq -r '.config.chainId')"
    echo "  Berlin Block: $(cat besu-network/genesis.json | jq -r '.config.berlinBlock')"
    echo "  London Block: $(cat besu-network/genesis.json | jq -r '.config.londonBlock')"
    echo "  Shanghai Time: $(cat besu-network/genesis.json | jq -r '.config.shanghaiTime')"
    echo "  Cancun Time: $(cat besu-network/genesis.json | jq -r '.config.cancunTime')"
    echo "  Zero Base Fee: $(cat besu-network/genesis.json | jq -r '.config.zeroBaseFee')"
    echo "  Block Period: $(cat besu-network/genesis.json | jq -r '.config.qbft.blockperiodseconds')s"
    echo ""

    echo "Pre-funded accounts:"
    cat besu-network/genesis.json | jq -r '.alloc | keys[]' | while read addr; do
        echo "  0x$addr"
    done
else
    echo "  (install jq for detailed info)"
fi

echo ""
echo "Verification complete!"
echo ""
echo "To start the network: ./local/scripts/start.sh"
