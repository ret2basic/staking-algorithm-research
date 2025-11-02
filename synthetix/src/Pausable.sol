// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Inheritance
import "./Owned.sol";

// https://docs.synthetix.io/contracts/source/contracts/pausable
abstract contract Pausable is Owned {
    uint256 public lastPauseTime;
    bool public paused;

    constructor() {
        require(owner != address(0), "Owner must be set");
    }

    /**
     * @notice Change the paused state of the contract
     * @dev Only the contract owner may call this.
     */
    function setPaused(bool _paused) external onlyOwner {
        if (_paused == paused) {
            return;
        }

        paused = _paused;

        if (paused) {
            lastPauseTime = block.timestamp;
        }

        emit PauseChanged(paused);
    }

    event PauseChanged(bool isPaused);

    modifier notPaused() {
        require(!paused, "This action cannot be performed while the contract is paused");
        _;
    }
}
