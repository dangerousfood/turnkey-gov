// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.26;

import {console2} from "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {UngovernableERC20} from "../src/UngovernableERC20.sol";
import {UngovernableGovernor} from "../src/UngovernableGovernor.sol";

contract RenounceToGovernance is Script {
    struct Config {
        GovernorConfig governor;
        MetadataConfig metadata;
        TokenConfig token;
    }

    struct TokenConfig {
        address _address;
        string _name;
        string _symbol;
    }

    struct GovernorConfig {
        address _address;
        uint256 _initialProposalThreshold;
        uint256 _initialQuorumPercentage;
        uint256 _initialVoteExtension;
        uint256 _initialVotingDelay;
        uint256 _initialVotingPeriod;
        string _name;
        address _token;
    }

    struct MetadataConfig {
        address deployer;
        uint256 startBlock;
    }

    function run() public {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/out/deployed.config.json");
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);
        Config memory config = abi.decode(data, (Config));

        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));

        // Check if DEBUG environment variable is set
        bool isDebugMode = vm.envOr("DEBUG", false);

        if (isDebugMode) {
            console2.log("DEBUG MODE ENABLED");
            console2.log("deployer: ", deployer);
            console2.log("token address: ", config.token._address);
            console2.log("token name: ", config.token._name);
            console2.log("token symbol: ", config.token._symbol);
            console2.log("governor address: ", config.governor._address);
            console2.log("governor name: ", config.governor._name);
        } else {
            console2.log("deployer: ", deployer);
            console2.log("Using token address:", config.token._address);
            console2.log("Using governor address:", config.governor._address);
        }

        UngovernableERC20 ungovernableERC20 = UngovernableERC20(config.token._address);
        UngovernableGovernor ungovernableGovernor = UngovernableGovernor(payable(config.governor._address));

        vm.startBroadcast();
        ungovernableERC20.grantRoles(address(ungovernableGovernor), ungovernableERC20.DEFAULT_ADMIN_ROLE());
        ungovernableERC20.renounceOwnership();
        vm.stopBroadcast();
    }
}
