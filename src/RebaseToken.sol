// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title RebaseToken
 * @author Jason Suarez
 * @notice This is a cross-chain rebase token to incentivize users to deposit assets into a vault and gain interest
 * @notice Each user has its own interest rate
 * @dev The interest rate can only decrease to incentivize/reward early users
 */
contract RebaseToken is ERC20 {
    ///////////////////
    // Errors
    ///////////////////
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private s_interestRate = 5e10;

    uint256 private constant PRECISION = 1e18;

    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdated;
    mapping(address => uint256) private s_userPrincipleBalance;

    ///////////////////
    // Events
    ///////////////////
    event InterestRateChanged(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") {}

    /////////////////////////////
    /// External & Public
    /////////////////////////////

    /**
     * Set the interest rate
     * @param newInterestRate The new interest rate
     * @notice The interest rate can only decrease to incentivize/reward early users
     */
    function setInterestRate(uint256 newInterestRate) external {
        if (newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, newInterestRate);
        }
        s_interestRate = newInterestRate;
        emit InterestRateChanged(newInterestRate);
    }

    /**
     *
     * @param to address to mint tokens to
     * @param amount  amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        _mintAccrueInterest(to);
        s_userInterestRate[to] = s_interestRate;
        _mint(to, amount);
    }

    /**
     * @notice Amount of tokens that have been minted to the user + interest
     * @param user address of the user
     */
    function balanceOf(address user) public view override returns (uint256) {
        return (super.balanceOf(user) + _calculateUserAccumulatedInterestSinceLastUpdated(user) / PRECISION);
    }

    /////////////////////////////
    /// Internal
    /////////////////////////////

    /**
     * @notice Mint tokens to the user and accrue interest
     * @param to address to mint tokens to
     */
    function _mintAccrueInterest(address to) internal {
        // Principle balance : balance of rebase token that has been minted
        // Current balance including interest => balanceOf
        // amount of tokens that need to be minted => balanceOf - principle balance
        // Call mint
        // Set the users last updated time
        s_userLastUpdated[to] = block.timestamp;
    }

    /**
     * @notice Calculate the amount of interest that has been accrued since the last time the user updated
     * @param user address of the user
     * @return uint256 amount of interest that has been accrued since the last time the user updated
     */
    function _calculateUserAccumulatedInterestSinceLastUpdated(address user) internal view returns (uint256) {
        uint256 timeSinceLastUpdated = block.timestamp - s_userLastUpdated[user];

        return ((s_userInterestRate[user] * timeSinceLastUpdated) * PRECISION);
    }

    /////////////////////
    /// Getter Functions
    /////////////////////

    /**
     * @notice Get the current interest rate
     * @param user  address of the user
     */
    function getUserInterestRate(address user) external view returns (uint256) {
        return s_userInterestRate[user];
    }

    /**
     * @notice Get the current interest rate
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }
}
