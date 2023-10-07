// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IUriProvider {
    function tokenURI(uint256 id) external view returns (string memory);
}