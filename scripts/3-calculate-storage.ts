#!/usr/bin/env tsx
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { join } from 'path';
import { keccak256, encodeAbiParameters, parseAbiParameters, toHex, pad } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';

const rootDir = join(__dirname, '..');
const keysDir = join(rootDir, 'keys');

console.log('Calculating storage slots and extracting addresses...');

// Read node configuration
interface NodeConfig {
  type: 'validator' | 'rpc';
  location: 'local' | 'remote';
  port?: number;
  host?: string;
  user?: string;
}

interface NodesConfig {
  nodes: Record<string, NodeConfig>;
}

let nodesConfig: NodesConfig;
const nodesConfigFile = join(rootDir, 'nodes.json');

if (existsSync(nodesConfigFile)) {
  nodesConfig = JSON.parse(readFileSync(nodesConfigFile, 'utf-8'));
  console.log(`Using nodes.json: ${Object.keys(nodesConfig.nodes).length} nodes configured`);
} else {
  // Default: 3 validators + 1 RPC node
  nodesConfig = {
    nodes: {
      validator1: { type: 'validator', location: 'local', port: 8545 },
      validator2: { type: 'validator', location: 'local', port: 8546 },
      validator3: { type: 'validator', location: 'local', port: 8547 },
      rpc1: { type: 'rpc', location: 'local', port: 8548 },
    },
  };
  console.log('No nodes.json found, using default: 3 validators + 1 RPC node');
}

const nodeNames = Object.keys(nodesConfig.nodes);
const addresses: Record<string, string> = {};

// Read node keys and derive addresses
for (let i = 0; i < nodeNames.length; i++) {
  const nodeName = nodeNames[i];
  const keyFile = join(keysDir, `node${i + 1}.key`);

  if (!existsSync(keyFile)) {
    console.error(`Error: ${keyFile} not found. Run npm run keys:generate first.`);
    process.exit(1);
  }

  const privateKey = `0x${readFileSync(keyFile, 'utf-8').trim()}`;
  const account = privateKeyToAccount(privateKey as `0x${string}`);
  addresses[nodeName] = account.address;

  console.log(`${nodeName}: ${account.address}`);
}

// Save addresses
const addressesFile = join(keysDir, 'validator-addresses.json');
writeFileSync(addressesFile, JSON.stringify(addresses, null, 2));
console.log(`\nAddresses saved to: ${addressesFile}`);

// Get validator addresses
const validators = nodeNames
  .filter(name => nodesConfig.nodes[name].type === 'validator')
  .map(name => addresses[name]);

if (validators.length === 0) {
  console.error('Error: No validators configured');
  process.exit(1);
}

// Calculate storage slots for contract initialization
const storage: Record<string, string> = {};

// Use first validator as initial admin
const initialAdmin = validators[0];

console.log('\nCalculating storage slots...');
console.log(`Initial admin: ${initialAdmin}`);
console.log(`Initial validators (${validators.length}): ${validators.join(', ')}`);

// Slot 0: admins.length = 1
storage['0x0000000000000000000000000000000000000000000000000000000000000000'] =
  '0x0000000000000000000000000000000000000000000000000000000000000001';

// Slot 2: validators.length = N
storage['0x0000000000000000000000000000000000000000000000000000000000000002'] =
  pad(toHex(validators.length), { size: 32 });

// Slot 1 mapping: isAdmin[initialAdmin] = true
const adminMappingSlot = keccak256(
  encodeAbiParameters(
    parseAbiParameters('address, uint256'),
    [initialAdmin as `0x${string}`, BigInt(1)]
  )
);
storage[adminMappingSlot] = '0x0000000000000000000000000000000000000000000000000000000000000001';

// Slot 3 mapping: isValidator[each validator] = true
validators.forEach((validator) => {
  const validatorMappingSlot = keccak256(
    encodeAbiParameters(
      parseAbiParameters('address, uint256'),
      [validator as `0x${string}`, BigInt(3)]
    )
  );
  storage[validatorMappingSlot] = '0x0000000000000000000000000000000000000000000000000000000000000001';
});

// Array storage: admins[0] = initialAdmin
const adminsArraySlot = keccak256(toHex(BigInt(0), { size: 32 }));
storage[adminsArraySlot] = pad(initialAdmin as `0x${string}`, { size: 32 });

// Array storage: validators[0], validators[1], ...
const validatorsArraySlot = BigInt(keccak256(toHex(BigInt(2), { size: 32 })));
validators.forEach((validator, index) => {
  const slot = toHex(validatorsArraySlot + BigInt(index), { size: 32 });
  storage[slot] = pad(validator as `0x${string}`, { size: 32 });
});

// Save storage slots
const storageFile = join(rootDir, 'artifacts', 'storage-slots.json');
writeFileSync(storageFile, JSON.stringify(storage, null, 2));
console.log(`\nStorage slots saved to: ${storageFile}`);
console.log(`Total slots: ${Object.keys(storage).length}`);
