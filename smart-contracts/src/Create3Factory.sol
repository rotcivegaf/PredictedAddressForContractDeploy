// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { CREATE3 } from "solmate/utils/CREATE3.sol";
import { ERC721 } from "solmate/tokens/ERC721.sol";
import { Owned } from "solmate/auth/Owned.sol";
import { IUriProvider } from "./interfaces/IUriProvider.sol";

contract Create3Factory is ERC721, Owned {
    event SetTokenUriProvider(IUriProvider _uriProvider);
    event Reserve(address indexed _sender, address indexed _to, bytes32 _salt, uint256 indexed _addrId);
    event Deploy(uint256 _addrId);

    error AlreadyReserve();
    error NotOwnerOrApproved();
    error NotMinted();

    IUriProvider public uriProvider;
    mapping(uint256 => bytes32) public addrs;

    constructor(IUriProvider _uriProvider) payable
        ERC721("Predicted Address for Contract Deploy", "PACD")
        Owned(msg.sender)
    {
        setTokenUriProvider(_uriProvider);
    }

    // OnlyOwner

    function setTokenUriProvider(IUriProvider _uriProvider) public onlyOwner {
        uriProvider = _uriProvider;
        emit SetTokenUriProvider(_uriProvider);
    }

    // Reserve

    function reserve(address _to, bytes32 _salt) external returns(uint256 addrId_) {
        addrId_ = _reserve(_to, calcSenderSalt(msg.sender, _salt));

        emit Reserve(msg.sender, _to, _salt, addrId_);
    }

    function calcAddr(address _sender, bytes32 _salt) external view returns(address) {
        return CREATE3.getDeployed(calcSenderSalt(_sender, _salt));
    }

    function calcSenderSalt(address _sender, bytes32 _salt) public pure returns(bytes32) {
        return keccak256(
            abi.encodePacked(
                _sender,
                _salt
            )
        );
    }

    // Reserve

    function _reserve(address _to, bytes32 _senderSalt) private returns(uint256 addrId_) {
        addrId_ = uint160(CREATE3.getDeployed(_senderSalt));

        if (addrs[addrId_] != bytes32(0)) revert AlreadyReserve();

        addrs[addrId_] = _senderSalt;

        _safeMint(
            _to,
            addrId_,
            abi.encode(_senderSalt)
        );
    }

    // Deploy

    function deploy(uint256 _addrId, bytes memory _creationCode) external payable returns(address addr_) {
        _checkOwnerOrApproved(_addrId);

        _burn(_addrId);

        emit Deploy(_addrId);

        return CREATE3.deploy(
            addrs[_addrId],
            _creationCode,
            msg.value
        );
    }

    // ERC721 functions

    function tokenURI(uint256 _addrId) public view override returns (string memory) {
        if (addrs[_addrId] != 0) revert NotMinted();

        return uriProvider.tokenURI(_addrId);
    }

    function _checkOwnerOrApproved(uint256 _addrId) internal view {
        address owner = ERC721.ownerOf(_addrId);
        if (
            msg.sender != owner &&
            !isApprovedForAll[owner][msg.sender] &&
            getApproved[_addrId] != msg.sender
        )
            revert NotOwnerOrApproved();
    }
}