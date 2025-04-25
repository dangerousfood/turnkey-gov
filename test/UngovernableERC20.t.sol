// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.20;

import {UngovernableERC20} from "../src/UngovernableERC20.sol";
import {BaseTest} from "./utils/BaseTest.t.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";

contract UngovernableERC20Test is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.startPrank(address(1));
        ungovernableERC20 = new UngovernableERC20("Test Token", "TKEY");
        ungovernableERC20.grantRoles(admin1.addr, ungovernableERC20.DEFAULT_ADMIN_ROLE());
        vm.stopPrank();
    }

    function test_constructor() public {
        vm.prank(address(1));
        ungovernableERC20 = new UngovernableERC20("Test Token", "TKEY");

        assertEq(ungovernableERC20.owner(), address(1), "Owner should be set to address(1)");
        assertEq(ungovernableERC20.balanceOf(address(1)), 0, "Balance of owner should be 0");
        assertEq(ungovernableERC20.totalSupply(), 0, "Total supply should be 0");
        assertEq(ungovernableERC20.decimals(), 18, "Decimals should be 18");
        assertEq(ungovernableERC20.isTransferPaused(), true, "Transfer should be paused");
        assertEq(ungovernableERC20.name(), "Test Token", "Name should be Test Token");
        assertEq(ungovernableERC20.symbol(), "TKEY", "Symbol should be TKEY");
    }

    function test_enableTransferAndBurnOwnership_success() public {
        vm.prank(admin1.addr);
        ungovernableERC20.enableTransfer();
        assertEq(ungovernableERC20.isTransferPaused(), false, "Transfer should be enabled");
    }

    function test_enableTransferAndBurnOwnership_revert_Unauthorized() public {
        vm.prank(address(2));
        vm.expectRevert(Ownable.Unauthorized.selector);
        ungovernableERC20.enableTransfer();
    }

    function test_transfer_revert_TransferPaused() public {
        vm.prank(address(1));
        ungovernableERC20.mint(address(2), 100);
        vm.prank(address(2));
        vm.expectRevert(UngovernableERC20.TransferPaused.selector);
        ungovernableERC20.transfer(address(3), 100);
    }

    function test_transfer_success() public {
        vm.prank(address(1));
        ungovernableERC20.mint(address(2), 100);
        vm.prank(admin1.addr);
        ungovernableERC20.enableTransfer();
        vm.prank(address(2));
        ungovernableERC20.transfer(address(3), 100);
        assertEq(ungovernableERC20.balanceOf(address(3)), 100, "Balance of address(3) should be 100");
    }

    function test_mint_revert_Unauthorized() public {
        vm.prank(address(2));
        vm.expectRevert(Ownable.Unauthorized.selector);
        ungovernableERC20.mint(address(3), 100);
    }

    function test_mint_success() public {
        // transfer is paused
        vm.prank(address(1));
        ungovernableERC20.mint(address(2), 100);
        assertEq(ungovernableERC20.balanceOf(address(2)), 100, "Balance of address(2) should be 100");
    }

    function test_CLOCK_MODE_success() public {
        assertEq(ungovernableERC20.CLOCK_MODE(), "mode=timestamp", "CLOCKMODE is not correct");
    }

    function test_clock_success() public {
        assertEq(ungovernableERC20.clock(), block.timestamp, "clock is not correct");
    }

    function test_toggleBlacklist_success() public {
        vm.prank(admin1.addr);
        ungovernableERC20.toggleBlacklist(address(2));
        assertEq(ungovernableERC20.blacklist(address(2)), true, "address(2) should be blacklisted");
    }

    function test_toggleBlacklist_revert_Unauthorized() public {
        vm.prank(address(2));
        vm.expectRevert(Ownable.Unauthorized.selector);
        ungovernableERC20.toggleBlacklist(address(3));
    }

    function test_transfer_revert_Blacklisted() public {
        vm.prank(admin1.addr);
        ungovernableERC20.toggleBlacklist(address(2));
        vm.prank(admin1.addr);
        ungovernableERC20.enableTransfer();
        vm.prank(address(2));
        vm.expectRevert(UngovernableERC20.Blacklisted.selector);
        ungovernableERC20.transfer(address(3), 100);
    }
}
