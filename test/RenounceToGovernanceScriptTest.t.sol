// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {RenounceToGovernance} from "../script/RenounceToGovernance.s.sol";
import {UngovernableERC20} from "../src/UngovernableERC20.sol";
import {UngovernableGovernor} from "../src/UngovernableGovernor.sol";

contract RenounceToGovernanceScriptTest is Test {
    Deploy public deployerScript;
    RenounceToGovernance public renounceScript;
    UngovernableERC20 public token;
    UngovernableGovernor public governor;
    address public deployerAddress = vm.addr(vm.envUint("PRIVATE_KEY"));
    address public initialTokenOwner;
    uint256 public adminRole;

    function setUp() public {
        // Initial deployment of contracts
        deployerScript = new Deploy();
        deployerScript.run();

        // Read deployed contract addresses from the output configuration file
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/out/deployed.config.json");
        string memory json = vm.readFile(path);
        if (bytes(json).length == 0) {
            revert("Failed to read or JSON content is empty from ./out/deployed.config.json");
        }
        address tokenAddress = vm.parseJsonAddress(json, ".token._address");
        address governorAddress = vm.parseJsonAddress(json, ".governor._address");

        if (tokenAddress == address(0) || governorAddress == address(0)) {
            revert("Failed to parse contract addresses from JSON, or address is zero.");
        }

        // Initialize contract instances for testing
        token = UngovernableERC20(tokenAddress);
        governor = UngovernableGovernor(payable(governorAddress));

        // Store initial state for later assertions
        initialTokenOwner = token.owner();
        adminRole = token.DEFAULT_ADMIN_ROLE();
        assertEq(initialTokenOwner, deployerAddress, "Initial token owner should be the deployer.");

        // Execute the script under test
        renounceScript = new RenounceToGovernance();
        renounceScript.run();
    }

    function test_TokenOwner_Is_AddressZero() public view {
        assertEq(token.owner(), address(0), "Token owner should be the address(0) after renunciation.");
    }

    function test_Governor_Has_DefaultAdminRole_For_Token() public view {
        assertTrue(
            token.hasAnyRole(address(governor), adminRole),
            "Governor should have DEFAULT_ADMIN_ROLE on the Token contract."
        );
    }

    function test_InitialOwner_NoLonger_Owner() public view {
        assertNotEq(token.owner(), initialTokenOwner, "Initial token owner (deployer) should no longer be the owner.");
    }

    function test_InitialOwner_DoesNotHave_DefaultAdminRole() public view {
        assertFalse(
            token.hasAnyRole(initialTokenOwner, adminRole),
            "Initial owner (deployer) should not have DEFAULT_ADMIN_ROLE on the Token contract after renunciation."
        );
    }

    function test_Run_InDebugMode() public {
        // Enable debug mode for the subsequent script executions
        vm.setEnv("DEBUG", "true");

        // Re-deploy contracts in debug mode
        Deploy newDeployer = new Deploy();
        newDeployer.run();

        // Read deployed contract addresses from the new debug deployment
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/out/deployed.config.json");
        string memory json = vm.readFile(path);
        assertTrue(bytes(json).length > 0, "Failed to read deployed.config.json after debug deploy");
        address tokenAddress = vm.parseJsonAddress(json, ".token._address");
        address governorAddress = vm.parseJsonAddress(json, ".governor._address");
        assertTrue(
            tokenAddress != address(0) && governorAddress != address(0), "Invalid addresses from deployed.config.json"
        );

        // Initialize new contract instances from the debug deployment
        UngovernableERC20 debugToken = UngovernableERC20(tokenAddress);
        UngovernableGovernor debugGovernor = UngovernableGovernor(payable(governorAddress));
        address debugInitialTokenOwner = debugToken.owner();
        assertEq(debugInitialTokenOwner, deployerAddress, "Initial token owner for debug run should be deployer");

        // Re-run the renunciation script in debug mode
        RenounceToGovernance newRenounceScript = new RenounceToGovernance();
        newRenounceScript.run();

        // Assertions to verify the state after renunciation in debug mode
        assertEq(debugToken.owner(), address(0), "Token owner should be address(0) after debug renunciation.");
        assertTrue(
            debugToken.hasAnyRole(address(debugGovernor), adminRole),
            "Governor should have DEFAULT_ADMIN_ROLE on the Token contract after debug renunciation."
        );
        assertNotEq(
            debugToken.owner(),
            debugInitialTokenOwner,
            "Initial token owner should no longer be owner after debug renunciation."
        );
        assertFalse(
            debugToken.hasAnyRole(debugInitialTokenOwner, adminRole),
            "Initial owner should not have DEFAULT_ADMIN_ROLE after debug renunciation."
        );

        // Reset debug mode environment variable
        vm.setEnv("DEBUG", "false");
    }
}
