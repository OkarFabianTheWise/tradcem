// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "./TradCemFund.sol";

/**
 * @title FundFactory
 * @dev Deploys new TradCemFund contracts via CREATE2 for deterministic addresses
 */
contract FundFactory is Ownable {
    address[] public allFunds;
    mapping(address => address[]) public managerFunds;

    event FundCreated(
        address indexed fundAddress,
        address indexed manager,
        string name,
        string symbol,
        uint256 creationTime
    );

    /**
     * @dev Creates a new TradCemFund
     * @param name Fund name (ERC20 token name)
     * @param symbol Fund symbol (ERC20 token symbol)
     * @param manager Fund manager address
     * @param allowedAssets Array of allowed asset addresses
     * @param targetWeights Target allocation weights (basis points, sum to 10000)
     * @param priceOracle Address of the price oracle
     * @param dexRouter Address of the DEX router
     * @param feeCollector Address of the fee collector
     * @param rebalanceValidator Address of the rebalance validator
     * @param emergencyModule Address of the emergency module
     * @param managementFee Management fee in basis points (e.g., 200 = 2%)
     * @param performanceFee Performance fee in basis points (e.g., 2000 = 20%)
     * @param rebalanceInterval Minimum time between rebalances (seconds)
     * @param weightTolerance Weight drift tolerance in basis points
     * @param salt Salt for CREATE2 deployment
     */
    function createFund(
        string memory name,
        string memory symbol,
        address manager,
        address[] memory allowedAssets,
        uint256[] memory targetWeights,
        address priceOracle,
        address dexRouter,
        address feeCollector,
        address rebalanceValidator,
        address emergencyModule,
        uint256 managementFee,
        uint256 performanceFee,
        uint256 rebalanceInterval,
        uint256 weightTolerance,
        bytes32 salt
    ) external returns (address fundAddress) {
        require(manager != address(0), "Invalid manager");
        require(allowedAssets.length == targetWeights.length, "Assets/weights mismatch");
        require(allowedAssets.length > 0, "No assets specified");

        // Validate weights sum to 10000 (100%)
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < targetWeights.length; i++) {
            totalWeight += targetWeights[i];
        }
        require(totalWeight == 10000, "Weights must sum to 10000");

        // Encode constructor arguments
        bytes memory bytecode = abi.encodePacked(
            type(TradCemFund).creationCode,
            abi.encode(
                name,
                symbol,
                manager,
                allowedAssets,
                targetWeights,
                priceOracle,
                dexRouter,
                feeCollector,
                rebalanceValidator,
                emergencyModule,
                managementFee,
                performanceFee,
                rebalanceInterval,
                weightTolerance
            )
        );

        // Deploy using CREATE2
        fundAddress = Create2.deploy(0, salt, bytecode);

        // Register the fund
        allFunds.push(fundAddress);
        managerFunds[manager].push(fundAddress);

        emit FundCreated(fundAddress, manager, name, symbol, block.timestamp);
    }

    /**
     * @dev Gets all funds created by a manager
     */
    function getFundsByManager(address manager) external view returns (address[] memory) {
        return managerFunds[manager];
    }

    /**
     * @dev Gets total number of funds
     */
    function getFundCount() external view returns (uint256) {
        return allFunds.length;
    }

    /**
     * @dev Computes the address of a fund before deployment
     */
    function computeFundAddress(
        string memory name,
        string memory symbol,
        address manager,
        address[] memory allowedAssets,
        uint256[] memory targetWeights,
        address priceOracle,
        address dexRouter,
        address feeCollector,
        address rebalanceValidator,
        address emergencyModule,
        uint256 managementFee,
        uint256 performanceFee,
        uint256 rebalanceInterval,
        uint256 weightTolerance,
        bytes32 salt
    ) external view returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(TradCemFund).creationCode,
            abi.encode(
                name,
                symbol,
                manager,
                allowedAssets,
                targetWeights,
                priceOracle,
                dexRouter,
                feeCollector,
                rebalanceValidator,
                emergencyModule,
                managementFee,
                performanceFee,
                rebalanceInterval,
                weightTolerance
            )
        );

        return Create2.computeAddress(salt, keccak256(bytecode));
    }
}