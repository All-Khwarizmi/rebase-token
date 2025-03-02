// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant INITIAL_INTEREST_RATE = 5e10;

    address private ALICE = makeAddr("Alice");

    function setUp() public {
        rebaseToken = new RebaseToken();
    }

    modifier mint(uint256 amount, address to) {
        rebaseToken.mint(to, amount);
        _;
    }

    /* setInterestRate */
    function testSetInterestRate() public {
        rebaseToken.setInterestRate(INITIAL_INTEREST_RATE - 1);
        assertEq(rebaseToken.getInterestRate(), INITIAL_INTEREST_RATE - 1);
    }

    function testSetInterestRateShouldRevertIfNotOwner() public {
        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        rebaseToken.setInterestRate(INITIAL_INTEREST_RATE - 1);
    }

    function testSetInterestRateShouldRevertIfIncrease() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "RebaseToken__InterestRateCanOnlyDecrease(uint256,uint256)",
                INITIAL_INTEREST_RATE,
                INITIAL_INTEREST_RATE + 1
            )
        );
        rebaseToken.setInterestRate(INITIAL_INTEREST_RATE + 1);
    }

    function testSetInterestRateShouldEmitInterestRateChanged() public {
        vm.expectEmit(true, true, true, true);
        emit RebaseToken.InterestRateChanged(INITIAL_INTEREST_RATE - 1);
        rebaseToken.setInterestRate(INITIAL_INTEREST_RATE - 1);
    }

    /* mint */
    function testMintShouldMintTokensToUser() public {
        assertEq(rebaseToken.balanceOf(ALICE), 0);
        rebaseToken.mint(ALICE, 100);
        assertEq(rebaseToken.balanceOf(ALICE), 100);
    }

    function testMintShouldMintTokensToUserAndUpdateLastUpdated() public mint(100, ALICE) {
        assertEq(rebaseToken.getUserLastUpdated(ALICE), block.timestamp);

        vm.warp(block.timestamp + 1);
        rebaseToken.mint(ALICE, 100);
        assertEq(rebaseToken.getUserLastUpdated(ALICE), block.timestamp);
    }

    function testMintShouldMintTokensToUserAndAccrueInterest() public mint(100, ALICE) {
        uint256 balanceBefore = rebaseToken.balanceOf(ALICE);
        assertEq(balanceBefore, 100);

        // Interest rate is 5%
        uint256 timeElapsed = 1; // 1 second
        vm.warp(block.timestamp + timeElapsed);

        uint256 increaseAmount = 100;

        rebaseToken.mint(ALICE, increaseAmount);

        uint256 interestRateWithTimeElapsed = (INITIAL_INTEREST_RATE * timeElapsed * PRECISION);

        uint256 expectedAmount =
            balanceBefore + (balanceBefore * interestRateWithTimeElapsed / PRECISION) + increaseAmount;

        assertEq(rebaseToken.balanceOf(ALICE), expectedAmount);
    }

    /* burn */
    function testBurnShouldBurnTokensFromUser() public mint(100, ALICE) {
        rebaseToken.burn(ALICE, 100);
        assertEq(rebaseToken.balanceOf(ALICE), 0);
    }

    /* getUserInterestRate */
    function testGetUserInterestRate() public mint(100, ALICE) {
        assertEq(rebaseToken.getUserInterestRate(ALICE), INITIAL_INTEREST_RATE);
        rebaseToken.setInterestRate(INITIAL_INTEREST_RATE - 1);
        assertEq(rebaseToken.getUserInterestRate(ALICE), INITIAL_INTEREST_RATE);
    }
}
