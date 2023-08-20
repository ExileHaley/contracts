// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {WrappedBridge} from "../WrappedBridge.sol";

/// @dev used only in unit tests to call internal _nonblockingLzReceive
contract WrappedTokenBridgeHarness is WrappedBridge {
    constructor(address _endpoint) WrappedBridge(_endpoint) {}

    function simulateNonblockingLzReceive(uint16 srcChainId, bytes memory payload) external {
        _nonblockingLzReceive(srcChainId, "0x", 0, payload);
    }
}