const { ethers } = require('ethers');
const fs = require('fs');

const CONTRACT_ADDRESS = '0x0000000000000000000000000000000000009999';

const DEPLOYED_BYTECODE = fs.readFileSync('deployedBytecode.txt', 'utf8').trim();

const validatorAddresses = [
  '0xf176465f83bfa22f1057e4353b5a100a1c198507',
  '0xef832eca2439987697d43917f9d3d0dd1e9410b7',
  '0x97d2a16f323947b757a4de762e460e6bbace1adc',
  '0x82085d3051fc8c0c90c7908c92382072c8681b2c'
];

const adminAddress = validatorAddresses[0];

console.log('Generating genesis file...');
console.log('Admin:', adminAddress);
console.log('Validators:', validatorAddresses);

const storage = {};

storage['0x0'] = ethers.toBeHex(1, 32);

const adminsArraySlot = ethers.keccak256(ethers.toBeHex(0, 32));
storage[adminsArraySlot] = ethers.zeroPadValue(adminAddress, 32);

const isAdminMapKey = ethers.keccak256(
  ethers.concat([
    ethers.zeroPadValue(adminAddress, 32),
    ethers.toBeHex(1, 32)
  ])
);
storage[isAdminMapKey] = ethers.toBeHex(1, 32);

storage['0x2'] = ethers.toBeHex(validatorAddresses.length, 32);

const validatorsArraySlot = ethers.keccak256(ethers.toBeHex(2, 32));
for (let i = 0; i < validatorAddresses.length; i++) {
  const slot = ethers.toBeHex(ethers.toBigInt(validatorsArraySlot) + ethers.toBigInt(i));
  storage[slot] = ethers.zeroPadValue(validatorAddresses[i], 32);

  const isValidatorMapKey = ethers.keccak256(
    ethers.concat([
      ethers.zeroPadValue(validatorAddresses[i], 32),
      ethers.toBeHex(3, 32)
    ])
  );
  storage[isValidatorMapKey] = ethers.toBeHex(1, 32);
}

storage['0x5'] = ethers.toBeHex(0, 32);
storage['0x7'] = ethers.toBeHex(0, 32);

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

fs.writeFileSync('besu-network/genesis.json', JSON.stringify(genesis, null, 2));

console.log('\nGenesis file created at besu-network/genesis.json');
console.log('\nStorage slots configured:');
console.log(`- Admin count (slot 0): 1`);
console.log(`- Admin address at array position 0`);
console.log(`- Validator count (slot 2): ${validatorAddresses.length}`);
console.log(`- Validators at array positions 0-${validatorAddresses.length - 1}`);
console.log(`- isAdmin and isValidator mappings configured`);
