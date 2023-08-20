// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract MultiTransfer{
    // event MultiTransfer(address wallet,uint256[] amounts);
    address public beforeToken;
    address public currentToken;

    mapping(address => bool) blacklist;//不发送token
    mapping(address => bool) hasBeenSent; // 已发送
    mapping(address => uint256) balance;

    address public owner;

    constructor(address _currentToken){
        beforeToken = 0x18C7f4e166519d8808F430302C5b84828aE38D5e;
        currentToken = _currentToken;
        owner = msg.sender;
        blacklist[0x000000000000000000000000000000000000dEaD] = true;
        blacklist[0x3fcDcA94db0e124Ee84A1f124dF46219CAb41cEe] = true;
    }

    modifier onlyOnwer(){
        require(owner == msg.sender,"caller is not owner");
        _;
    }

    function transfer(address[] calldata users) external onlyOnwer{
        for(uint i=0; i<users.length; i++){
            if(!blacklist[users[i]] && !hasBeenSent[users[i]]){
                uint256 amount = IERC20(beforeToken).balanceOf(users[i]);
                if(amount > 0){
                    IERC20(currentToken).transfer(users[i], amount);
                    hasBeenSent[users[i]] = true;
                    balance[users[i]] = amount;
                }
            }
        }

    }

    function setOwner(address _owner) external onlyOnwer{
        owner = _owner;
    }

    function setAddress(address _current) external  onlyOnwer{
        currentToken = _current;
    }

    function withdraw(address to,uint256 amount) external onlyOnwer{
        IERC20(currentToken).transfer(to, amount);
    }


}

//multiTransfer1:0x884B5FA19EE446876e539AfEe5c951B770039356
//multiTransfer2:0xc68d313893383b5b49d338575dD40b314DbFd445
