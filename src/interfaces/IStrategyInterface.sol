// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";

interface IStrategyInterface is IStrategy {
    function maxTendBasefee() external returns (uint64);

    function minCooldownAmount() external returns (uint80);

    function minSUSDeDiscountBps() external returns (uint16);

    function depositLimit() external returns (uint256);

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
}
