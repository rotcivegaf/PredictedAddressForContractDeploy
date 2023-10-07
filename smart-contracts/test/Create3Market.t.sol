// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/Create3Factory.sol";
import "../src/interfaces/IUriProvider.sol";
import "../src/Create3Market.sol";
import "../src/TestContracts.sol";

contract Create3MarketTest is Test {
    event CreateOrder(uint256 _orderId, Create3Market.Order _order);
    event CancelOrder(uint256 _orderId);
    event TakeOrder(address indexed _creator, uint256 indexed _addrId, uint256 _orderId);

    Create3Factory public factory;
    Create3Market public market;

    IERC20 testToken;
    address constant alice = address(1);
    address constant james = address(2);

    //uint40 bitsOn = uint40(bytes5(hex'0000000001'));
    uint256 offer = 1 ether;

    bytes32 aSalt32 = 0x0000000000000000000000000000000000000000000000000000000000000001;
    uint40 bitsOn = uint40(bytes5(hex'F060010001'));
    //                      1111000001100000000000010000000000000001
    address reserveAddr = 0xb23B00000660000080000004000000000000000A;
    //                    0xB23b08B0b6614f118d801684e68bcA9F2Cbece2A

    Create3Market.Order defaultOrder;

    function setUp() external {
        factory = new Create3Factory(IUriProvider(address(0)));
        market = new Create3Market(factory);
        testToken = IERC20(address(new TestToken()));

        defaultOrder = Create3Market.Order({
            to:             james,
            expiryToCancel: 0,
            reserveAddr:    reserveAddr,
            token:          testToken,
            bitsOn:         bitsOn,
            offer:          offer,
            miner:          address(0)
        });

        deal(address(testToken), alice, defaultOrder.offer);
        vm.startPrank(alice);
        testToken.approve(address(market), type(uint256).max);
    }

    // Function: createOrder

    function testCreateOrder() external {
        vm.expectEmit(false, false, false, true);
        emit CreateOrder(market.getOrdersLength(alice), defaultOrder);

        market.createOrder(defaultOrder);

        assertEq(testToken.balanceOf(address(market)), defaultOrder.offer, "Wrong testToken balance");
        assertEq(testToken.balanceOf(alice), 0, "Wrong testToken balance");

        Create3Market.Order memory order = market.getOrder(alice, 0);
        assertEq(order.to, defaultOrder.to, "Wrong to");
        assertEq(order.reserveAddr, defaultOrder.reserveAddr, "Wrong reserveAddr");
        assertEq(address(order.token), address(defaultOrder.token), "Wrong token");
        assertEq(order.bitsOn, defaultOrder.bitsOn, "Wrong bitsOn");
        assertEq(order.offer, defaultOrder.offer, "Wrong offer");
    }

    function testCreateThreeOrders() external {
        deal(address(testToken), alice, 3 * defaultOrder.offer);

        market.createOrder(defaultOrder);
        assertEq(testToken.balanceOf(alice), 2 * defaultOrder.offer, "Wrong testToken balance 0");
        assertEq(testToken.balanceOf(address(market)), defaultOrder.offer, "Wrong testToken balance 0");
        assertEq(market.getOrdersLength(alice), 1, "Wrong orders length 0");

        market.createOrder(defaultOrder);
        assertEq(testToken.balanceOf(alice), defaultOrder.offer, "Wrong testToken balance 1");
        assertEq(testToken.balanceOf(address(market)), 2 *defaultOrder.offer, "Wrong testToken balance 1");
        assertEq(market.getOrdersLength(alice), 2, "Wrong orders length 1");

        market.createOrder(defaultOrder);
        assertEq(testToken.balanceOf(alice), 0, "Wrong testToken balance 2");
        assertEq(testToken.balanceOf(address(market)), 3 * defaultOrder.offer, "Wrong testToken balance 2");
        assertEq(market.getOrdersLength(alice), 3, "Wrong orders length 2");
    }

    function testTryCreateOrderWithToZeroAddress() external {
        defaultOrder.to = address(0);

        vm.expectRevert(Create3Market.ToZeroAddress.selector);
        market.createOrder(defaultOrder);
    }

    function testTryCreateOrderWithReserveAddrZeroAddress() external {
        defaultOrder.reserveAddr = address(0);

        vm.expectRevert(Create3Market.ReserveAddrZeroAddress.selector);
        market.createOrder(defaultOrder);
    }

    function testTryCreateOrderWithBitsOnZero() external {
        defaultOrder.bitsOn = 0;

        vm.expectRevert(Create3Market.BitsOnZero.selector);
        market.createOrder(defaultOrder);
    }

    function testTryCreateOrderWithTokenZeroAddress() external {
        defaultOrder.token = IERC20(address(0));

        vm.expectRevert(Create3Market.TokenZeroAddress.selector);
        market.createOrder(defaultOrder);
    }

    function testTryCreateOrderWithOfferZero() external {
        defaultOrder.offer = 0;

        vm.expectRevert(Create3Market.OfferZero.selector);
        market.createOrder(defaultOrder);
    }

    // Function: cancelOrder

    function testCancelOrder() external {
        market.createOrder(defaultOrder);

        vm.expectEmit(false, false, false, true);
        emit CancelOrder(0);

        market.cancelOrder(0);

        assertEq(testToken.balanceOf(address(market)), 0, "Wrong testToken balance");
        assertEq(testToken.balanceOf(alice), defaultOrder.offer, "Wrong testToken balance");

        Create3Market.Order memory order = market.getOrder(alice, 0);
        assertEq(order.to, address(0), "Wrong to");
        assertEq(order.reserveAddr, address(0), "Wrong reserveAddr");
        assertEq(address(order.token), address(0), "Wrong token");
        assertEq(order.bitsOn, 0, "Wrong bitsOn");
        assertEq(order.offer, 0, "Wrong offer");

        assertEq(market.getOrdersLength(alice), 1, "Wrong orders length");
    }

    function testWaitADayAndCancelOrder() external {
        defaultOrder.expiryToCancel = uint96(block.timestamp + 1 days);
        market.createOrder(defaultOrder);

        vm.warp(block.timestamp + 1 days);

        market.cancelOrder(0);
    }

    function testTryCancelOrderNotExpiredToCancel() external {
        defaultOrder.expiryToCancel = uint96(block.timestamp + 1 days);
        uint256 orderId = market.createOrder(defaultOrder);

        vm.expectRevert(Create3Market.NotExpiredToCancel.selector);
        market.cancelOrder(orderId);
    }

    function testTryCancelOrderInexist() external {
        vm.expectRevert(stdError.indexOOBError);
        market.cancelOrder(0);

        vm.expectRevert(stdError.indexOOBError);
        market.cancelOrder(10);

        vm.expectRevert(stdError.indexOOBError);
        market.cancelOrder(type(uint256).max);
    }

    // Function: takeOrder

    function testTakeOrder() external {
        market.createOrder(defaultOrder);
        vm.stopPrank();

        vm.startPrank(james);
        uint256 addrId = factory.reserve(james, aSalt32);
        factory.setApprovalForAll(address(market), true);

        vm.expectEmit(true, true, false, true);
        emit TakeOrder(alice, addrId, 0);

        market.takeOrder(addrId, alice, 0);

        // ERC721
        assertEq(factory.ownerOf(addrId), james, "Wrong owner");

        // ERC20
        assertEq(testToken.balanceOf(address(market)), 0, "Wrong testToken balance");
        assertEq(testToken.balanceOf(alice), 0, "Wrong testToken balance");
        assertEq(testToken.balanceOf(james), defaultOrder.offer, "Wrong testToken balance");

        // Order
        Create3Market.Order memory order = market.getOrder(alice, 0);
        assertEq(order.to, address(0), "Wrong to");
        assertEq(order.reserveAddr, address(0), "Wrong reserveAddr");
        assertEq(address(order.token), address(0), "Wrong token");
        assertEq(order.bitsOn, 0, "Wrong bitsOn");
        assertEq(order.offer, 0, "Wrong offer");
    }

    function testTakeOrderWithMiner() external {
        defaultOrder.miner = address(3);
        market.createOrder(defaultOrder);
        vm.stopPrank();

        vm.startPrank(james);
        uint256 addr = factory.reserve(james, aSalt32);
        factory.transferFrom(james, defaultOrder.miner, addr);
        vm.stopPrank();

        vm.startPrank(defaultOrder.miner);
        factory.setApprovalForAll(address(market), true);
        market.takeOrder(addr, alice, 0);
    }

    function testTryTakeOrderWithWrongMiner() external {
        defaultOrder.miner = address(3);
        market.createOrder(defaultOrder);
        vm.stopPrank();

        vm.startPrank(james);
        uint256 addr = factory.reserve(james, aSalt32);

        vm.expectRevert(Create3Market.WrongMiner.selector);
        market.takeOrder(addr, alice, 0);
    }
}
