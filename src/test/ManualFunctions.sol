// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console.sol";
import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract ManualFunctionsTest is Setup {
    function setUp() public virtual override {
        super.setUp();
        vm.prank(management);
        strategy.setMinCooldownAmount(uint80((minFuzzAmount * 10) / MAX_BPS)); // set to the minimum possible amount
    }

    function test_setupStrategyOK() public {
        console.log("address of strategy", address(strategy));
        assertTrue(address(0) != address(strategy));
        assertEq(strategy.asset(), address(asset));
        assertEq(strategy.management(), management);
        assertEq(strategy.performanceFeeRecipient(), performanceFeeRecipient);
        assertEq(strategy.keeper(), keeper);
    }

    function test_manualUnstake(uint256 _amount, uint16 _profitFactor) public {
        _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);
        _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS));

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest
        skip(1 days);

        uint256 toAirdrop = susde.convertToShares(
            (_amount * (MAX_BPS + _profitFactor)) / MAX_BPS
        );
        airdrop(ERC20(address(susde)), address(strategy), toAirdrop);
        deal(address(asset), address(strategy), 0);

        logStrategyInfo();

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        logStrategyInfo();

        // Check return Values
        assertApproxEq(
            profit,
            susde.convertToAssets(toAirdrop) - _amount,
            1e6,
            "!profit"
        );
        assertEq(loss, 0, "!loss");

        skip(
            Math.max(strategy.profitMaxUnlockTime(), susde.cooldownDuration())
        );

        logStrategyInfo();

        assertEq(asset.balanceOf(address(strategy)), 0);
        assertGt(strategy.coolingUSDe(), _amount);

        address strategyProxy = strategy.strategyProxies(0);

        vm.expectRevert("!emergency authorized");
        strategy.manualUnstakeSUSDe(strategyProxy);

        vm.prank(management);
        strategy.manualUnstakeSUSDe(strategyProxy);

        logStrategyInfo();

        assertGt(asset.balanceOf(address(strategy)), _amount);
        assertEq(strategy.coolingUSDe(), 0);

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }

    function test_manualCooldown(uint256 _amount, uint16 _profitFactor) public {
        _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);
        _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS));

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest
        skip(1 days);

        uint256 toAirdrop = susde.convertToShares(
            (_amount * (MAX_BPS + _profitFactor)) / MAX_BPS
        );
        airdrop(ERC20(address(susde)), address(strategy), toAirdrop);
        deal(address(asset), address(strategy), 0);

        logStrategyInfo();

        assertEq(asset.balanceOf(address(strategy)), 0);
        assertGe(
            susde.balanceOf(address(strategy)),
            susde.convertToShares(_amount)
        );
        assertEq(strategy.coolingUSDe(), 0);

        address strategyProxy = strategy.strategyProxies(0);
        uint256 cooldownAmount = susde.balanceOf(address(strategy));

        vm.expectRevert("!emergency authorized");
        strategy.manualCooldownSUSDe(strategyProxy, cooldownAmount);

        vm.prank(management);
        strategy.manualCooldownSUSDe(strategyProxy, cooldownAmount);

        logStrategyInfo();

        assertEq(asset.balanceOf(address(strategy)), 0);
        assertEq(susde.balanceOf(address(strategy)), 0);
        assertEq(strategy.coolingUSDe(), susde.convertToAssets(cooldownAmount));

        skip(
            Math.max(strategy.profitMaxUnlockTime(), susde.cooldownDuration())
        );

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }

    function test_recallAmount(uint256 _amount, uint256 _recallAmount) public {
        _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);
        _recallAmount = bound(_recallAmount, minFuzzAmount, maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        logStrategyInfo();

        assertEq(asset.balanceOf(address(strategy)), _amount);
        assertEq(susde.balanceOf(address(strategy)), 0);
        assertEq(strategy.coolingUSDe(), 0);

        address strategyProxy = strategy.strategyProxies(0);

        airdrop(asset, strategyProxy, _recallAmount);

        vm.expectRevert("!emergency authorized");
        strategy.recallFromProxy(strategyProxy, address(asset), _recallAmount);

        vm.prank(management);
        strategy.recallFromProxy(strategyProxy, address(asset), _recallAmount);

        logStrategyInfo();

        assertEq(asset.balanceOf(address(strategy)), _amount + _recallAmount);
        assertEq(susde.balanceOf(address(strategy)), 0);
        assertEq(strategy.coolingUSDe(), 0);

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }

    function test_recall(uint256 _amount, uint256 _recallAmount) public {
        _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);
        _recallAmount = bound(_recallAmount, minFuzzAmount, maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        logStrategyInfo();

        assertEq(asset.balanceOf(address(strategy)), _amount);
        assertEq(susde.balanceOf(address(strategy)), 0);
        assertEq(strategy.coolingUSDe(), 0);

        address strategyProxy = strategy.strategyProxies(0);

        airdrop(asset, strategyProxy, _recallAmount);

        vm.expectRevert("!emergency authorized");
        strategy.recallFromProxy(strategyProxy, address(asset));

        vm.prank(management);
        strategy.recallFromProxy(strategyProxy, address(asset));

        logStrategyInfo();

        assertEq(asset.balanceOf(address(strategy)), _amount + _recallAmount);
        assertEq(susde.balanceOf(address(strategy)), 0);
        assertEq(strategy.coolingUSDe(), 0);

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }
}
