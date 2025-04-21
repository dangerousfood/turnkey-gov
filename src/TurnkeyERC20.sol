// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.26;

import {Votes, VotesExtended} from "@openzeppelin/contracts/governance/utils/VotesExtended.sol";
import {ERC20, ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";

contract TurnkeyERC20 is ERC20Votes, Ownable {
    bool public isTransferPaused = true;
    /// @dev The error for when a transfer is attempted but transfers are paused (minting/burning is still allowed)
    error TransferPaused();

    constructor(
        address _owner,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) EIP712(_name, "1") {
        _initializeOwner(_owner);
    }

    function enableTransfer() external onlyOwner {
      isTransferPaused = false;
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    /// @inheritdoc ERC20
    /// @notice Function is overidden to check if transfers are paused
    /// @notice When transfers are paused, minting/burning is still allowed
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0) && isTransferPaused) {
            assembly {
                mstore(0x00, 0xcd1fda9f) // `TransferPaused()`.
                revert(0x1c, 0x04)
            }
        }
        super._update(from, to, value);
    }
}
