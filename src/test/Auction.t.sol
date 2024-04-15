// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console.sol";
import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";
import {Auction, AuctionFactory} from "@periphery/Auctions/AuctionFactory.sol";
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

        auction.kick(auctionId);

        (, , address receiver, , uint128 takeAvailable) = auction.auctions(
            auctionId
        );

        assertEq(receiver, address(strategy));

        uint256 steps = 7_200;
        uint256 skipBps = 0; //2500;

        uint256 stakingRate = susde.convertToAssets(1e18);
        console.log("sr: %e", stakingRate);

        skip((auction.auctionLength() * skipBps) / 1e4); // immediately skip part of the auction
        for (uint256 i = 0; i < steps; ++i) {
            address buyer = address(62735);
            uint256 amountNeeded = auction.getAmountNeeded(
                auctionId,
                takeAvailable
            );
            uint256 rate = (amountNeeded * 1e18) / uint256(takeAvailable);

            int256 surplusBps = ((int256(susde.convertToAssets(amountNeeded)) -
                int256(uint256(takeAvailable))) * 1e4) /
                int256(uint256(takeAvailable));

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
                susde.approve(address(auction), amountNeeded);

                // take the auction
                vm.prank(buyer);
                auction.take(auctionId);
                break;
            }

            skip(((auction.auctionLength() * (1e4 - skipBps)) / 1e4) / steps);
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

        auction.kick(auctionId);

        (, , address receiver, , uint128 takeAvailable) = auction.auctions(
            auctionId
        );

        assertEq(receiver, address(strategy));

        uint256 steps = 7_200;
        uint256 skipBps = 0; //2500;

        uint256 stakingRate = susde.convertToAssets(1e18);
        console.log("sr: %e", stakingRate);

        skip((auction.auctionLength() * skipBps) / 1e4); // immediately skip part of the auction
        for (uint256 i = 0; i < steps; ++i) {
            address buyer = address(62735);
            uint256 amountNeeded = auction.getAmountNeeded(
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
                susde.approve(address(auction), amountNeeded);

                // take the auction
                vm.startPrank(buyer);
                vm.expectRevert();
                auction.take(auctionId);
                vm.stopPrank();
                break;
            }

            skip(((auction.auctionLength() * (1e4 - skipBps)) / 1e4) / steps);
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

    function test_auction_partiallyTake(uint256 _amount, uint16 _partBps)
        public
    {
        _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);
        _partBps = uint16(bound(uint256(_partBps), 1000, 9000)); // between 10% and 90%

        vm.prank(management);
        strategy.setMinCooldownAmount(1e18); // set minCooldown to be very small

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        auction.kick(auctionId);

        (, , address receiver, , uint128 takeAvailable) = auction.auctions(
            auctionId
        );

        assertEq(receiver, address(strategy));

        uint256 steps = 7_200;
        uint256 skipBps = 0; //2500;

        uint256 stakingRate = susde.convertToAssets(1e18);

        skip((auction.auctionLength() * skipBps) / 1e4); // immediately skip part of the auction
        for (uint256 i = 0; i < steps; ++i) {
            address buyer = address(62735);
            uint256 amountNeeded = auction.getAmountNeeded(
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
                susde.approve(address(auction), amountNeeded);

                // take the auction
                vm.prank(buyer);
                auction.take(
                    auctionId,
                    (uint256(takeAvailable) * uint256(_partBps)) / 1e4
                );
                console.log("take");
                break;
            }

            skip(((auction.auctionLength() * (1e4 - skipBps)) / 1e4) / steps);
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
        strategy.redeem(
            _amount,
            user,
            user
        );
        vm.stopPrank();

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
        logStrategyInfo();
    }
}
