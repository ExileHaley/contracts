// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {WrappedERC20} from "./WrappedERC20.sol";

contract WBNB is WrappedERC20 {
	constructor(address _bridge) WrappedERC20(_bridge, "Wrapped BNB", "WBNB", 18) {}
}