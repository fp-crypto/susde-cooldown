// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console.sol";
import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";
import {ISUSDe} from "../interfaces/ethena/ISUSDe.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract AuctionTest is Setup {
    function setUp() public virtual override {
        super.setUp();
        setFees(0, 0);
        vm.prank(management);
        strategy.setMinCooldownAmount(500e18);
    }

    function test_auction_baseCase(uint256 _amount) public {
        _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        uint256 kickedAmount = strategy.kick(auctionId);
        assertEq(kickedAmount, _amount, "!kickedAmount");

        (, , , uint128 takeAvailable) = strategy.auctions(auctionId);

        uint256 steps = 1_440;
        uint256 skipBps = 0; //2500;

        uint256 stakingRate = susde.convertToAssets(1e18);
        console.log("sr: %e", stakingRate);

        skip((strategy.auctionLength() * skipBps) / 1e4); // immediately skip part of the auction
        for (uint256 i = 0; i < steps; ++i) {
            address buyer = address(62735);
            uint256 amountNeeded = strategy.getAmountNeeded(
                auctionId,
                takeAvailable
            );
            uint256 rate = (amountNeeded * 1e18) / uint256(takeAvailable);

            int256 surplusBps = ((int256(susde.convertToAssets(amountNeeded)) -
                int256(uint256(takeAvailable))) * 1e4) /
                int256(uint256(takeAvailable));

            console.log("i: %i", i);
            console.log("surplus bps: ");
            console.logInt(surplusBps);
            console.log("rate: %e\n", 1e36 / rate);

            if (surplusBps < 0) break;

            if (
                surplusBps <= 200 &&
                surplusBps > int256(uint256(strategy.minSUSDeDiscountBps()))
            ) {
                console.log();
                console.log("i: %i", i);
                console.log("amountNeeded: %e", amountNeeded);
                console.log("takeAvailable: %e", takeAvailable);
                console.log("rate: %e", rate);
                console.log("sr: %e", stakingRate);
                console.log(susde.convertToAssets(amountNeeded));
                console.log("surplus bps: ");
                console.logInt(surplusBps);

                airdrop(ERC20(address(susde)), buyer, amountNeeded);
                vm.prank(buyer);
                susde.approve(address(strategy), amountNeeded);

                // take the auction
                vm.prank(buyer);
                strategy.take(auctionId);
                break;
            }

            skip(((strategy.auctionLength() * (1e4 - skipBps)) / 1e4) / steps);
        }

        logStrategyInfo();
        assertEq(asset.balanceOf(address(strategy)), 0);
        assertGt(
            susde.convertToAssets(susde.balanceOf(address(strategy))),
            strategy.totalAssets()
        );
        assertEq(strategy.coolingUSDe(), 0);

        vm.prank(management);
        strategy.setDoHealthCheck(false);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        logStrategyInfo();
        assertEq(asset.balanceOf(address(strategy)), 0);
        assertEq(susde.convertToAssets(susde.balanceOf(address(strategy))), 0);
        assertEq(strategy.coolingUSDe(), strategy.totalAssets());

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(
            Math.max(strategy.profitMaxUnlockTime(), susde.cooldownDuration())
        );

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGt(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
        logStrategyInfo();
    }

    function test_auction_failure(uint256 _amount) public {
        _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        uint256 kickedAmount = strategy.kick(auctionId);
        assertEq(kickedAmount, _amount, "!kickedAmount");

        (, , , uint128 takeAvailable) = strategy.auctions(auctionId);

        uint256 steps = 1_440;
        uint256 skipBps = 0; //2500;

        uint256 stakingRate = susde.convertToAssets(1e18);
        console.log("sr: %e", stakingRate);

        skip((strategy.auctionLength() * skipBps) / 1e4); // immediately skip part of the auction
        for (uint256 i = 0; i < steps; ++i) {
            address buyer = address(62735);
            uint256 amountNeeded = strategy.getAmountNeeded(
                auctionId,
                takeAvailable
            );
            uint256 rate = (amountNeeded * 1e18) / uint256(takeAvailable);

            int256 surplusBps = ((int256(susde.convertToAssets(amountNeeded)) -
                int256(uint256(takeAvailable))) * 1e4) /
                int256(uint256(takeAvailable));

            if (surplusBps < int256(uint256(strategy.minSUSDeDiscountBps()))) {
                console.log();
                console.log("i: %i", i);
                console.log("amountNeeded: %e", amountNeeded);
                console.log("takeAvailable: %e", takeAvailable);
                console.log("rate: %e", rate);
                console.log("sr: %e", stakingRate);
                console.log(susde.convertToAssets(amountNeeded));
                console.log("surplusbps: ");
                console.logInt(surplusBps);

                airdrop(ERC20(address(susde)), buyer, amountNeeded);
                vm.prank(buyer);
                susde.approve(address(strategy), amountNeeded);

                // take the auction
                vm.startPrank(buyer);
                vm.expectRevert();
                strategy.take(auctionId);
                vm.stopPrank();
                break;
            }

            skip(((strategy.auctionLength() * (1e4 - skipBps)) / 1e4) / steps);
        }

        logStrategyInfo();
        assertEq(asset.balanceOf(address(strategy)), strategy.totalAssets());

        vm.prank(management);
        strategy.setDoHealthCheck(false);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        logStrategyInfo();

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(
            Math.max(strategy.profitMaxUnlockTime(), susde.cooldownDuration())
        );

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertEq(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
        logStrategyInfo();
    }

    function test_auction_partiallyTake(
        uint256 _amount,
        uint16 _partBps
    ) public {
        _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);
        _partBps = uint16(bound(uint256(_partBps), 1000, 9000)); // between 10% and 90%

        vm.prank(management);
        strategy.setMinCooldownAmount(1e18); // set minCooldown to be very small

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        uint256 kickedAmount = strategy.kick(auctionId);
        assertEq(kickedAmount, _amount, "!kickedAmount");

        (, , , uint128 takeAvailable) = strategy.auctions(auctionId);

        uint256 steps = 1_440;
        uint256 skipBps = 0; //2500;

        uint256 stakingRate = susde.convertToAssets(1e18);

        skip((strategy.auctionLength() * skipBps) / 1e4); // immediately skip part of the auction
        for (uint256 i = 0; i < steps; ++i) {
            address buyer = address(62735);
            uint256 amountNeeded = strategy.getAmountNeeded(
                auctionId,
                takeAvailable
            );
            uint256 rate = (amountNeeded * 1e18) / uint256(takeAvailable);

            int256 surplusBps = ((int256(susde.convertToAssets(amountNeeded)) -
                int256(uint256(takeAvailable))) * 1e4) /
                int256(uint256(takeAvailable));

            if (
                surplusBps <= 200 &&
                surplusBps > int256(uint256(strategy.minSUSDeDiscountBps()))
            ) {
                airdrop(ERC20(address(susde)), buyer, amountNeeded);
                vm.prank(buyer);
                susde.approve(address(strategy), amountNeeded);

                // take the auction
                vm.prank(buyer);
                strategy.take(
                    auctionId,
                    (uint256(takeAvailable) * uint256(_partBps)) / 1e4
                );
                console.log("take");
                break;
            }

            skip(((strategy.auctionLength() * (1e4 - skipBps)) / 1e4) / steps);
        }

        logStrategyInfo();
        assertApproxEq(
            asset.balanceOf(address(strategy)),
            (strategy.totalAssets() * uint256(1e4 - _partBps)) / 1e4,
            1e6
        );
        assertGe(
            susde.convertToAssets(susde.balanceOf(address(strategy))),
            (strategy.totalAssets() * uint256(_partBps)) / 1e4
        );
        assertEq(strategy.coolingUSDe(), 0);

        vm.prank(management);
        strategy.setDoHealthCheck(false);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        logStrategyInfo();

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(
            Math.max(strategy.profitMaxUnlockTime(), susde.cooldownDuration())
        );
        logStrategyInfo();

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.startPrank(user);
        strategy.redeem(_amount, user, user);
        vm.stopPrank();

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
        logStrategyInfo();
    }

    function test_auction_withCompletedCooldown(uint256 _amount) public {
        _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);

        vm.prank(management);
        strategy.setMaxAuctionAmount(type(uint88).max); // set to max value for this test

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        uint256 toAirdrop = susde.convertToShares(
            (_amount * (MAX_BPS + strategy.minSUSDeDiscountBps())) / MAX_BPS
        );
        airdrop(ERC20(address(susde)), address(strategy), toAirdrop);
        deal(address(asset), address(strategy), 0);

        vm.prank(keeper);
        strategy.tend();
        assertGt(strategy.coolingUSDe(), 0);

        skip(susde.cooldownDuration());

        logStrategyInfo();

        uint256 kickedAmount = strategy.kick(auctionId);
        assertGt(kickedAmount, _amount, "!kickedAmount");
        assertEq(asset.balanceOf(address(strategy)), 0);

        (, , , uint128 takeAvailable) = strategy.auctions(auctionId);

        uint256 steps = 1_440;
        uint256 skipBps = 0; //2500;

        skip((strategy.auctionLength() * skipBps) / 1e4); // immediately skip part of the auction
        for (uint256 i = 0; i < steps; ++i) {
            address buyer = address(62735);
            uint256 amountNeeded = strategy.getAmountNeeded(
                auctionId,
                takeAvailable
            );

            int256 surplusBps = ((int256(susde.convertToAssets(amountNeeded)) -
                int256(uint256(takeAvailable))) * 1e4) /
                int256(uint256(takeAvailable));

            if (surplusBps < 0) {
                revert("Auction failed");
                break;
            }

            if (
                surplusBps <= 200 &&
                surplusBps > int256(uint256(strategy.minSUSDeDiscountBps()))
            ) {
                airdrop(ERC20(address(susde)), buyer, amountNeeded);
                vm.prank(buyer);
                susde.approve(address(strategy), amountNeeded);

                // take the auction
                vm.prank(buyer);
                strategy.take(auctionId);
                break;
            }

            skip(((strategy.auctionLength() * (1e4 - skipBps)) / 1e4) / steps);
        }

        logStrategyInfo();
        assertEq(asset.balanceOf(address(strategy)), 0, "!idle");
        assertGt(
            susde.convertToAssets(susde.balanceOf(address(strategy))),
            strategy.totalAssets(),
            "!susde"
        );
        assertEq(strategy.coolingUSDe(), 0, "!cooling");

        vm.prank(management);
        strategy.setDoHealthCheck(false);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        logStrategyInfo();
        assertEq(asset.balanceOf(address(strategy)), 0, "!idle");
        assertEq(
            susde.convertToAssets(susde.balanceOf(address(strategy))),
            0,
            "!susde"
        );
        assertEq(strategy.coolingUSDe(), strategy.totalAssets(), "!cooling");

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(
            Math.max(strategy.profitMaxUnlockTime(), susde.cooldownDuration())
        );

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGt(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
        logStrategyInfo();
    }

    function test_auction_minAndMaxAmounts() public {
        uint256 _amount = 10_000e18;

        vm.expectRevert(); // below minimum
        strategy.kick(auctionId);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        logStrategyInfo();

        uint88 maxAuctionAmount = 5_000e18;
        vm.prank(management);
        strategy.setMaxAuctionAmount(maxAuctionAmount);

        uint256 kickedAmount = strategy.kick(auctionId);
        assertEq(kickedAmount, maxAuctionAmount, "!kickedAmount");
        assertEq(asset.balanceOf(address(strategy)), _amount);
    }

    function test_auction_settersRevert(
        uint256 _auctionStartingPrice,
        uint64 _auctionRangeSize,
        uint32 _auctionLength
    ) public {
        _auctionStartingPrice = bound(
            _auctionStartingPrice,
            1,
            type(uint256).max
        );
        _auctionRangeSize = uint64(
            bound(
                uint256(_auctionRangeSize),
                1,
                Math.min(_auctionStartingPrice, type(uint64).max)
            )
        );
        _auctionLength = uint32(
            bound(uint256(_auctionLength), 1, type(uint32).max)
        );

        uint256 _amount = maxFuzzAmount;

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        vm.startPrank(management);

        vm.expectRevert(bytes("!0"));
        strategy.setAuctionStartingPrice(0);

        vm.expectRevert(bytes("!0"));
        strategy.setAuctionRangeSize(0);

        vm.expectRevert(bytes("!0"));
        strategy.setAuctionLength(0);

        vm.expectRevert();
        strategy.setAuctionStartingPrice(uint256(1));

        vm.expectRevert();
        strategy.setAuctionRangeSize(type(uint64).max);

        uint256 kickedAmount = strategy.kick(auctionId);
        assertEq(kickedAmount, _amount, "!kickedAmount");

        vm.expectRevert();
        strategy.setAuctionStartingPrice(_auctionStartingPrice);

        vm.expectRevert();
        strategy.setAuctionRangeSize(_auctionRangeSize);

        vm.expectRevert();
        strategy.setAuctionLength(_auctionLength);

        skip(strategy.auctionLength() + 1);

        if (_auctionRangeSize > strategy.auctionStartingPrice()) {
            strategy.setAuctionStartingPrice(_auctionStartingPrice);
            assertEq(strategy.auctionStartingPrice(), _auctionStartingPrice);

            strategy.setAuctionRangeSize(_auctionRangeSize);
            assertEq(strategy.auctionRangeSize(), _auctionRangeSize);
        } else {
            strategy.setAuctionRangeSize(_auctionRangeSize);
            assertEq(strategy.auctionRangeSize(), _auctionRangeSize);

            strategy.setAuctionStartingPrice(_auctionStartingPrice);
            assertEq(strategy.auctionStartingPrice(), _auctionStartingPrice);
        }

        vm.stopPrank();
    }

    function test_auction_startingPriceAndStepSize(
        uint64 _auctionStartingPrice,
        uint64 _auctionRangeSize,
        uint32 _auctionLength
    ) public {
        _auctionStartingPrice = uint64(
            bound(uint256(_auctionStartingPrice), 1, 1e18)
        );
        _auctionRangeSize = uint64(
            bound(uint256(_auctionRangeSize), 1, _auctionStartingPrice)
        );
        _auctionLength = uint32(
            bound(uint256(_auctionLength), 1, type(uint32).max)
        );
        uint256 _amount = maxFuzzAmount;

        vm.startPrank(management);

        strategy.setAuctionRangeSize(_auctionRangeSize);
        assertEq(strategy.auctionRangeSize(), _auctionRangeSize);
        strategy.setAuctionStartingPrice(_auctionStartingPrice);
        assertEq(strategy.auctionStartingPrice(), _auctionStartingPrice);
        strategy.setAuctionLength(_auctionLength);
        assertEq(strategy.auctionLength(), _auctionLength);

        vm.stopPrank();

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        uint256 kickedAmount = strategy.kick(auctionId);
        assertEq(kickedAmount, _amount, "!kickedAmount");

        (, , , uint128 takeAvailable) = strategy.auctions(auctionId);

        uint256 amountNeeded = strategy.getAmountNeeded(
            auctionId,
            takeAvailable
        );
        assertEq(strategy.price(auctionId), _auctionStartingPrice);

        skip(1);
        assertEq(
            strategy.price(auctionId),
            _auctionStartingPrice - (_auctionRangeSize / _auctionLength)
        );

        skip(_auctionLength - 1);
        assertEq(
            strategy.price(auctionId),
            _auctionStartingPrice - _auctionRangeSize
        );
    }
}
