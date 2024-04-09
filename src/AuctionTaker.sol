// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {Governance} from "@periphery/utils/Governance.sol";
import {Auction} from "@periphery/Auctions/Auction.sol";
import {ITaker} from "@periphery/interfaces/ITaker.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AuctionTaker is Governance, ReentrancyGuard, ITaker {
    using SafeERC20 for ERC20;

    constructor() Governance(msg.sender) {}

    function take(
        address _auction,
        bytes32 _auctionId,
        uint256 _maxAmount,
        address _target,
        bytes calldata _calldata
    ) external {
        Auction(_auction).take(
            _auctionId,
            _maxAmount,
            address(this),
            abi.encode(_target, _calldata)
        );
    }

    function auctionTakeCallback(
        bytes32 /*_auctionId*/,
        address _sender,
        uint256 /*_amountTaken*/,
        uint256 /*_amountNeeded*/,
        bytes calldata _data
    ) external nonReentrant {
        require(_sender == address(this));

        (address _target, bytes memory _calldata) = abi.decode(
            _data,
            (address, bytes)
        );
        (bool success, ) = address(_target).call(_calldata);
        require(success, "!success"); // dev: static call failed
    }
}
