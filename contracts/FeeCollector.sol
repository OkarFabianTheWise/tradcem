// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IFeeCollector.sol";

/**
 * @title FeeCollector
 * @dev Separate fee accounting and distribution
 */
contract FeeCollector is IFeeCollector, Ownable, ReentrancyGuard {
    mapping(address => uint256) public accruedFees;
    mapping(address => mapping(address => uint256)) public fundFees; // fund => token => amount

    address[] public supportedTokens;
    mapping(address => bool) public isSupportedToken;

    event FeeCollected(address indexed fund, address indexed token, uint256 amount);
    event FeeWithdrawn(address indexed token, uint256 amount, address indexed recipient);

    /**
     * @dev Collect management fee from a fund
     */
    function collectManagementFee(address fund) external override nonReentrant returns (uint256 feeAmount) {
        // This would be called by the fund contract
        // For now, return 0 as funds handle their own fee accrual
        return 0;
    }

    /**
     * @dev Collect performance fee from a fund
     */
    function collectPerformanceFee(address fund) external override nonReentrant returns (uint256 feeAmount) {
        // This would be called by the fund contract
        // For now, return 0 as funds handle their own fee accrual
        return 0;
    }

    /**
     * @dev Withdraw accumulated fees
     */
    function withdrawFees(address token) external override onlyOwner nonReentrant {
        uint256 amount = accruedFees[token];
        require(amount > 0, "No fees to withdraw");

        accruedFees[token] = 0;
        require(IERC20(token).transfer(owner(), amount), "Transfer failed");

        emit FeeWithdrawn(token, amount, owner());
    }

    /**
     * @dev Add support for a fee token
     */
    function addSupportedToken(address token) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(!isSupportedToken[token], "Token already supported");

        supportedTokens.push(token);
        isSupportedToken[token] = true;
    }

    /**
     * @dev Remove support for a fee token
     */
    function removeSupportedToken(address token) external onlyOwner {
        require(isSupportedToken[token], "Token not supported");

        isSupportedToken[token] = false;

        // Remove from array
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == token) {
                supportedTokens[i] = supportedTokens[supportedTokens.length - 1];
                supportedTokens.pop();
                break;
            }
        }
    }

    /**
     * @dev Get total accrued fees for a token
     */
    function getAccruedFees(address token) external view returns (uint256) {
        return accruedFees[token];
    }

    /**
     * @dev Get fees accrued by a specific fund
     */
    function getFundFees(address fund, address token) external view returns (uint256) {
        return fundFees[fund][token];
    }

    /**
     * @dev Get number of supported tokens
     */
    function getSupportedTokensCount() external view returns (uint256) {
        return supportedTokens.length;
    }

    /**
     * @dev Internal function to record fee collection
     */
    function _recordFee(address fund, address token, uint256 amount) internal {
        accruedFees[token] += amount;
        fundFees[fund][token] += amount;

        emit FeeCollected(fund, token, amount);
    }
}