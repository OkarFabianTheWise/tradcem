// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IEmergencyModule.sol";

/**
 * @title EmergencyModule
 * @dev Circuit breakers and emergency functions
 */
contract EmergencyModule is IEmergencyModule, Ownable {
    mapping(address => bool) public emergencyMode;
    mapping(address => bool) public pausedFunds;

    address public multisig; // Emergency multisig
    uint256 public constant EMERGENCY_THRESHOLD = 50; // 50% price drop threshold

    mapping(address => uint256) public lastKnownPrices;
    mapping(address => uint256) public priceCheckTimestamps;

    event EmergencyActivated(address indexed fund, string reason);
    event EmergencyDeactivated(address indexed fund);
    event FundPaused(address indexed fund);
    event FundUnpaused(address indexed fund);

    constructor(address _multisig) {
        require(_multisig != address(0), "Invalid multisig");
        multisig = _multisig;
    }

    /**
     * @dev Check if emergency mode should be activated for a fund
     */
    function isEmergency(address fund) external view override returns (bool) {
        if (emergencyMode[fund]) return true;

        // Check for oracle failure (price not updated recently)
        if (block.timestamp - priceCheckTimestamps[fund] > 3600) { // 1 hour
            return true;
        }

        // Check for extreme price movements
        // This would require integration with price oracle
        // For now, return false

        return false;
    }

    /**
     * @dev Enable emergency mode for a fund
     */
    function enableEmergency(address fund) external override {
        require(msg.sender == owner() || msg.sender == multisig, "Not authorized");

        emergencyMode[fund] = true;
        emit EmergencyActivated(fund, "Manual activation");
    }

    /**
     * @dev Disable emergency mode for a fund
     */
    function disableEmergency(address fund) external override onlyOwner {
        emergencyMode[fund] = false;
        emit EmergencyDeactivated(fund);
    }

    /**
     * @dev Emergency pause a fund
     */
    function emergencyPause(address fund) external override {
        require(msg.sender == owner() || msg.sender == multisig, "Not authorized");
        require(!pausedFunds[fund], "Already paused");

        pausedFunds[fund] = true;
        emit FundPaused(fund);
    }

    /**
     * @dev Emergency unpause a fund
     */
    function emergencyUnpause(address fund) external override onlyOwner {
        require(pausedFunds[fund], "Not paused");

        pausedFunds[fund] = false;
        emit FundUnpaused(fund);
    }

    /**
     * @dev Update multisig address
     */
    function updateMultisig(address newMultisig) external onlyOwner {
        require(newMultisig != address(0), "Invalid multisig");
        multisig = newMultisig;
    }

    /**
     * @dev Check if a fund is paused
     */
    function isPaused(address fund) external view returns (bool) {
        return pausedFunds[fund];
    }

    /**
     * @dev Update price check timestamp (called by funds)
     */
    function updatePriceCheck(address fund) external {
        // Only funds should call this
        priceCheckTimestamps[fund] = block.timestamp;
    }

    /**
     * @dev Emergency withdrawal for stuck funds
     */
    function emergencyWithdraw(
        address fund,
        address token,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        require(emergencyMode[fund], "Not in emergency mode");

        // This would require the fund to have emergency withdrawal functions
        // For now, this is a placeholder
        revert("Emergency withdrawal not implemented");
    }
}