// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.26;

import {console2} from "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {UngovernableERC20} from "../src/UngovernableERC20.sol";
import {UngovernableGovernor} from "../src/UngovernableGovernor.sol";

contract Deploy is Script {
    struct Config {
        GovernorConfig governor;
        TokenConfig token;
    }

    struct TokenConfig {
        string _name;
        string _symbol;
    }

    struct GovernorConfig {
        uint256 _initialProposalThreshold;
        uint256 _initialQuorumPercentage;
        uint256 _initialVoteExtension;
        uint256 _initialVotingDelay;
        uint256 _initialVotingPeriod;
        string _name;
    }

    function run() public {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deploy.config.json");
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);
        Config memory config = abi.decode(data, (Config));

        // Check if DEBUG environment variable is set
        bool isDebugMode = vm.envOr("DEBUG", false);

        if (isDebugMode) {
            console2.log("DEBUG MODE ENABLED");
            console2.log("name: ", config.token._name);
            console2.log("symbol: ", config.token._symbol);
            console2.log("governor name: ", config.governor._name);
            console2.log("proposalThreshold: ", config.governor._initialProposalThreshold);
            console2.log("quorumPercentage: ", config.governor._initialQuorumPercentage);
            console2.log("votingDelay: ", config.governor._initialVotingDelay);
            console2.log("votingPeriod: ", config.governor._initialVotingPeriod);
            console2.log("voteExtension: ", config.governor._initialVoteExtension);
        }

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        console2.log("deployer: ", deployer);

        UngovernableERC20 ungovernableERC20 = new UngovernableERC20(config.token._name, config.token._symbol);
        UngovernableGovernor ungovernableGovernor = new UngovernableGovernor(
            config.governor._name,
            ungovernableERC20,
            config.governor._initialQuorumPercentage,
            uint48(config.governor._initialVoteExtension),
            uint48(config.governor._initialVotingDelay),
            uint32(config.governor._initialVotingPeriod),
            config.governor._initialProposalThreshold
        );
        vm.stopBroadcast();

        string memory deployments = "deployments";
        string memory ungovernableERC20Json = "token";
        string memory ungovernableGovernorJson = "governor";

        vm.serializeAddress(ungovernableERC20Json, "_address", address(ungovernableERC20));
        vm.serializeString(ungovernableERC20Json, "_name", config.token._name);
        vm.serializeString(ungovernableERC20Json, "_symbol", config.token._symbol);

        vm.serializeAddress(ungovernableGovernorJson, "_address", address(ungovernableGovernor));
        vm.serializeUint(
            ungovernableGovernorJson, "_initialProposalThreshold", config.governor._initialProposalThreshold
        );
        vm.serializeUint(ungovernableGovernorJson, "_initialQuorumPercentage", config.governor._initialQuorumPercentage);
        vm.serializeUint(ungovernableGovernorJson, "_initialVotingDelay", config.governor._initialVotingDelay);
        vm.serializeUint(ungovernableGovernorJson, "_initialVotingPeriod", config.governor._initialVotingPeriod);
        vm.serializeUint(ungovernableGovernorJson, "_initialVoteExtension", config.governor._initialVoteExtension);
        vm.serializeString(ungovernableGovernorJson, "_name", config.governor._name);
        vm.serializeAddress(ungovernableGovernorJson, "_token", address(ungovernableERC20));

        vm.serializeString(
            deployments, "token", vm.serializeAddress(ungovernableERC20Json, "_address", address(ungovernableERC20))
        );
        string memory deploymentsJson = vm.serializeString(
            deployments, "governor", vm.serializeAddress(ungovernableGovernorJson, "_token", address(ungovernableERC20))
        );

        string memory metadataJson = "metadata";
        vm.serializeAddress(metadataJson, "deployer", deployer);
        vm.writeJson(
            vm.serializeString(deployments, "metadata", vm.serializeUint(metadataJson, "startBlock", block.number)),
            "./out/deployed.config.json"
        );
    }
}
