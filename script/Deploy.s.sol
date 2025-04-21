// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.26;

import {console2} from "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {TurnkeyERC20} from "../src/TurnkeyERC20.sol";
import {TurnkeyGovernor} from "../src/TurnkeyGovernor.sol";

contract Deploy is Script {
    struct Config {
        GovernorConfig governor;
        TokenConfig token;
    }

    struct TokenConfig {
        string name;
        address owner;
        string symbol;
    }
    struct GovernorConfig {
        string name;
        uint256 proposalThreshold;
        uint256 quorumPercentage;
        uint256 votingDelay;
        uint256 voteExtension;
        uint256 votingPeriod;
    }

    function run() public {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deploy.config.json");
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);
        Config memory config = abi.decode(data, (Config));

        console2.log("owner: ", config.token.owner);
        console2.log("name: ", config.token.name);
        console2.log("symbol: ", config.token.symbol);
        console2.log("governor name: ", config.governor.name);
        console2.log("proposalThreshold: ", config.governor.proposalThreshold);
        console2.log("quorumPercentage: ", config.governor.quorumPercentage);
        console2.log("votingDelay: ", config.governor.votingDelay);
        console2.log("votingPeriod: ", config.governor.votingPeriod);
        console2.log("voteExtension: ", config.governor.voteExtension);
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        console2.log("deployer: ", deployer);

        TurnkeyERC20 turnkeyERC20 = new TurnkeyERC20(
            config.token.owner,
            config.token.name,
            config.token.symbol
        );
        TurnkeyGovernor turnkeyGovernor = new TurnkeyGovernor(
            config.governor.name,
            turnkeyERC20,
            config.governor.quorumPercentage,
            uint48(config.governor.voteExtension),
            uint48(config.governor.votingDelay),
            uint32(config.governor.votingPeriod),
            config.governor.proposalThreshold
        );
        vm.stopBroadcast();

        string memory deployments = "deployments";

        vm.serializeAddress(deployments, "TurnkeyGovernor", address(turnkeyGovernor));
        string memory deploymentsJson = vm.serializeAddress(deployments, "TurnkeyERC20", address(turnkeyERC20));

        string memory deployedConfig = "config";
        vm.serializeAddress(deployedConfig, "deployer", deployer);
        vm.serializeAddress(deployedConfig, "owner", config.token.owner);
        vm.serializeString(deployedConfig, "name", config.token.name);
        vm.serializeString(deployedConfig, "symbol", config.token.symbol);
        vm.serializeString(deployedConfig, "governorName", config.governor.name);
        vm.serializeUint(deployedConfig, "proposalThreshold", config.governor.proposalThreshold);
        vm.serializeUint(deployedConfig, "quorumPercentage", config.governor.quorumPercentage);
        vm.serializeUint(deployedConfig, "votingDelay", config.governor.votingDelay);
        vm.serializeUint(deployedConfig, "votingPeriod", config.governor.votingPeriod);
        vm.serializeUint(deployedConfig, "voteExtension", config.governor.voteExtension);
        string memory deployedConfigJson = vm.serializeUint(deployedConfig, "startBlock", block.number);

        vm.writeJson(deploymentsJson, "./out/deployments.json");
        vm.writeJson(deployedConfigJson, "./out/deployed.config.json");
    }
}
