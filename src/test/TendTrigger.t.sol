// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console.sol";
import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";

contract TendTriggerTest is Setup {
    function setUp() public virtual override {
        super.setUp();
        vm.prank(management);
        strategy.setMinCooldownAmount(50e18);
    }

    function test_tendTrigger(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        (bool trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        // false because nothing to do
        (trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);

        uint256 toAirdrop = susde.convertToShares(
            (_amount * (MAX_BPS + 100)) / MAX_BPS
        );
        airdrop(ERC20(address(susde)), address(strategy), toAirdrop);
        deal(address(asset), address(strategy), 0);

        // true because we can cooldown
        (trigger, ) = strategy.tendTrigger();
        assertTrue(trigger);

        // False due to fee too high
        vm.fee(strategy.maxTendBasefeeGwei() * 1e9 + 1);
        (trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);

        // True due to fee below max
        vm.fee(strategy.maxTendBasefeeGwei() * 1e9 - 1);
        (trigger, ) = strategy.tendTrigger();
        assertTrue(trigger);

        vm.prank(keeper);
        strategy.tend();

        // False just tended
        (trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);

        skip(susde.cooldownDuration());

        // true cooldown is complete
        (trigger, ) = strategy.tendTrigger();
        assertTrue(trigger);

        vm.prank(user);
        strategy.redeem(_amount, user, user);

        (trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);
    }
}
