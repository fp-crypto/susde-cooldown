// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IBaseHealthCheck} from "@periphery/Bases/HealthCheck/IBaseHealthCheck.sol";

interface IStrategyInterface is IBaseHealthCheck {
    function auctionFactory() external view returns (address);

    function auction() external view returns (address);

    function maxTendBasefee() external view returns (uint64);

    function minCooldownAmount() external view returns (uint80);

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
     * @param _maxTendBasefee The maximum base fee allowed
     */
    function setMaxTendBasefee(uint64 _maxTendBasefee) external;

    /**
     * @notice Sets the min amount to be cooled down. Can only be called by management
     * @param _minCooldownAmount The minimum amount of sUSDe before a cooldown is triggered
     */
    function setMinCooldownAmount(uint80 _minCooldownAmount) external;

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

    function recallFromProxy(
        address _proxy,
        address _token,
        uint256 _amount
    ) external;

    function manualUnstakeSUSDe(address _proxy) external;

    function manualCooldownSUSDe(address _proxy, uint256 _amount) external;
}
