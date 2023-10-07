// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/Create3Factory.sol";
import { IUriProvider } from "../src/interfaces/IUriProvider.sol";
import "../src/TestContracts.sol";

contract Create3FactoryTest is Test {
    event Reserve(address indexed _sender, address indexed _to, bytes32 _salt, uint256 indexed _addrId);
    event Deploy(uint256 _addrId);
    event UnSoulbound(uint256 _addrId);

    Create3Factory public factory;

    address constant alice = address(1);
    address constant james = address(2);

    bytes32 aSalt;
    address specAddr;
    uint256 specAddrId;

    address testContractInstance;

    function setUp() external {
        factory = new Create3Factory(IUriProvider(address(0)));

        aSalt = keccak256(abi.encode(bytes32(block.timestamp)));
        specAddr = factory.calcAddr(alice, aSalt);
        specAddrId = uint160(specAddr);

        testContractInstance = address(new TestContract());

        vm.startPrank(alice);
    }

    // reserve

    function testReserve() external {
        vm.expectEmit(true, true, true, false);
        emit Reserve(alice, alice, aSalt, specAddrId);

        factory.reserve(alice, aSalt);

        bytes32 senderSalt = keccak256(abi.encodePacked(alice, aSalt));
        assertEq(factory.addrs(specAddrId), senderSalt, "Wrong address -> salt");
        assertEq(factory.ownerOf(specAddrId), alice, "NFT not minted");
    }

    function testReserveTo() external {
        vm.expectEmit(true, true, true, false);
        emit Reserve(alice, james, aSalt, specAddrId);

        factory.reserve(james, aSalt);

        bytes32 senderSalt = keccak256(abi.encodePacked(alice, aSalt));
        assertEq(factory.addrs(specAddrId), senderSalt, "Wrong address -> salt");
        assertEq(factory.ownerOf(specAddrId), james, "NFT not minted");
    }

    function testTryReserveTwice() external {
        factory.reserve(alice, aSalt);

        vm.expectRevert(Create3Factory.AlreadyReserve.selector);
        factory.reserve(alice, aSalt);
    }

    // deploy

    function testDeploy() external {
        factory.reserve(alice, aSalt);

        vm.expectEmit(false, false, false, true);
        emit Deploy(specAddrId);

        bytes memory creationCode = type(TestContract).creationCode;
        address retAddr = factory.deploy(specAddrId, creationCode);

        assertEq(retAddr, specAddr, "Wrong address");
        bytes32 senderSalt = keccak256(abi.encodePacked(alice, aSalt));
        assertEq(factory.addrs(specAddrId), senderSalt);

        // Burned
        vm.expectRevert("NOT_MINTED");
        factory.ownerOf(specAddrId);

        assertEq(specAddr.code, testContractInstance.code, "Wrong code match");
        assertEq(TestContract(specAddr).foo(), 1);
    }

    function testDeployWithValue() external {
        factory.reserve(alice, aSalt);

        vm.deal(alice, 1);
        address retAddr = factory.deploy{ value: 1 }(specAddrId, type(TestContractPayable).creationCode);

        assertEq(retAddr.balance, 1, "Wrong balance");
    }

    function testDeployWithParameters() external {
        factory.reserve(alice, aSalt);

        uint256 pUint = 1;
        uint256 pUintC = 2;

        address retAddr = factory.deploy(
            specAddrId,
            abi.encodePacked(
                type(TestContractWithParameters).creationCode,
                pUint,
                pUintC
            )
        );

        assertEq(TestContractWithParameters(retAddr).pUint(), pUint);
        assertEq(TestContractWithParameters(retAddr).pUintC(), pUintC);
    }

    function testTryDeployTwice() external {
        factory.reserve(alice, aSalt);
        bytes memory creationCode = type(TestContract).creationCode;
        factory.deploy(specAddrId, creationCode);

        vm.expectRevert("NOT_MINTED");
        factory.deploy(specAddrId, creationCode);
    }

    function testTryDeployWithoutAllowance() external {
        factory.reserve(alice, aSalt);
        vm.stopPrank();

        vm.prank(james);
        bytes memory creationCode = type(TestContract).creationCode;
        vm.expectRevert(Create3Factory.NotOwnerOrApproved.selector);
        factory.deploy(specAddrId, creationCode);
    }

    function testTryDeployAndReserveAgain() external {
        factory.reserve(alice, aSalt);
        bytes memory creationCode = type(TestContract).creationCode;
        factory.deploy(specAddrId, creationCode);

        vm.expectRevert(Create3Factory.AlreadyReserve.selector);
        factory.reserve(alice, aSalt);
    }
}
