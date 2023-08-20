// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {OriginalBridge} from "../OriginalBridge.sol";

/// @dev used only in unit tests to call internal _nonblockingLzReceive
contract OriginalTokenBridgeHarness is OriginalBridge {
    constructor(address _endpoint, uint16 _remoteChainId, address _weth) OriginalBridge(_endpoint, _remoteChainId, _weth) {}

    function simulateNonblockingLzReceive(uint16 srcChainId, bytes memory payload) external {
        _nonblockingLzReceive(srcChainId, "0x", 0, payload);
    }
}