// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {Auction} from "@periphery/Auctions/Auction.sol";
import {ITaker} from "@periphery/interfaces/ITaker.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AuctionTaker is ReentrancyGuard, ITaker {
    using SafeERC20 for ERC20;

    constructor() {}

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
        (address _takeToken, address _giveToken, , ) = Auction(_auction)
            .auctionInfo(_auctionId);
        uint256 _takeSurplus = ERC20(_takeToken).balanceOf(address(this));

        // send any surplus tokens to the caller
        if (_takeSurplus > 0) {
            ERC20(_takeToken).safeTransfer(msg.sender, _takeSurplus);
        }
        uint256 _giveSurplus = ERC20(_giveToken).balanceOf(address(this));
        if (_giveSurplus > 0) {
            ERC20(_giveToken).safeTransfer(msg.sender, _giveSurplus);
        }
    }

    function auctionTakeCallback(
        bytes32 _auctionId,
        address _sender,
        uint256 _amountTaken,
        uint256 _amountNeeded,
        bytes calldata _data
    ) external nonReentrant {
        require(_sender == address(this));

        (address _takeToken, address _giveToken, , ) = Auction(msg.sender)
            .auctionInfo(_auctionId);

        (address _target, bytes memory _calldata) = abi.decode(
            _data,
            (address, bytes)
        );

        ERC20(_takeToken).safeApprove(_target, _amountTaken);
        (bool success, ) = address(_target).call(_calldata);
        require(success, "!success"); // dev: call failed

        ERC20(_giveToken).safeApprove(msg.sender, _amountNeeded);
    }

    function sweep(address _token, uint256 _amount) external {
        ERC20(_token).safeTransfer(msg.sender, _amount);
    }
}
