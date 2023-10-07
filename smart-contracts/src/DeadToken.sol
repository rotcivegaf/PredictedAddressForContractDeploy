// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ERC20 } from "solmate/tokens/ERC20.sol";

contract DeadToken is ERC20("Dead Token", "DEAD", 18) {
    constructor () {
        _mint(0x889558Ea3C7b58b544EB17a6Fc04044547837a77, 1_000_000 ether);
    }
}