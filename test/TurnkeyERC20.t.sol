// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.20;

import {TurnkeyERC20} from "../src/TurnkeyERC20.sol";
import {BaseTest} from "./utils/BaseTest.t.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";

contract TurnkeyERC20Test is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.startPrank(address(1));
        turnkeyERC20 = new TurnkeyERC20("Test Token", "TKEY");
        turnkeyERC20.grantRoles(admin1.addr, turnkeyERC20.DEFAULT_ADMIN_ROLE());
        vm.stopPrank();
    }

    function test_constructor() public {
        vm.prank(address(1));
        turnkeyERC20 = new TurnkeyERC20("Test Token", "TKEY");

        assertEq(turnkeyERC20.owner(), address(1), "Owner should be set to address(1)");
        assertEq(turnkeyERC20.balanceOf(address(1)), 0, "Balance of owner should be 0");
        assertEq(turnkeyERC20.totalSupply(), 0, "Total supply should be 0");
        assertEq(turnkeyERC20.decimals(), 18, "Decimals should be 18");
        assertEq(turnkeyERC20.isTransferPaused(), true, "Transfer should be paused");
        assertEq(turnkeyERC20.name(), "Test Token", "Name should be Test Token");
        assertEq(turnkeyERC20.symbol(), "TKEY", "Symbol should be TKEY");
    }

    function test_enableTransferAndBurnOwnership_success() public {
        vm.prank(admin1.addr);
        turnkeyERC20.enableTransfer();
        assertEq(turnkeyERC20.isTransferPaused(), false, "Transfer should be enabled");
    }

    function test_enableTransferAndBurnOwnership_revert_Unauthorized() public {
        vm.prank(address(2));
        vm.expectRevert(Ownable.Unauthorized.selector);
        turnkeyERC20.enableTransfer();
    }

    function test_transfer_revert_TransferPaused() public {
        vm.prank(address(1));
        turnkeyERC20.mint(address(2), 100);
        vm.prank(address(2));
        vm.expectRevert(TurnkeyERC20.TransferPaused.selector);
        turnkeyERC20.transfer(address(3), 100);
    }

    function test_transfer_success() public {
        vm.prank(address(1));
        turnkeyERC20.mint(address(2), 100);
        vm.prank(admin1.addr);
        turnkeyERC20.enableTransfer();
        vm.prank(address(2));
        turnkeyERC20.transfer(address(3), 100);
        assertEq(turnkeyERC20.balanceOf(address(3)), 100, "Balance of address(3) should be 100");
    }

    function test_mint_revert_Unauthorized() public {
        vm.prank(address(2));
        vm.expectRevert(Ownable.Unauthorized.selector);
        turnkeyERC20.mint(address(3), 100);
    }

    function test_mint_success() public {
        // transfer is paused
        vm.prank(address(1));
        turnkeyERC20.mint(address(2), 100);
        assertEq(turnkeyERC20.balanceOf(address(2)), 100, "Balance of address(2) should be 100");
    }

    function test_CLOCK_MODE_success() public {
        assertEq(turnkeyERC20.CLOCK_MODE(), "mode=timestamp", "CLOCKMODE is not correct");
    }

    function test_clock_success() public {
        assertEq(turnkeyERC20.clock(), block.timestamp, "clock is not correct");
    }

    function test_toggleBlacklist_success() public {
        vm.prank(admin1.addr);
        turnkeyERC20.toggleBlacklist(address(2));
        assertEq(turnkeyERC20.blacklist(address(2)), true, "address(2) should be blacklisted");
    }

    function test_toggleBlacklist_revert_Unauthorized() public {
        vm.prank(address(2));
        vm.expectRevert(Ownable.Unauthorized.selector);
        turnkeyERC20.toggleBlacklist(address(3));
    }

    function test_transfer_revert_Blacklisted() public {
        vm.prank(admin1.addr);
        turnkeyERC20.toggleBlacklist(address(2));
        vm.prank(admin1.addr);
        turnkeyERC20.enableTransfer();
        vm.prank(address(2));
        vm.expectRevert(TurnkeyERC20.Blacklisted.selector);
        turnkeyERC20.transfer(address(3), 100);
    }
}
