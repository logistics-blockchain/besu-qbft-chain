#!/usr/bin/env tsx
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { join } from 'path';
import { encodeAbiParameters, parseAbiParameters, toRlp, concat, toHex } from 'viem';

const rootDir = join(__dirname, '..');

console.log('Generating genesis.json...');

// Check prerequisites
const templateFile = join(rootDir, 'genesis.template.json');
const contractFile = join(rootDir, 'artifacts', 'DynamicMultiSigValidatorManager.json');
const storageFile = join(rootDir, 'artifacts', 'storage-slots.json');
const addressesFile = join(rootDir, 'keys', 'validator-addresses.json');

if (!existsSync(templateFile)) {
  console.error('Error: genesis.template.json not found');
  process.exit(1);
}

if (!existsSync(contractFile)) {
  console.error('Error: Contract artifact not found. Run npm run contracts:compile first.');
  process.exit(1);
}

if (!existsSync(storageFile)) {
  console.error('Error: Storage slots not found. Run npm run storage:calculate first.');
  process.exit(1);
}

if (!existsSync(addressesFile)) {
  console.error('Error: Validator addresses not found. Run npm run storage:calculate first.');
  process.exit(1);
}

// Load files
const template = JSON.parse(readFileSync(templateFile, 'utf-8'));
const contract = JSON.parse(readFileSync(contractFile, 'utf-8'));
const storage = JSON.parse(readFileSync(storageFile, 'utf-8'));
const addresses = JSON.parse(readFileSync(addressesFile, 'utf-8'));

console.log('Loaded all required files');

// Extract deployed bytecode (not creation bytecode with constructor)
const bytecode = contract.deployedBytecode;
console.log(`Contract deployed bytecode length: ${bytecode.length} characters`);

// Get validator addresses dynamically
// Addresses file contains all nodes, we need to filter for validators only
// Must match "validator" but NOT "rpc"
const validators = Object.entries(addresses)
  .filter(([name, _]) => {
    const lower = name.toLowerCase();
    return lower.includes('validator') && !lower.includes('rpc');
  })
  .map(([_, address]) => address);

if (validators.length === 0) {
  console.error('Error: No validators found in addresses file');
  process.exit(1);
}

console.log(`Validators (${validators.length}): ${validators.join(', ')}`);

// Generate extraData for QBFT
// QBFT extraData format: RLP([vanityData, [validators], [], round, []])
const vanityData = '0x0000000000000000000000000000000000000000000000000000000000000000' as `0x${string}`;
const validatorList = validators.map(v => v as `0x${string}`);
const vote: `0x${string}`[] = []; // Empty list for vote
const round = '0x' as `0x${string}`; // Round 0 as empty bytes
const seals: `0x${string}`[] = []; // Empty list for seals

// Create the complete QBFT extra data structure
const qbftExtraData = [
  vanityData,
  validatorList,
  vote,
  round,
  seals
];

// RLP encode the entire structure
const extraData = toRlp(qbftExtraData);

console.log(`Generated extraData (${extraData.length} chars): ${extraData.slice(0, 66)}...`);

// Update genesis template
template.alloc['0x0000000000000000000000000000000000009999'].code = bytecode;
template.alloc['0x0000000000000000000000000000000000009999'].storage = storage;
template.extraData = extraData;

// Save genesis file
const genesisFile = join(rootDir, 'artifacts', 'genesis.json');
writeFileSync(genesisFile, JSON.stringify(template, null, 2));

console.log(`\nGenesis file generated successfully: ${genesisFile}`);
console.log('\nGenesis summary:');
console.log(`  Chain ID: ${template.config.chainId}`);
console.log(`  Block time: ${template.config.qbft.blockperiodseconds}s`);
console.log(`  Validator contract: ${template.config.qbft.validatorcontractaddress}`);
console.log(`  Initial validators: ${validators.length}`);
console.log(`  Storage slots: ${Object.keys(storage).length}`);
console.log('\nReady for deployment!');
