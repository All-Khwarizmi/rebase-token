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
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    error Vault__RedeemFailed();

    IRebaseToken private immutable i_rebaseToken;
    // pass rebase token address

    ///////////////////
    // Events
    ///////////////////
    event Deposit(address indexed user, uint256 amount);

    constructor(IRebaseToken rebaseTokenAddress) {
        i_rebaseToken = rebaseTokenAddress;
    }

    /////////////////////////////
    /// External & Public
    /////////////////////////////

    receive() external payable {}

    /**
     * Deposits the user's funds into the vault
     */
    function deposit() external payable {
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * Redeems the user's funds from the vault
     * @param amount  amount of tokens to redeem
     */
    function redeem(uint256 amount) public {
        i_rebaseToken.burn(msg.sender, amount);
        (bool sent,) = payable(msg.sender).call{value: amount}("");
        if (!sent) {
            revert Vault__RedeemFailed();
        }
    }

    /////////////////////////////
    /// Internal
    /////////////////////////////

    /////////////////////
    /// Getter
    /////////////////////

    /**
     * @notice Get the rebase token address
     * @return address rebase token address
     */
    function getRebaseTokenAddress() public view returns (address) {
        return address(i_rebaseToken);
    }
}
