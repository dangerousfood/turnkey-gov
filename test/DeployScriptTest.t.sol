// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {UngovernableERC20} from "../src/UngovernableERC20.sol";
import {UngovernableGovernor} from "../src/UngovernableGovernor.sol";
import "../script/Deploy.s.sol";

contract DeployScriptTest is Test {
    Deploy public deployer;
    UngovernableERC20 public token;
    UngovernableGovernor public governor;
    address public deployerAddress = vm.addr(vm.envUint("PRIVATE_KEY"));

    string internal deployedJsonContent;

    string internal expectedTokenName;
    string internal expectedTokenSymbol;
    string internal expectedGovernorName;
    uint256 internal expectedInitialProposalThreshold;
    uint256 internal expectedInitialQuorumPercentage;
    uint48 internal expectedInitialVoteExtension;
    uint48 internal expectedInitialVotingDelay;
    uint32 internal expectedInitialVotingPeriod;

    function setUp() public {
        // Execute the main deployment script.
        deployer = new Deploy();
        deployer.run();

        // Read and parse addresses from the script's output configuration file
        string memory root = vm.projectRoot();
        string memory deployedPath = string.concat(root, "/out/deployed.config.json");
        deployedJsonContent = vm.readFile(deployedPath);
        if (bytes(deployedJsonContent).length == 0) {
            revert("Failed to read or JSON content is empty from ./out/deployed.config.json");
        }
        address tokenAddress = vm.parseJsonAddress(deployedJsonContent, ".token._address");
        address governorAddress = vm.parseJsonAddress(deployedJsonContent, ".governor._address");

        if (tokenAddress == address(0)) {
            revert("Failed to parse token address from JSON, or address is zero.");
        }
        if (governorAddress == address(0)) {
            revert("Failed to parse governor address from JSON, or address is zero.");
        }

        // Initialize contract instances with deployed addresses
        token = UngovernableERC20(tokenAddress);
        governor = UngovernableGovernor(payable(governorAddress));

        // Read and store expected values from the input deploy.config.json for assertions
        string memory deployConfigPath = string.concat(root, "/deploy.config.json");
        string memory deployConfigJsonContent = vm.readFile(deployConfigPath);
        if (bytes(deployConfigJsonContent).length == 0) {
            revert("Failed to read or JSON content is empty from ./deploy.config.json");
        }

        expectedTokenName = vm.parseJsonString(deployConfigJsonContent, ".token._name");
        expectedTokenSymbol = vm.parseJsonString(deployConfigJsonContent, ".token._symbol");

        expectedGovernorName = vm.parseJsonString(deployConfigJsonContent, ".governor._name");
        expectedInitialProposalThreshold =
            vm.parseJsonUint(deployConfigJsonContent, ".governor._initialProposalThreshold");
        expectedInitialQuorumPercentage =
            vm.parseJsonUint(deployConfigJsonContent, ".governor._initialQuorumPercentage");
        expectedInitialVoteExtension =
            uint48(vm.parseJsonUint(deployConfigJsonContent, ".governor._initialVoteExtension"));
        expectedInitialVotingDelay = uint48(vm.parseJsonUint(deployConfigJsonContent, ".governor._initialVotingDelay"));
        expectedInitialVotingPeriod =
            uint32(vm.parseJsonUint(deployConfigJsonContent, ".governor._initialVotingPeriod"));
    }

    function test_Deployment_Properties() public view {
        // Assertions for token and governor properties against expected configuration values
        assertEq(token.owner(), deployerAddress, "Token owner should be the deployer of the script");
        assertEq(address(governor.token()), address(token), "Governor's token should be the deployed token instance");

        assertEq(token.name(), expectedTokenName, "Token name should match config");
        assertEq(token.symbol(), expectedTokenSymbol, "Token symbol should match config");

        assertEq(governor.name(), expectedGovernorName, "Governor name should match config");
        assertEq(
            governor.proposalThreshold(),
            expectedInitialProposalThreshold,
            "Governor proposalThreshold should match config's _initialProposalThreshold"
        );
        assertEq(
            governor.quorumNumerator(),
            expectedInitialQuorumPercentage,
            "Governor quorumNumerator should match config's _initialQuorumPercentage"
        );
        assertEq(
            governor.lateQuorumVoteExtension(),
            uint256(expectedInitialVoteExtension),
            "Governor lateQuorumVoteExtension should match config's _initialVoteExtension"
        );
        assertEq(
            governor.votingDelay(),
            uint256(expectedInitialVotingDelay),
            "Governor votingDelay should match config's _initialVotingDelay"
        );
        assertEq(
            governor.votingPeriod(),
            uint256(expectedInitialVotingPeriod),
            "Governor votingPeriod should match config's _initialVotingPeriod"
        );
    }

    function test_SerializedOutput_Properties() public view {
        // Assertions for the content of the generated deployed.config.json file
        // Token related checks in deployed.config.json
        assertEq(
            vm.parseJsonAddress(deployedJsonContent, ".token._address"),
            address(token),
            "Serialized token address mismatch"
        );
        assertEq(
            vm.parseJsonString(deployedJsonContent, ".token._name"), expectedTokenName, "Serialized token name mismatch"
        );
        assertEq(
            vm.parseJsonString(deployedJsonContent, ".token._symbol"),
            expectedTokenSymbol,
            "Serialized token symbol mismatch"
        );

        // Governor related checks in deployed.config.json
        assertEq(
            vm.parseJsonAddress(deployedJsonContent, ".governor._address"),
            address(governor),
            "Serialized governor address mismatch"
        );
        assertEq(
            vm.parseJsonString(deployedJsonContent, ".governor._name"),
            expectedGovernorName,
            "Serialized governor name mismatch"
        );
        assertEq(
            vm.parseJsonUint(deployedJsonContent, ".governor._initialProposalThreshold"),
            expectedInitialProposalThreshold,
            "Serialized governor proposalThreshold mismatch"
        );
        assertEq(
            vm.parseJsonUint(deployedJsonContent, ".governor._initialQuorumPercentage"),
            expectedInitialQuorumPercentage,
            "Serialized governor quorumPercentage mismatch"
        );
        assertEq(
            vm.parseJsonUint(deployedJsonContent, ".governor._initialVotingDelay"),
            uint256(expectedInitialVotingDelay),
            "Serialized governor votingDelay mismatch"
        );
        assertEq(
            vm.parseJsonUint(deployedJsonContent, ".governor._initialVotingPeriod"),
            uint256(expectedInitialVotingPeriod),
            "Serialized governor votingPeriod mismatch"
        );
        assertEq(
            vm.parseJsonUint(deployedJsonContent, ".governor._initialVoteExtension"),
            uint256(expectedInitialVoteExtension),
            "Serialized governor voteExtension mismatch"
        );
        assertEq(
            vm.parseJsonAddress(deployedJsonContent, ".governor._token"),
            address(token),
            "Serialized governor's token address mismatch"
        );

        // Metadata related checks in deployed.config.json
        assertEq(
            vm.parseJsonAddress(deployedJsonContent, ".metadata.deployer"),
            deployerAddress,
            "Serialized deployer address mismatch"
        );
        assertTrue(
            vm.parseJsonUint(deployedJsonContent, ".metadata.startBlock") > 0, "Serialized startBlock should be > 0"
        );
    }

    function test_Run_InDebugMode() public {
        // Enable debug mode for script execution
        vm.setEnv("DEBUG", "true");

        // Re-run the deployment script in debug mode
        Deploy debugDeployer = new Deploy();
        debugDeployer.run();

        // Verify that the output configuration file is created and contains a valid token address
        string memory root = vm.projectRoot();
        string memory deployedPath = string.concat(root, "/out/deployed.config.json");
        string memory debugDeployedJsonContent = vm.readFile(deployedPath);
        assertTrue(
            bytes(debugDeployedJsonContent).length > 0, "deployed.config.json should not be empty after debug run"
        );
        address tokenAddress = vm.parseJsonAddress(debugDeployedJsonContent, ".token._address");
        assertTrue(tokenAddress != address(0), "Token address should be non-zero after debug run");

        // Reset debug mode environment variable
        vm.setEnv("DEBUG", "false");
    }
}
