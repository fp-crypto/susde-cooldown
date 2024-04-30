// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IBaseAuctioneer} from "@periphery/Bases/Auctioneer/IBaseAuctioneer.sol";

interface IStrategyInterface is IBaseAuctioneer {
    function MAX_STRATEGY_PROXIES() external view returns (uint256);

    function auctionFactory() external view returns (address);

    function auction() external view returns (address);

    function maxTendBasefeeGwei() external view returns (uint64);

    function minCooldownAmount() external view returns (uint80);

    function minAuctionAmount() external view returns (uint80);

    function maxAuctionAmount() external view returns (uint88);

    function auctionRangeSize() external view returns (uint64);

    function minSUSDeDiscountBps() external view returns (uint16);

    function depositLimit() external view returns (uint256);

    function estimatedTotalAssets() external view returns (uint256);

    function coolingUSDe() external view returns (uint256);

    function strategyProxies(uint256 i) external view returns (address);

    function strategyProxyCount() external view returns (uint256);

    /**
     * @notice Sets the deposit limit. Can only be called by management
     * @param _depositLimit The deposit limit
     */
    function setDepositLimit(uint256 _depositLimit) external;

    /**
     * @notice Sets the max base fee for tends. Can only be called by management
     * @param _maxTendBasefeeGwei The maximum base fee allowed in gwei
     */
    function setMaxTendBasefeeGwei(uint16 _maxTendBasefeeGwei) external;

    /**
     * @notice Sets the min amount to be cooled down. Can only be called by management
     * @param _minCooldownAmount The minimum amount of sUSDe before a cooldown is triggered
     */
    function setMinCooldownAmount(uint80 _minCooldownAmount) external;

    /**
     * @notice Sets the min amount to be auctioned. Can only be called by management
     * @param _minAuctionAmount The minimum amount of USDe to auction
     */
    function setMinAuctionAmount(uint80 _minAuctionAmount) external;

    /**
     * @notice Sets the max amount to be auctioned. Can only be called by management
     * @param _maxAuctionAmount The maximum amount of USDe to auction
     */
    function setMaxAuctionAmount(uint88 _maxAuctionAmount) external;

    /**
     * @notice Sets the starting price for the auction. Can only be called by management
     * @param _auctionStartingPrice The price at which to start the auction
     */
    function setAuctionStartingPrice(uint256 _auctionStartingPrice) external;

    /**
     * @notice Sets the range for the auction. The auction will go from the starting price
     * to starting price minus auctionRangeSize. Can only be called by management
     * @param _auctionRangeSize The width of the range for the auction.
     */
    function setAuctionRangeSize(uint64 _auctionRangeSize) external;

    /**
     * @notice Sets the length of time an auction lasts. Can only be called by management
     * @param _auctionLength The length of the auction
     */
    function setAuctionLength(uint32 _auctionLength) external;

    /**
     * @notice Sets the min discount on sUSDe to accept. Can only be called by management
     * @param _minSUSDeDiscountBps The minimum discount in basis points when buying sUSDe
     */
    function setMinSUSDeDiscountBps(uint16 _minSUSDeDiscountBps) external;

    /**
     * @notice Sets the auction contract. Can only be called by emergency authorized
     * @param _auction The minimum auction contract address
     */
    function setAuction(address _auction) external;

    function addStrategyProxy() external;

    function recallFromProxy(address _proxy, address _token) external;

    function recallFromProxy(
        address _proxy,
        address _token,
        uint256 _amount
    ) external;

    function manualUnstakeSUSDe(address _proxy) external;

    function manualCooldownSUSDe(address _proxy, uint256 _amount) external;

    function sweep(address _token) external;
}
