// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {RebaseTokenPool} from "../../src/RebaseTokenPool.sol";
import {IRebaseToken} from "../../src/interfaces/IRebaseToken.sol";
import {Vault} from "../../src/Vault.sol";

contract CrossChainTest is Test {
    RebaseToken rebaseToken;
    Vault vault;
    uint256 amount = 100 ether;

    address user = makeAddr("user");

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    function setUp() public {

        sepoliaFork = vm.createSelectFork("sepolia");
        arbSepoliaFork = vm.createFork("arb-sepolia");

        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        vm.deal(user, amount);
        vm.prank(user);
    }
}
