// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IFeeCollector
 * @dev Interface for fee collection and distribution
 */
interface IFeeCollector {
    /**
     * @dev Collect management fee from a fund
     * @param fund Fund address
     * @return feeAmount Amount of fees collected
     */
    function collectManagementFee(address fund) external returns (uint256 feeAmount);

    /**
     * @dev Collect performance fee from a fund
     * @param fund Fund address
     * @return feeAmount Amount of fees collected
     */
    function collectPerformanceFee(address fund) external returns (uint256 feeAmount);

    /**
     * @dev Withdraw accumulated fees
     * @param token Token address to withdraw
     */
    function withdrawFees(address token) external;
}