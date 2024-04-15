// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console.sol";
import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract OperationTest is Setup {
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
        // TODO: add additional check on strat params
    }

    function test_operation(uint256 _amount) public {
        _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest
        skip(1 days);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

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

    function test_profitableReport(uint256 _amount, uint16 _profitFactor)
        public
    {
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

    function test_profitableReport_multipleProxies(
        uint256 _amount,
        uint16 _profitFactor,
        uint8 _proxyCount
    ) public {
        _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);
        _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS));
        _proxyCount = uint8(bound(uint256(_proxyCount), 1, 7));

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);
        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        uint256 totalAirdrop = susde.convertToShares(
            (_amount * (MAX_BPS + _profitFactor)) / MAX_BPS
        );

        for (uint8 i = 1; i < _proxyCount; ++i) {
            // we already have one
            vm.prank(management);
            strategy.addStrategyProxy();

            uint256 toAirdrop = totalAirdrop / _proxyCount;

            airdrop(ERC20(address(susde)), address(strategy), toAirdrop);
            deal(
                address(asset),
                address(strategy),
                asset.balanceOf(address(strategy)) - (_amount / 7)
            );

            logStrategyInfo();

            // Report profit
            vm.prank(keeper);
            (uint256 profit, uint256 loss) = strategy.report();

            logStrategyInfo();

            // Check return Values
            assertGe(
                profit,
                susde.convertToAssets(toAirdrop) - (_amount / 7),
                "!profit"
            );
            assertEq(loss, 0, "!loss");

            skip(1 days); // skip 1 day
        }

        assertEq(strategy.strategyProxyCount(), _proxyCount, "!proxyCount");

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
}
