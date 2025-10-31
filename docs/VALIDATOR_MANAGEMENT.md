# Validator Management

Guide for adding and removing validators from a running QBFT network.

## Overview

QBFT networks use block header voting to manage validators dynamically. Existing validators vote to add or remove validators without restarting the network.

### Requirements

- Network must be running with QBFT API enabled (already configured)
- Majority (>50%) of current validators must vote for changes
- Each validator can propose one vote per block they produce

## Adding a New Validator

### Step 1: Generate Validator Keys

Generate a new validator key pair:

```bash
./tools/generate-validator-key.sh
```

This creates a directory with:
- Private key file (`key`)
- Public address (`address.txt`)

**Important:** Keep the private key secure and never commit it to version control.

### Step 2: Vote to Add Validator

Each existing validator must vote to add the new validator. You need >50% of current validators to vote.

**From each validator node:**

```bash
./tools/vote-add-validator.sh 0xNEW_VALIDATOR_ADDRESS
```

**Vote from specific RPC endpoints:**

```bash
# Vote from validator at port 8545
RPC_ENDPOINT=http://localhost:8545 ./tools/vote-add-validator.sh 0xNEW_VALIDATOR_ADDRESS

# Vote from validator at port 8547
RPC_ENDPOINT=http://localhost:8547 ./tools/vote-add-validator.sh 0xNEW_VALIDATOR_ADDRESS
```

### Step 3: Check Pending Votes

Monitor the voting progress:

```bash
./tools/check-pending-votes.sh
```

### Step 4: Verify Addition

Once >50% have voted, check that the validator was added:

```bash
./tools/get-validators.sh
```

### Step 5: Start New Validator Node

After the validator is added to the validator set, start the node:

```bash
# Copy the generated validator directory to besu-network/keys/
cp -r new-validator-1234567890 besu-network/keys/0xNEW_VALIDATOR_ADDRESS

# Start the new validator using Besu
besu --data-path=besu-data/nodeN \
  --genesis-file=besu-network/genesis.json \
  --node-private-key-file=besu-network/keys/0xNEW_VALIDATOR_ADDRESS/key \
  --rpc-http-enabled \
  --rpc-http-api=ETH,NET,QBFT \
  --rpc-http-host=0.0.0.0 \
  --rpc-http-port=8550 \
  --p2p-host=127.0.0.1 \
  --p2p-port=30306 \
  --bootnodes=BOOTNODE_ENODE \
  --min-gas-price=0 \
  --miner-enabled \
  --miner-coinbase=0xNEW_VALIDATOR_ADDRESS
```

## Removing a Validator

### Step 1: Vote to Remove

Each validator votes to remove the target validator:

```bash
./tools/vote-remove-validator.sh 0xVALIDATOR_TO_REMOVE
```

### Step 2: Check Votes

```bash
./tools/check-pending-votes.sh
```

### Step 3: Verify Removal

```bash
./tools/get-validators.sh
```

### Step 4: Stop Removed Validator Node

Once removed from the validator set, stop the node:

```bash
# Find the process ID
ps aux | grep besu

# Stop the process
kill <PID>
```

## Voting Requirements

### Majority Threshold

Votes require >50% of **current** validators:

| Current Validators | Votes Needed |
|-------------------|--------------|
| 2 | 2 (both must vote) |
| 3 | 2 |
| 4 | 3 |
| 5 | 3 |
| 6 | 4 |
| 7 | 4 |

### Vote Lifecycle

1. **Proposed**: Validator calls `qbft_proposeValidatorVote`
2. **Pending**: Proposal included in blocks produced by that validator
3. **Executed**: Once >50% vote, change takes effect
4. **Cleared**: At epoch boundary (30,000 blocks), pending votes are discarded

## Troubleshooting

### Vote Not Passing

**Problem**: Submitted votes but validator not added

**Solutions**:
- Verify >50% of validators have voted
- Check pending votes: `./tools/check-pending-votes.sh`
- Ensure validators are producing blocks (need to include votes in blocks)
- Wait for epoch if votes were discarded

### Cannot Connect to Validator

**Problem**: Vote script fails with connection error

**Solutions**:
- Verify network is running: `./tools/health-check.sh`
- Check RPC endpoint is correct
- Ensure QBFT API is enabled on the node

### New Validator Not Producing Blocks

**Problem**: Validator added but not participating in consensus

**Solutions**:
- Verify node is connected to network (check peer count)
- Ensure node is using correct genesis file
- Check node has correct private key
- Verify bootnode enode is correct

## API Reference

### Propose Validator Vote

```bash
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "method":"qbft_proposeValidatorVote",
    "params":["0xVALIDATOR_ADDRESS", true],
    "id":1
  }'
```

Parameters:
- `validatorAddress`: Address of validator to add/remove
- `add`: `true` to add, `false` to remove

### Get Pending Votes

```bash
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "method":"qbft_getPendingVotes",
    "params":[],
    "id":1
  }'
```

### Discard Validator Vote

```bash
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "method":"qbft_discardValidatorVote",
    "params":["0xVALIDATOR_ADDRESS"],
    "id":1
  }'
```

### Get Validators at Block

```bash
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "method":"qbft_getValidatorsByBlockNumber",
    "params":["latest"],
    "id":1
  }'
```

## Best Practices

### Before Adding Validators

1. Generate and securely store validator keys
2. Coordinate with existing validators
3. Prepare node infrastructure
4. Test connectivity to network

### During Voting

1. Vote from multiple validators simultaneously
2. Monitor pending votes
3. Verify vote execution
4. Check validator set after change

### After Adding Validators

1. Verify new validator is producing blocks
2. Monitor network health
3. Update documentation of validator set
4. Backup validator keys securely

## Security Considerations

### Private Keys

- Never commit validator private keys to version control
- Store keys in secure, encrypted storage
- Use hardware security modules in production
- Implement key rotation procedures

### Voting Coordination

- Establish off-chain communication for validators
- Document voting procedures
- Implement approval processes for validator changes
- Monitor for unauthorized voting attempts

### Network Stability

- Maintain at least 4 validators for Byzantine fault tolerance
- Add validators gradually
- Test validator addition on testnet first
- Keep validator count odd to avoid split votes
