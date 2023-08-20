// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract WrappedERC20 is ERC20 {
    address public immutable bridge;
    uint8 private immutable _tokenDecimals;

    constructor(address _bridge, string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol) {
        require(_bridge != address(0), "WrappedERC20: invalid bridge");

        bridge = _bridge;
        _tokenDecimals = _decimals;
    }

    modifier onlyBridge() {
        require(msg.sender == bridge, "WrappedERC20: caller is not the bridge");
        _;
    }

    function decimals() public view virtual override returns (uint8) {
        return _tokenDecimals;
    }

    function mint(address _to, uint _amount) external virtual onlyBridge {
        _mint(_to, _amount);
    }

    function burn(address _from, uint _amount) external virtual onlyBridge {
        _burn(_from, _amount);
    }
}
