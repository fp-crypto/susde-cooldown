// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console.sol";
import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";
import {Auction, AuctionFactory} from "@periphery/Auctions/AuctionFactory.sol";
import {ISUSDe} from "../interfaces/ethena/ISUSDe.sol";
import {AuctionTaker} from "../periphery/AuctionTaker.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

interface CurveRouter {
    function exchange(
        address[11] memory _route,
        uint256[5][5] memory _swap_params,
        uint256 _amount,
        uint256 _expected,
        address[5] memory _pools,
        address _receiver
    ) external payable returns (uint256);

    function get_dy(
        address[11] memory _route,
        uint256[5][5] memory _swap_params,
        uint256 _amount,
        address[5] memory _pools
    ) external view returns (uint256);
}

contract AuctionTakerTest is Setup {
    AuctionTaker taker;
    CurveRouter curveRouter =
        CurveRouter(0xF0d4c12A5768D806021F80a262B4d39d26C58b8D);

    function setUp() public virtual override {
        super.setUp();
        setFees(0, 0);
        vm.prank(management);
        strategy.setMinCooldownAmount(500e18);
        vm.prank(management);
        strategy.setMinSUSDeDiscountBps(0);
        taker = new AuctionTaker();
    }

    function test_auctionTaker_curve() public {
        uint256 _amount = 100_000e18;

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        uint256 kickedAmount = auction.kick(auctionId);
        assertEq(kickedAmount, _amount, "!kickedAmount");

        (, , address receiver, , uint128 takeAvailable) = auction.auctions(
            auctionId
        );

        console.log("startPrice: %e", auction.startingPrice());

        assertEq(receiver, address(strategy));

        uint256 steps = 7_200;
        uint256 skipBps = 0; //2500;

        uint256 auctionLength = auction.auctionLength();

        uint256 curveAmountOut = getCurveRouterAmountOut(takeAvailable);

        skip((auctionLength * skipBps) / 1e4); // immediately skip part of the auction
        for (uint256 i = 0; i < steps; ++i) {
            uint256 amountNeeded = auction.getAmountNeeded(
                auctionId,
                takeAvailable
            );

            console.log("bt: %i", block.timestamp);
            unchecked {
                console.log("er: %e", (amountNeeded * 1e18) / uint256(takeAvailable));
            }

            if (amountNeeded <= curveAmountOut) {
                console.log();
                console.log("i: %i", i);
                console.log("amountNeeded: %e", amountNeeded);
                console.log("takeAvailable: %e", takeAvailable);
                console.log("curveAmountOut: %e", curveAmountOut);
                console.log(susde.convertToAssets(amountNeeded));

                bytes memory curveRouterCallData = getCurveRouterCalldata(
                    takeAvailable,
                    amountNeeded
                );

                taker.take(
                    address(auction),
                    auctionId,
                    takeAvailable,
                    address(curveRouter),
                    curveRouterCallData
                );
                break;
            }

            skip(((auctionLength * (1e4 - skipBps)) / 1e4) / steps);
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

    function getCurveRouterAmountOut(uint256 amount)
        internal
        returns (uint256)
    {
        address[11] memory route;
        route[0] = address(asset);
        route[1] = 0x5dc1BF6f1e983C0b21EfB003c105133736fA0743;
        route[2] = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
        route[3] = 0xcE6431D21E3fb1036CE9973a3312368ED96F5CE7;
        route[4] = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
        route[5] = 0xc559f6716d8b1471Fc2DC10aAfEB0faa219fE9df;
        route[6] = address(susde);

        uint256[5][5] memory swap_params;
        swap_params[0] = [uint256(1), 0, 1, 1, 2];
        swap_params[1] = [uint256(0), 1, 1, 1, 2];
        swap_params[2] = [uint256(1), 0, 1, 1, 3];

        address[5] memory pools;
        pools[0] = 0x5dc1BF6f1e983C0b21EfB003c105133736fA0743;
        pools[1] = 0xcE6431D21E3fb1036CE9973a3312368ED96F5CE7;
        pools[2] = 0xc559f6716d8b1471Fc2DC10aAfEB0faa219fE9df;

        return curveRouter.get_dy(route, swap_params, amount, pools);
    }

    function getCurveRouterCalldata(uint256 amount, uint256 expected)
        internal
        returns (bytes memory curveRouterCallData)
    {
        address[11] memory route;
        route[0] = address(asset);
        route[1] = 0x5dc1BF6f1e983C0b21EfB003c105133736fA0743;
        route[2] = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
        route[3] = 0xcE6431D21E3fb1036CE9973a3312368ED96F5CE7;
        route[4] = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
        route[5] = 0xc559f6716d8b1471Fc2DC10aAfEB0faa219fE9df;
        route[6] = address(susde);

        uint256[5][5] memory swap_params;
        swap_params[0] = [uint256(1), 0, 1, 1, 2];
        swap_params[1] = [uint256(0), 1, 1, 1, 2];
        swap_params[2] = [uint256(1), 0, 1, 1, 3];

        address[5] memory pools;
        pools[0] = 0x5dc1BF6f1e983C0b21EfB003c105133736fA0743;
        pools[1] = 0xcE6431D21E3fb1036CE9973a3312368ED96F5CE7;
        pools[2] = 0xc559f6716d8b1471Fc2DC10aAfEB0faa219fE9df;

        curveRouterCallData = abi.encodeCall(
            curveRouter.exchange,
            (route, swap_params, amount, expected, pools, address(taker))
        );
    }
}
