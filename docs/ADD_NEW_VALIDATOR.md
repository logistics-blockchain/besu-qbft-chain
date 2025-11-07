# Adding a New Validator to Existing Blockchain

Guide for adding a validator node to a running blockchain network.

## Prerequisites

- Genesis file from existing network (must match exactly)
- Access to existing network admin account
- Target server meeting hardware requirements (4GB RAM, 50GB storage)

## Step 1: Get Genesis File

Retrieve the genesis file from any existing node:

```bash
# From remote node
scp ubuntu@EXISTING_NODE_IP:/opt/besu/genesis.json ./genesis.json

# Or from local deployment
cp /path/to/besuchain/artifacts/genesis.json ./genesis.json
```

## Step 2: Generate Node Key

```bash
openssl rand -hex 32 > node-new.key
```

Derive the validator address (needed for contract approval):

```bash
# Install viem if not available: npm install -g viem
node -e "
const {privateKeyToAccount} = require('viem/accounts');
const fs = require('fs');
const key = '0x' + fs.readFileSync('node-new.key', 'utf-8').trim();
const account = privateKeyToAccount(key);
console.log('Validator Address:', account.address);
"
```

Save the address - you'll need it for contract approval.

## Step 3: Deploy Node

**Create deployment directory:**

```bash
sudo mkdir -p /opt/besu
sudo chown $USER:$USER /opt/besu
cd /opt/besu
```

**Copy files:**

```bash
# Copy genesis and node key
cp /path/to/genesis.json /opt/besu/
cp /path/to/node-new.key /opt/besu/node.key
```

**Create docker-compose.yml:**

```yaml
services:
  besu-node:
    image: hyperledger/besu:latest
    container_name: besu-validator
    ports:
      - "8545:8545"
      - "30303:30303"
    volumes:
      - ./genesis.json:/config/genesis.json:ro
      - ./node.key:/config/node.key:ro
      - besu-data:/data
    environment:
      - JAVA_OPTS=-Xmx512m -Xms256m
    command: |
      --genesis-file=/config/genesis.json
      --node-private-key-file=/config/node.key
      --data-path=/data
      --rpc-http-enabled=true
      --rpc-http-host=0.0.0.0
      --rpc-http-port=8545
      --rpc-http-cors-origins="*"
      --rpc-http-api=ETH,NET,WEB3,QBFT
      --host-allowlist="*"
      --p2p-enabled=true
      --p2p-host=0.0.0.0
      --p2p-port=30303
      --min-gas-price=0
    restart: unless-stopped

volumes:
  besu-data:
```

**Start node:**

```bash
docker-compose up -d
```

## Step 4: Configure Peer Discovery

**Get new node's enode:**

```bash
docker logs besu-validator 2>&1 | grep "enode://" | head -1
```

Extract the public key and create the enode URL:
```
enode://PUBLIC_KEY@NEW_NODE_IP:30303
```

**Add existing network peers to new node:**

Get enodes from existing nodes, then create static-nodes.json:

```bash
cat > static-nodes.json <<EOF
[
  "enode://EXISTING_NODE1_PUBKEY@IP1:30303",
  "enode://EXISTING_NODE2_PUBKEY@IP2:30303",
  "enode://EXISTING_NODE3_PUBKEY@IP3:30303"
]
EOF

docker cp static-nodes.json besu-validator:/data/
docker-compose restart
```

**Add new node to existing network:**

On each existing node, add the new node's enode to their static-nodes.json and restart.

## Step 5: Verify Synchronization

Wait 15-20 seconds for peer discovery, then check:

```bash
# Check peer count (should equal number of existing nodes)
curl -X POST --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' http://localhost:8545

# Check block number (should match network)
curl -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545
```

The node is now synced but **not yet a validator**.

## Step 6: Approve as Validator

The new validator must be approved through the validator contract governance process.

**Apply to be validator (from new validator address):**

Using cast or web interface, call on validator contract at `0x0000000000000000000000000000000000009999`:

```bash
cast send 0x0000000000000000000000000000000000009999 \
  "applyToBeValidator(string,string)" \
  "Organization Name" \
  "contact@email.com" \
  --private-key NEW_NODE_PRIVATE_KEY \
  --rpc-url http://localhost:8545 \
  --gas-price 0
```

**Admin proposes approval:**

An existing admin must propose the validator for approval:

```bash
cast send 0x0000000000000000000000000000000000009999 \
  "proposeApproval(address,string)" \
  NEW_VALIDATOR_ADDRESS \
  "Approval reason" \
  --private-key ADMIN_PRIVATE_KEY \
  --rpc-url http://EXISTING_NODE:8545 \
  --gas-price 0
```

**Other admins sign the proposal:**

Get the proposal ID from the transaction receipt, then other admins sign:

```bash
cast send 0x0000000000000000000000000000000000009999 \
  "signValidatorProposal(uint256)" \
  PROPOSAL_ID \
  --private-key ADMIN_PRIVATE_KEY \
  --rpc-url http://EXISTING_NODE:8545 \
  --gas-price 0
```

**Automatic execution:**

When threshold is reached (majority of admins), the proposal executes automatically and the new validator is added to the validator set. Besu reads the updated validator list and includes the new node in consensus.

## Verification

Confirm the new validator is active:

```bash
cast call 0x0000000000000000000000000000000000009999 \
  "getValidators()" \
  --rpc-url http://localhost:8545
```

The new validator address should appear in the returned array.

## Troubleshooting

**Node stays at block 0:**
- Verify genesis hash matches: check logs for genesis hash, compare with existing nodes
- Check peer count is greater than 0

**Peer count is 0:**
- Verify enode URLs are reachable
- Check firewall allows port 30303
- Verify static-nodes.json format is valid JSON

**Not participating in consensus after approval:**
- Verify validator address matches node key address
- Check contract shows validator in approved list
- Restart node to ensure it reads updated validator set
- Check logs for QBFT consensus messages
