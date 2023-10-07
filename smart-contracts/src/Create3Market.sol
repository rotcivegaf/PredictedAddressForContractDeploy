// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Create3Factory } from "./Create3Factory.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Create3Market {
    event CreateOrder(uint256 _orderId, Order _order);
    event CancelOrder(uint256 _orderId);
    event TakeOrder(address indexed _creator, uint256 indexed _addrId, uint256 _orderId);

    error ToZeroAddress();
    error ReserveAddrZeroAddress();
    error TokenZeroAddress();
    error BitsOnZero();
    error OfferZero();
    error WrongAddress();
    error NotExpiredToCancel();
    error WrongMiner();

    bytes32 constant private F = 0xF000000000000000000000000000000000000000000000000000000000000000;

    Create3Factory immutable c3factory;

    mapping(address => Order[]) private _orders;

    struct Order {
        address to;            // The recipient of the NFT
        uint96 expiryToCancel; // The timestamp from which it can be canceled
        address reserveAddr;   // The wanted address
        uint40 bitsOn;         // Each bit on represent an hex wanted in the reserveAddr
                               // Example: I want an address who start with 0000, in the index ten have a 6 and ends with CAFE
                               //     bitsOn: F02000000F(1111000000100000000000000000000000001111)
                               //     reserveAddr:     0x0000??????6?????????????????????????CAFE
        IERC20 token;          // The currency of the Order
        uint256 offer;         // The amount of the currency
        address miner;         // The taker of the Order(address(0) if any)
    }

    constructor(Create3Factory _c3factory) payable {
        c3factory = _c3factory;
    }

    function createOrder(Order calldata _order) external returns(uint256 orderId_) {
        if (_order.to == address(0)) revert ToZeroAddress();
        if (_order.reserveAddr == address(0)) revert ReserveAddrZeroAddress();
        if (_order.bitsOn == 0) revert BitsOnZero();
        if (address(_order.token) == address(0)) revert TokenZeroAddress();
        if (_order.offer == 0) revert OfferZero();

        SafeERC20.safeTransferFrom(_order.token, msg.sender, address(this), _order.offer);

        orderId_ = _orders[msg.sender].length;
        _orders[msg.sender].push(_order);

        emit CreateOrder(orderId_, _order);
    }

    function cancelOrder(uint256 _orderId) external {
        Order memory order = _orders[msg.sender][_orderId];
        delete _orders[msg.sender][_orderId];

        if (order.expiryToCancel > block.timestamp) revert NotExpiredToCancel();

        SafeERC20.safeTransfer(order.token, msg.sender, order.offer);

        emit CancelOrder(_orderId);
    }

    function takeOrder(uint256 _addrId, address _creator, uint256 _orderId) external {
        Order memory order = _orders[_creator][_orderId];
        delete _orders[_creator][_orderId];

        if (order.miner != address(0) && order.miner != msg.sender) revert WrongMiner();
        _checkAddress(order.bitsOn, bytes20(order.reserveAddr), bytes20(uint160(_addrId)));

        c3factory.safeTransferFrom(msg.sender, order.to, _addrId);
        SafeERC20.safeTransfer(order.token, msg.sender, order.offer);

        emit TakeOrder(_creator, _addrId, _orderId);
    }

    // Internals

    function _checkAddress(uint40 _bitsOn, bytes20 _addr0, bytes20 _addr1) private pure {
        unchecked {
            for (uint256 i; i < 40; ++i) {
                uint256 shiftBits = i * 4;

                if (((_bitsOn >> (39 - i)) & 1) == 1) {
                    if (
                        (_addr0 << shiftBits & F) !=
                        (_addr1 << shiftBits & F)
                    ) {
                        revert WrongAddress();
                    }
                }
            }
        }
    }

    // Getters

    function getOrdersLength(address _who) external view returns(uint256) {
        return _orders[_who].length;
    }

    function getOrders(address _who) external view returns(Order[] memory) {
        return _orders[_who];
    }

    function getOrder(address _who, uint256 _orderId) external view returns(Order memory) {
        return _orders[_who][_orderId];
    }
}
