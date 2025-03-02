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
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author Jason Suarez
 * @notice This is a cross-chain rebase token to incentivize users to deposit assets into a vault and gain interest
 * @notice Each user has its own interest rate
 * @dev The interest rate can only decrease to incentivize/reward early users
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    ///////////////////
    // Errors
    ///////////////////
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private s_interestRate = 5e10;

    uint256 private constant PRECISION = 1e18;

    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

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

    function grantMintAndBurnRole(address account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, account);
    }

    /**
     * Set the interest rate
     * @param newInterestRate The new interest rate
     * @notice The interest rate can only decrease to incentivize/reward early users
     */
    function setInterestRate(uint256 newInterestRate) external onlyOwner {
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
    function mint(address to, uint256 amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccrueInterest(to);
        s_userInterestRate[to] = s_interestRate;
        _mint(to, amount);
    }

    /**
     *  Burn tokens from the user
     * @param from address to burn tokens from
     * @param amount  amount of tokens to burn
     * @dev If amount is max, burn all tokens (common pattern used to avoid dust)
     */
    function burn(address from, uint256 amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if (amount == type(uint256).max) {
            amount = balanceOf(from);
        }
        _mintAccrueInterest(from);
        _burn(from, amount);
    }

    /**
     * @notice Amount of tokens that have been minted to the user + interest
     * @param user address of the user
     */
    function balanceOf(address user) public view override returns (uint256) {
        uint256 balance = super.balanceOf(user);
        if (balance == 0) {
            return 0;
        }
        return (balance * _calculateUserAccumulatedInterestSinceLastUpdated(user) / PRECISION);
    }

    /**
     * Transfer tokens from the user to another user
     * @param to  address to transfer tokens to
     * @param amount  amount of tokens to transfer
     * @return bool true if the transfer was successful
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        _mintAccrueInterest(to);
        _mintAccrueInterest(msg.sender);
        if (amount == type(uint256).max) {
            amount = balanceOf(msg.sender);
        }
        if (balanceOf(to) == 0) {
            s_userInterestRate[to] = s_userInterestRate[msg.sender];
        }

        return super.transfer(to, amount);
    }

    /**
     * Transfer tokens from the user to another user
     * @param from  address to transfer tokens from
     * @param to  address to transfer tokens to
     * @param amount  amount of tokens to transfer
     * @return bool true if the transfer was successful
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _mintAccrueInterest(to);
        _mintAccrueInterest(from);
        if (amount == type(uint256).max) {
            amount = balanceOf(from);
        }
        if (balanceOf(to) == 0) {
            s_userInterestRate[to] = s_userInterestRate[from];
        }
        return super.transferFrom(from, to, amount);
    }

    /////////////////////////////
    /// Internal
    /////////////////////////////

    /**
     * @notice Calculates and mints tokens accrue interest tokens to the user and update the last updated time
     * @param to address to mint tokens to
     */
    function _mintAccrueInterest(address to) internal {
        uint256 principleBalance = super.balanceOf(to);
        uint256 principleBalanceWithInterest = balanceOf(to);
        uint256 amountToMint = principleBalanceWithInterest - principleBalance;
        s_userLastUpdated[to] = block.timestamp;
        _mint(to, amountToMint);
    }

    /**
     * @notice Calculate the amount of interest that has been accrued since the last time the user updated
     * @param user address of the user
     * @return uint256 amount of interest that has been accrued since the last time the user updated
     */
    function _calculateUserAccumulatedInterestSinceLastUpdated(address user) internal view returns (uint256) {
        uint256 timeSinceLastUpdated = block.timestamp - s_userLastUpdated[user];

        return (s_userInterestRate[user] * timeSinceLastUpdated + PRECISION);
    }

    /////////////////////
    /// Getter Functions
    /////////////////////

    /**
     * @notice Get the current interest rate
     * @param user  address of the user
     * @return uint256 interest rate of the user
     */
    function getUserInterestRate(address user) external view returns (uint256) {
        return s_userInterestRate[user];
    }

    /**
     * @notice Get the principle balance of the user. This is the balance of the user before any interest has been accrued.
     * @param user address of the user
     * @return uint256 principle balance of the user
     */
    function getPrincipleBalance(address user) external view returns (uint256) {
        return super.balanceOf(user);
    }

    /**
     * @notice Get the current interest rate
     * @return uint256 current interest rate
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /**
     * @notice Get the last updated time
     * @param user address of the user
     * @return uint256 last updated time
     */
    function getUserLastUpdated(address user) external view returns (uint256) {
        return s_userLastUpdated[user];
    }
}
