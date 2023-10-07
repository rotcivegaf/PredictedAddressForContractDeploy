// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract TestContract {
    function foo() external pure returns(uint256) {
        return 1;
    }
}

contract TestContractPayable is TestContract {
    constructor () payable { }
}

contract TestContractWithParameters is TestContract {
    uint256 public pUint;
    uint256 public immutable pUintC;

    constructor (
        uint256 _pUint,
        uint256 _pUintC
    ) {
        pUint = _pUint;
        pUintC = _pUintC;
    }
}

import { ERC20 } from "solmate/tokens/ERC20.sol";

contract TestToken is ERC20("Test Token", "TEST", 18) { }