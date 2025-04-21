// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {TurnkeyGovernor} from "../../src/TurnkeyGovernor.sol";
import {console} from "forge-std/console.sol";

interface IERC20 {
    function mint(address to, uint256 amount) external;
    function approve(address spender, uint256 amount) external;
}

contract BaseTest is Test {
    TurnkeyGovernor turnkeyGovernor;
    TurnkeyERC20 turnkeyERC20;
    Account initialOwner;
    Account admin1;
    Account admin2;

    address alice;
    address bob;
    address charlie;

    uint32 defaultTimelockDelay = 1 days;
    uint256 defaultQuorumPercentage = 4;
    uint48 defaultVoteExtension = 1 days;
    uint48 defaultVotingDelay = 1 days;
    uint32 defaultVotingPeriod = 5 days;
    uint256 defaultProposalThreshold = 30_000e18;

    function setUp() public virtual {
        initialOwner = makeAccount("initialOwner");
        admin1 = makeAccount("admin1");
        admin2 = makeAccount("admin2");
        address[] memory admins = new address[](2);
        admins[0] = admin1.addr;
        admins[1] = admin2.addr;
        vm.label(initialOwner.addr, "initialOwner");
        vm.label(admin1.addr, "admin1");
        vm.label(admin2.addr, "admin2");

        turnkeyERC20 = new TurnkeyERC20(initialOwner.addr, "ERC20", "ABC");
        turnkeyGovernor = new TurnkeyGovernor(
            "Governor",
            turnkeyERC20,
            defaultQuorumPercentage,
            defaultVoteExtension,
            defaultVotingDelay,
            defaultVotingPeriod,
            defaultProposalThreshold
        );

        alice = address(1);
        vm.label(alice, "alice");
        bob = address(2);
        vm.label(bob, "bob");
        charlie = address(3);
        vm.label(charlie, "charlie");
    }

    function mintAndApprove(address _to, uint256 _amount, address spender, address _token) public {
        IERC20(_token).mint(_to, _amount);
        vm.prank(_to);
        IERC20(_token).approve(spender, _amount);
    }
}
