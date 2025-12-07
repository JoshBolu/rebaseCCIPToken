// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken public rebaseToken;
    Vault public vault;

    address public joshua = makeAddr("joshua");
    address public caleb = makeAddr("caleb");
    address public owner = makeAddr("owner");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
        if (success == false) {
            revert();
        }
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // deposit into the vault
        vm.startPrank(joshua);
        vm.deal(joshua, amount);
        vault.deposit{value: amount}();
        // check the balance of joshua
        uint256 startingBalance = rebaseToken.balanceOf(joshua);
        console.log("Starting balance:", startingBalance);
        assertEq(startingBalance, amount);
        // warp time by 1 week
        vm.warp(block.timestamp + 6 hours);
        uint256 middleBalance = rebaseToken.balanceOf(joshua);
        console.log("Middle balance:", middleBalance);
        assertGt(middleBalance, startingBalance);
        // warp time by another hour
        vm.warp(block.timestamp + 6 hours);
        uint256 endingBalance = rebaseToken.balanceOf(joshua);
        console.log("Ending balance:", endingBalance);
        assertGt(endingBalance, middleBalance);

        assertApproxEqAbs(endingBalance - middleBalance, middleBalance - startingBalance, 1);
        vm.stopPrank();
    }

    function testDepositAndRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // deposit
        vm.startPrank(joshua);
        vm.deal(joshua, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(joshua), amount);
        // redeem
        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(joshua), 0);
        assertEq(address(joshua).balance, amount);
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1000, type(uint96).max);
        depositAmount = bound(depositAmount, 1e8, type(uint96).max);
        // deposit
        vm.prank(joshua);
        vm.deal(joshua, depositAmount);
        vault.deposit{value: depositAmount}();

        // warp time
        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(joshua);
        // add some rewards to the vault
        vm.prank(owner);
        vm.deal(owner, balanceAfterSomeTime - depositAmount);
        addRewardsToVault(balanceAfterSomeTime - depositAmount);
        // redeem
        vm.prank(joshua);
        vault.redeem(type(uint256).max);

        uint256 ethBalance = address(joshua).balance;

        assertEq(ethBalance, balanceAfterSomeTime);
        assertGt(ethBalance, depositAmount);
    }

    function testRedeemAfterTimePassedWithInsufficuentEthBalanceTriggerFailedTransfer(
        uint256 depositAmount,
        uint256 time
    ) public {
        time = bound(time, 1000, type(uint96).max);
        depositAmount = bound(depositAmount, 1e8, type(uint96).max);
        // deposit
        vm.prank(joshua);
        vm.deal(joshua, depositAmount);
        vault.deposit{value: depositAmount}();

        // warp time
        vm.warp(block.timestamp + time);
        // redeem expected to revert because there would be no enough eth for the transfer after interest has accrued
        vm.prank(joshua);
        vm.expectRevert(Vault.Vault_redeemFailed.selector);
        vault.redeem(type(uint256).max);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint192).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        // deposit into the vault
        vm.prank(joshua);
        vm.deal(joshua, amount);
        vault.deposit{value: amount}();

        uint256 startingBalanceJoshua = rebaseToken.balanceOf(joshua);
        uint256 startingBalanceCaleb = rebaseToken.balanceOf(caleb);
        assertEq(startingBalanceJoshua, amount);
        assertEq(startingBalanceCaleb, 0);

        // Owner changes interest rate lower
        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        // transfer some tokens to caleb
        vm.prank(joshua);
        rebaseToken.transfer(caleb, amountToSend);
        uint256 joshuaBalanceAfterTransfer = rebaseToken.balanceOf(joshua);
        uint256 calebBalanceAfterTransfer = rebaseToken.balanceOf(caleb);

        assertEq(joshuaBalanceAfterTransfer, startingBalanceJoshua - amountToSend);
        assertEq(calebBalanceAfterTransfer, startingBalanceCaleb + amountToSend);

        // check interest Rate applied correctly after transfer and rate changed
        assertEq(rebaseToken.getUserInterestRate(joshua), 5e10);
        assertEq(rebaseToken.getUserInterestRate(caleb), 5e10);
    }

    function testTransferMaxValue() public {
        vm.startPrank(joshua);
        vm.deal(joshua, type(uint56).max);
        vault.deposit{value: type(uint24).max}();
        console.log(rebaseToken.balanceOf(joshua));
        rebaseToken.transfer(caleb, type(uint256).max);
        console.log(rebaseToken.balanceOf(caleb));
        assertEq(rebaseToken.balanceOf(joshua), 0);
        assertEq(rebaseToken.balanceOf(caleb), type(uint24).max);
        vm.stopPrank();
    }

    function testTransferFrom(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint192).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);
        vm.startPrank(joshua);
        vm.deal(joshua, amount);
        vault.deposit{value: amount}();
        rebaseToken.approve(caleb, amountToSend);
        vm.stopPrank();

        vm.prank(caleb);
        rebaseToken.transferFrom(joshua, caleb, amountToSend);

        assertEq(rebaseToken.balanceOf(joshua), amount - amountToSend);
        assertEq(rebaseToken.balanceOf(caleb), amountToSend);
    }

    function testTransferFromMaxValue() public {
        vm.startPrank(joshua);
        vm.deal(joshua, type(uint56).max);
        vault.deposit{value: type(uint24).max}();
        rebaseToken.approve(caleb, type(uint24).max);
        vm.stopPrank();

        vm.prank(caleb);
        rebaseToken.transferFrom(joshua, caleb, type(uint256).max);
        assertEq(rebaseToken.balanceOf(joshua), 0);
        assertEq(rebaseToken.balanceOf(caleb), type(uint24).max);
    }

    function testNonOwnerCannotSetInterestRate(uint256 newInterestRate, address randomOwners) public {
        vm.prank(randomOwners);
        // used expectPartialRevert because custom errors can have arguments that are difficult to calculate in a testing environment and could be unrelated to the test at hand
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testCannotCallMintAndBurn() public {
        vm.prank(joshua);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.mint(joshua, 1e18);
        vm.prank(joshua);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.burn(joshua, 1e18);
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(joshua, amount);
        vm.prank(joshua);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.getPrincipalBalanceOf(joshua), amount);
        vm.warp(block.timestamp + 6 hours);
        assertEq(rebaseToken.getPrincipalBalanceOf(joshua), amount);
    }

    function testGetRebaseTokenAddress() public {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(newInterestRate, initialInterestRate, type(uint256).max);
        vm.prank(owner);
        vm.expectPartialRevert(RebaseToken.RebaseToken__InterestRateTooHigh.selector);
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
    }
}
