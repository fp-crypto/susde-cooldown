// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import "forge-std/console.sol";
import {ExtendedTest} from "./ExtendedTest.sol";

import {Strategy, ERC20} from "../../Strategy.sol";
import {IStrategyInterface} from "../../interfaces/IStrategyInterface.sol";
import {Auction, AuctionFactory} from "@periphery/Auctions/AuctionFactory.sol";
import {ISUSDe} from "../../interfaces/ethena/ISUSDe.sol";

// Inherit the events so they can be checked if desired.
import {IEvents} from "@tokenized-strategy/interfaces/IEvents.sol";

interface IFactory {
    function governance() external view returns (address);

    function set_protocol_fee_bps(uint16) external;

    function set_protocol_fee_recipient(address) external;
}

contract Setup is ExtendedTest, IEvents {
    // Contract instances that we will use repeatedly.
    ERC20 public asset;
    IStrategyInterface public strategy;
    ISUSDe susde;

    Auction public auction;
    bytes32 public auctionId;

    mapping(string => address) public tokenAddrs;

    // Addresses for different roles we will use repeatedly.
    address public user = address(10);
    address public keeper = address(4);
    address public management = address(1);
    address public performanceFeeRecipient = address(3);

    // Address of the real deployed Factory
    address public factory;

    // Integer variables that will be used repeatedly.
    uint256 public decimals;
    uint256 public MAX_BPS = 10_000;

    // Fuzz from $0.01 of 1e6 stable coins up to 1 trillion of a 1e18 coin
    uint256 public maxFuzzAmount = 100_000e18;
    uint256 public minFuzzAmount = 1_000e18;

    // Default profit max unlock time is set for 10 days
    uint256 public profitMaxUnlockTime = 10 days;

    function setUp() public virtual {
        _setTokenAddrs();

        // Set asset
        asset = ERC20(tokenAddrs["USDE"]);
        susde = ISUSDe(tokenAddrs["SUSDE"]);

        // Set decimals
        decimals = asset.decimals();

        // Deploy strategy and set variables
        strategy = IStrategyInterface(setUpStrategy());

        // Setup auction
        (auction, auctionId) = setUpAuction(strategy);

        factory = strategy.FACTORY();

        // label all the used addresses for traces
        vm.label(keeper, "keeper");
        vm.label(factory, "factory");
        vm.label(address(asset), "USDe");
        vm.label(management, "management");
        vm.label(address(strategy), "strategy");
        vm.label(performanceFeeRecipient, "performanceFeeRecipient");
        vm.label(tokenAddrs["SUSDE"], "sUSDe");
        vm.label(address(auction), "auction");
    }

    function setUpStrategy() public returns (address) {
        // we save the strategy as a IStrategyInterface to give it the needed interface
        IStrategyInterface _strategy = IStrategyInterface(
            address(new Strategy("Tokenized Strategy"))
        );

        // set keeper
        _strategy.setKeeper(keeper);
        // set treasury
        _strategy.setPerformanceFeeRecipient(performanceFeeRecipient);
        _strategy.setDepositLimit(type(uint256).max);
        // set management of the strategy
        _strategy.setPendingManagement(management);

        vm.prank(management);
        _strategy.acceptManagement();

        return address(_strategy);
    }

    function setUpAuction(IStrategyInterface _strategy)
        public
        returns (Auction _auction, bytes32 _auctionId)
    {
        vm.startPrank(management);
        AuctionFactory _auctionFactory = AuctionFactory(
            _strategy.auctionFactory()
        );
        _auction = Auction(
            _auctionFactory.createNewAuction(
                tokenAddrs["SUSDE"],
                address(_strategy)
            )
        );
        _auctionId = _auction.enable(_strategy.asset(), address(_strategy));
        _auction.setHookFlags(true, true, true, false);

        _strategy.setAuction(address(_auction));
        vm.stopPrank();
    }

    function depositIntoStrategy(
        IStrategyInterface _strategy,
        address _user,
        uint256 _amount
    ) public {
        vm.prank(_user);
        asset.approve(address(_strategy), _amount);

        vm.prank(_user);
        _strategy.deposit(_amount, _user);
    }

    function mintAndDepositIntoStrategy(
        IStrategyInterface _strategy,
        address _user,
        uint256 _amount
    ) public {
        airdrop(asset, _user, _amount);
        depositIntoStrategy(_strategy, _user, _amount);
    }

    // For checking the amounts in the strategy
    function checkStrategyTotals(
        IStrategyInterface _strategy,
        uint256 _totalAssets,
        uint256 _totalDebt,
        uint256 _totalIdle
    ) public {
        uint256 _assets = _strategy.totalAssets();
        uint256 _balance = ERC20(_strategy.asset()).balanceOf(
            address(_strategy)
        );
        uint256 _idle = _balance > _assets ? _assets : _balance;
        uint256 _debt = _assets - _idle;
        assertEq(_assets, _totalAssets, "!totalAssets");
        assertEq(_debt, _totalDebt, "!totalDebt");
        assertEq(_idle, _totalIdle, "!totalIdle");
        assertEq(_totalAssets, _totalDebt + _totalIdle, "!Added");
    }

    function airdrop(
        ERC20 _asset,
        address _to,
        uint256 _amount
    ) public {
        uint256 balanceBefore = _asset.balanceOf(_to);
        deal(address(_asset), _to, balanceBefore + _amount);
    }

    function setFees(uint16 _protocolFee, uint16 _performanceFee) public {
        address gov = IFactory(factory).governance();

        // Need to make sure there is a protocol fee recipient to set the fee.
        vm.prank(gov);
        IFactory(factory).set_protocol_fee_recipient(gov);

        vm.prank(gov);
        IFactory(factory).set_protocol_fee_bps(_protocolFee);

        vm.prank(management);
        strategy.setPerformanceFee(_performanceFee);
    }

    function logStrategyInfo() internal view {
        console.log();
        console.log("==== Strategy Info ====");
        console.log("ETA: %e", strategy.estimatedTotalAssets());
        console.log("Total Assets: %e", strategy.totalAssets());
        console.log(
            "Total Idle: %e",
            ERC20(asset).balanceOf(address(strategy))
        );
        console.log(
            "Total sUSDe: %e",
            ERC20(tokenAddrs["SUSDE"]).balanceOf(address(strategy))
        );
        console.log(
            "Total cooling: %e",
            strategy.coolingUSDe()
        );
    }

    function _setTokenAddrs() internal {
        tokenAddrs["USDE"] = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
        tokenAddrs["SUSDE"] = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
        tokenAddrs["ENA"] = 0x57e114B691Db790C35207b2e685D4A43181e6061;
    }
}
