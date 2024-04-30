pragma solidity ^0.8.18;

import {Governance} from "@periphery/utils/Governance.sol";
import {ERC20} from "@tokenized-strategy/BaseStrategy.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ISUSDe, UserCooldown} from "./interfaces/ethena/ISUSDe.sol";

contract StrategyProxy is Governance {
    using SafeERC20 for ERC20;

    ISUSDe private constant SUSDE =
        ISUSDe(0x9D39A5DE30e57443BfF2A8307A4256c8797A3497);
    bool private original;

    constructor(address _strategy) Governance(_strategy) {
        original = true;
    }

    function initialize(address _strategy) external {
        require(address(governance) == address(0), "!initialized");
        governance = _strategy;
        emit GovernanceTransferred(address(0), _strategy);
    }

    /*//////////////////////////////////////////////////////////////
                          External Actions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initiates cooldown of sUSDe
     * @return . Amount of asset that will be released after cooldown
     */
    function cooldownSUSDe() external onlyGovernance returns (uint256) {
        return _cooldownSUSDe();
    }

    /**
     * @notice Unstakes cooldowned sUSDe and returns it to governance
     */
    function unstakeSUSDe() external onlyGovernance {
        SUSDE.unstake(governance);
    }

    /**
     * @notice Recalls the ERC20 tokens to governance
     * @param _token  The token to recall
     */
    function recall(address _token) external onlyGovernance {
        _recall(_token, ERC20(_token).balanceOf(address(this)));
    }

    /**
     * @notice Recalls the ERC20 tokens to governance
     * @param _token  The token to recall
     * @param _amount The amount to recall
     */
    function recall(address _token, uint256 _amount) external onlyGovernance {
        _recall(_token, _amount);
    }

    /**
     * @notice Clones this StrategyProxy
     */
    function clone() external returns (address _newStrategyProxy) {
        return _clone();
    }

    /*//////////////////////////////////////////////////////////////
                          Internal Actions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initiates cooldown of sUSDe
     * @return . Amount of asset that will be released after cooldown
     */
    function _cooldownSUSDe() internal returns (uint256) {
        uint256 sharesToCooldown = Math.min(
            SUSDE.balanceOf(address(this)),
            SUSDE.maxRedeem(address(this))
        );
        return SUSDE.cooldownShares(sharesToCooldown);
    }

    /**
     * @notice Unstakes cooldowned sUSDe and returns it to governance
     */
    function _unstakeSUSDe() internal {
        SUSDE.unstake(governance);
    }

    /**
     * @notice Recalls the specified amount of asset to the governing address
     * @param _token  Address of the token to recall
     * @param _amount Amount token to recall
     */
    function _recall(address _token, uint256 _amount) internal {
        ERC20(_token).safeTransfer(governance, _amount);
    }

    event Cloned(address indexed clone);

    /**
     * @notice Clones this StrategyProxy if it's the original
     */
    function _clone() internal returns (address _newStrategyProxy) {
        require(original, "!og"); // dev: not original

        // Copied from https://github.com/optionality/clone-factory/blob/master/contracts/CloneFactory.sol
        bytes20 addressBytes = bytes20(address(this));

        assembly {
            // EIP-1167 bytecode
            let clone_code := mload(0x40)
            mstore(
                clone_code,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone_code, 0x14), addressBytes)
            mstore(
                add(clone_code, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            _newStrategyProxy := create(0, clone_code, 0x37)
        }

        StrategyProxy(_newStrategyProxy).initialize(governance);
        emit Cloned(_newStrategyProxy);
    }
}
