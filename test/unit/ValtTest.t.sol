// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../../src/Vault.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {IRebaseToken} from "../../src/interfaces/IRebaseToken.sol";

contract VaultTest is Test {
    Vault private vault;
    RebaseToken private rebaseToken;
    address private CONTRACT_ADDR;

    address private ALICE = makeAddr("Alice");
    address private OWNER = makeAddr("Owner");
    address private BOB = makeAddr("Bob");
    address private CHARLIE = makeAddr("Charlie");
    address private DAVE = makeAddr("Dave");

    function setUp() public {
        vm.startPrank(OWNER);
        rebaseToken = new RebaseToken();
        CONTRACT_ADDR = address(new RebaseToken());
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
        _setUpAccounts();
    }

    function _setUpAccounts() internal {
        vm.deal(ALICE, 100 ether);
        vm.deal(BOB, 100 ether);
        vm.deal(CHARLIE, 100 ether);
        vm.deal(DAVE, 100 ether);
        vm.deal(CONTRACT_ADDR, 100 ether);
    }


    // /* deposit */
    function testDepositShouldMintTokensToUser() public {
        vm.prank(ALICE);
        vault.deposit{value: 100}();
        assertEq(rebaseToken.balanceOf(ALICE), 100);
    }

    function testDepositShouldEmitDepositEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Vault.Deposit(ALICE, 100);
        vm.prank(ALICE);
        vault.deposit{value: 100}();
    }

    // /* redeem */
    function testRedeemShouldBurnTokensFromUser() public {
        vm.prank(ALICE);
        vault.deposit{value: 100}();
        vm.prank(ALICE);
        vault.redeem(100);
        assertEq(rebaseToken.balanceOf(ALICE), 0);
    }

    function testRedeemShouldSendFundsToUser() public {
        vm.prank(ALICE);
        vault.deposit{value: 100}();
        address payable aliceAddress = payable(ALICE);
        uint256 aliceBalanceBefore = aliceAddress.balance;
        vm.prank(ALICE);
        vault.redeem(100);
        uint256 aliceBalanceAfter = aliceAddress.balance;
        assertEq(aliceBalanceAfter - aliceBalanceBefore, 100);
    }

    function testRedeemShouldRevertIfRedeemFailed() public {
        vm.prank(CONTRACT_ADDR);
        vault.deposit{value: 100}();
        vm.prank(CONTRACT_ADDR);
        vm.expectRevert(Vault.Vault__RedeemFailed.selector);
        vault.redeem(100);
    }

    /* getRebaseTokenAddress */
    function testGetRebaseTokenAddress() public {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }
}
