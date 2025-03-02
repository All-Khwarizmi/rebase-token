// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../../src/Vault.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {IRebaseToken} from "../../src/interfaces/IRebaseToken.sol";

contract VaultFuzz is Test {
    Vault private vault;
    RebaseToken private rebaseToken;
    address private CONTRACT_ADDR;

    address private ALICE = makeAddr("Alice");
    address private OWNER = makeAddr("Owner");
    address private BOB = makeAddr("Bob");
    address private CHARLIE = makeAddr("Charlie");

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
        vm.deal(CONTRACT_ADDR, 100 ether);
    }

    function testDepositInterestRateIsLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(ALICE);
        vm.deal(ALICE, amount);

        vault.deposit{value: amount}();
        uint256 balanceStart = rebaseToken.balanceOf(ALICE);

        vm.warp(block.timestamp + 1 hours);
        uint256 balanceMiddle = rebaseToken.balanceOf(ALICE);
        // assertGt(balanceMiddle, balanceStart);

        vm.warp(block.timestamp + 1 hours);
        uint256 balanceEnd = rebaseToken.balanceOf(ALICE);
        assertGt(balanceEnd, balanceMiddle);

        assertApproxEqAbs(balanceEnd - balanceMiddle, balanceMiddle - balanceStart, 1);

        vm.stopPrank();
    }

    function testRedeemRightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(ALICE);
        vm.deal(ALICE, amount);
        vault.deposit{value: amount}();
        vault.redeem(amount);
        assertEq(rebaseToken.balanceOf(ALICE), 0);
    }

    function testRedeemAfterTimeHasPassed(uint256 amount, uint256 time) public {
        amount = bound(amount, 1e5, type(uint96).max);
        time = bound(time, 1 hours, 1e9 days);

        vm.startPrank(ALICE);
        vm.deal(ALICE, amount);

        vault.deposit{value: amount}();

        vm.warp(block.timestamp + time);
        uint256 balance = rebaseToken.balanceOf(ALICE);
        vm.deal(address(vault), balance);

        vault.redeem(balance);

        assertEq(rebaseToken.balanceOf(ALICE), 0);
    }
}
