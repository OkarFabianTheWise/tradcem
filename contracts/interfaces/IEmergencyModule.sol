// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IEmergencyModule
 * @dev Interface for emergency controls and circuit breakers
 */
interface IEmergencyModule {
    /**
     * @dev Check if emergency mode should be activated for a fund
     * @param fund Fund address
     * @return isEmergency Whether emergency mode is active
     */
    function isEmergency(address fund) external view returns (bool isEmergency);

    /**
     * @dev Enable emergency mode for a fund
     * @param fund Fund address
     */
    function enableEmergency(address fund) external;

    /**
     * @dev Disable emergency mode for a fund
     * @param fund Fund address
     */
    function disableEmergency(address fund) external;

    /**
     * @dev Emergency pause a fund
     * @param fund Fund address
     */
    function emergencyPause(address fund) external;

    /**
     * @dev Emergency unpause a fund
     * @param fund Fund address
     */
    function emergencyUnpause(address fund) external;
}