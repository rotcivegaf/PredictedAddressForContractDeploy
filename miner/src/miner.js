const keccak = require('keccak');
const randomBytes = require('randombytes');
const BN = require('bn.js');
const config = require('../config.json');

const FACTORY_ADDR = (new BN(config.factoryAdrr.slice(2), 16)).toBuffer('big', 20);
const step = 500;
const PROXY_BYTECODE_HASH = (new BN("21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f", 16)).toBuffer('big', 32);
const FF = (new BN("FF", 16)).toBuffer('big', 1);
const D694 = (new BN("d694", 16)).toBuffer('big', 2);
const _01 = (new BN("01", 16)).toBuffer('big', 1);

function getRandomContract(sender) {
  const salt = randomBytes(32);
  const senderSalt = keccak('keccak256').update(Buffer.concat([sender, salt])).digest();

  const proxy = keccak('keccak256').update(
    Buffer.concat([FF, FACTORY_ADDR, senderSalt, PROXY_BYTECODE_HASH,])
  ).digest().slice(12);

  const address = keccak('keccak256').update(
    Buffer.concat([D694, proxy, _01,])
  ).digest().slice(12).toString('hex');

  return {
    salt,
    senderSalt,
    address,
  };
};

function isValidContractAddress(address, input, isChecksum, isSuffix) {
  const subStr = isSuffix ? address.substr(40 - input.length) : address.substr(0, input.length);

  if (!isChecksum) {
    return input === subStr;
  }
  if (input.toLowerCase() !== subStr) {
    return false;
  }

  return isValidChecksum(address, input, isSuffix);
};

function isValidChecksum(address, input, isSuffix) {
  const hash = keccak('keccak256').update(address).digest().toString('hex');
  const shift = isSuffix ? 40 - input.length : 0;

  for (let i = 0; i < input.length; i++) {
    const j = i + shift;
    if (input[i] !== (parseInt(hash[j], 16) >= 8 ? address[j].toUpperCase() : address[j])) {
      return false;
    }
  }
  return true;
};

function toChecksumAddress(address) {
  const hash = keccak('keccak256').update(address).digest().toString('hex');
  let ret = '';
  for (let i = 0; i < address.length; i++) {
    ret += parseInt(hash[i], 16) >= 8 ? address[i].toUpperCase() : address[i];
  }
  return ret;
};

function mineContract(sender, input, isChecksum, isSuffix) {
  input = isChecksum ? input : input.toLowerCase();
  const senderHex = (new BN(sender.slice(2), 16)).toBuffer('big', 20);
  let contract = getRandomContract(senderHex);
  let attempts = 1;

  while (!isValidContractAddress(contract.address, input, isChecksum, isSuffix)) {
    if (attempts >= step) {
      attempts = 0;
    }
    contract = getRandomContract(senderHex);
    attempts++;
  }

  return {
    salt: '0x' + contract.salt.toString('hex'),
    senderSalt: '0x' + contract.senderSalt.toString('hex'),
    address: '0x' + toChecksumAddress(contract.address),
    attempts
  };
};

function main () {
  const contract = mineContract(config.data.sender, config.data.hex, config.data.checksum, config.data.suffix);

  console.log(contract);
}

main();
