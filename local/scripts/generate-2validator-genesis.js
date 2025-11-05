const { ethers } = require('ethers');
const fs = require('fs');

const CONTRACT_ADDRESS = '0x0000000000000000000000000000000000009999';

const DEPLOYED_BYTECODE = fs.readFileSync('deployedBytecode.txt', 'utf8').trim();

// Cloud deployment validators (Node 0 and Node 1)
const validatorAddresses = [
  '0xf176465f83bfa22f1057e4353b5a100a1c198507',  // Node 0
  '0xef832eca2439987697d43917f9d3d0dd1e9410b7'   // Node 1
];

const adminAddress = validatorAddresses[0];

console.log('Generating 2-validator genesis file for cloud deployment...');
console.log('Admin:', adminAddress);
console.log('Validators:', validatorAddresses);

const storage = {};

// Admin count = 1 (slot 0)
storage['0x0'] = ethers.toBeHex(1, 32);

// Admin array (slot 0 array storage)
const adminsArraySlot = ethers.keccak256(ethers.toBeHex(0, 32));
storage[adminsArraySlot] = ethers.zeroPadValue(adminAddress, 32);

// isAdmin mapping (slot 1)
const isAdminMapKey = ethers.keccak256(
  ethers.concat([
    ethers.zeroPadValue(adminAddress, 32),
    ethers.toBeHex(1, 32)
  ])
);
storage[isAdminMapKey] = ethers.toBeHex(1, 32);

// Validator count = 2 (slot 2) - CRITICAL: Must be slot 2
storage['0x2'] = ethers.toBeHex(validatorAddresses.length, 32);

// Validators array (slot 2 array storage)
const validatorsArraySlot = ethers.keccak256(ethers.toBeHex(2, 32));
for (let i = 0; i < validatorAddresses.length; i++) {
  const slot = ethers.toBeHex(ethers.toBigInt(validatorsArraySlot) + ethers.toBigInt(i));
  storage[slot] = ethers.zeroPadValue(validatorAddresses[i], 32);

  // isValidator mapping (slot 3)
  const isValidatorMapKey = ethers.keccak256(
    ethers.concat([
      ethers.zeroPadValue(validatorAddresses[i], 32),
      ethers.toBeHex(3, 32)
    ])
  );
  storage[isValidatorMapKey] = ethers.toBeHex(1, 32);
}

// Additional storage slots
storage['0x5'] = ethers.toBeHex(0, 32);
storage['0x7'] = ethers.toBeHex(0, 32);

// QBFT extraData with EMPTY validator list (reads from contract)
const vanity = '0x' + '0'.repeat(64);
const validators = [];
const vote = [];
const round = '0x';
const seals = [];

const extraData = ethers.encodeRlp([
  vanity,
  validators,
  vote,
  round,
  seals
]);

const genesis = {
  config: {
    chainId: 10001,
    berlinBlock: 0,
    londonBlock: 0,
    shanghaiTime: 0,
    cancunTime: 0,
    qbft: {
      blockperiodseconds: 5,
      epochlength: 30000,
      requesttimeoutseconds: 10,
      validatorcontractaddress: CONTRACT_ADDRESS
    }
  },
  nonce: '0x0',
  timestamp: '0x' + Math.floor(Date.now() / 1000).toString(16),
  extraData,
  gasLimit: '0x3B9ACA00',
  difficulty: '0x1',
  mixHash: '0x63746963616c2062797a616e74696e65206661756c7420746f6c6572616e6365',
  coinbase: '0x0000000000000000000000000000000000000000',
  alloc: {
    [CONTRACT_ADDRESS]: {
      code: DEPLOYED_BYTECODE,
      storage,
      balance: '0x0'
    },
    [adminAddress]: {
      balance: '0x200000000000000000000000000000000000000000000000000000000000000'
    }
  }
};

fs.writeFileSync('genesis.json', JSON.stringify(genesis, null, 2));

console.log('\n✅ Genesis file created at genesis.json');
console.log('\nStorage slots configured:');
console.log(`- Admin count (slot 0): 1`);
console.log(`- Admin address at array position 0`);
console.log(`- Validator count (slot 2): ${validatorAddresses.length} ✓ CORRECT SLOT`);
console.log(`- Validators at array positions 0-${validatorAddresses.length - 1}`);
console.log(`- isAdmin and isValidator mappings configured`);
console.log('\nValidator Configuration:');
console.log('- Quorum requirement: 2/2 = 100% (zero fault tolerance)');
console.log('- Can add more validators later via contract calls');
