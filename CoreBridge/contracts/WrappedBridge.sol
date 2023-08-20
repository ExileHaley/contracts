// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {BridgeBase} from "./BridgeBase.sol";
import {LzLib} from "@layerzerolabs/solidity-examples/contracts/libraries/LzLib.sol";
import {IWrappedERC20} from "./interface/IWrappedERC20.sol";

contract WrappedBridge is BridgeBase{
    //local token => remote chainid => remote token
    mapping (address => mapping (uint16 => address)) public localToRemoteAddress;
    //remote token => remote chianId => local token
    mapping (address => mapping (uint16 => address)) public remoteToLocalAddress;
    //remote chainid => remote token => token amount
    mapping (uint16 => mapping (address => uint)) public totalValueLocked;

    uint16 public constant TOTAL_BPS = 10000;

    uint16 public bridgeFeeBps;

    event Wrapped(address localToken, address remoteToken, uint16 remoteChainId, address to, uint amount);
    event Unwrapped(address localToken, address remoteToken, uint16 remoteChainId, address to, uint amount);
    event RegisterToken(address local,uint16 remoteChainId,address remote);
    event SetBridgeFee(uint fee);

    constructor(address _endpoint) BridgeBase(_endpoint) {}
    //register token
    function registerToken(address local,uint16 remoteChainId,address remote) external  onlyOwner{
        require(local != address(0) && remote != address(0),"WrappedBridge:Invalid local/romte address");
        require(localToRemoteAddress[local][remoteChainId] == address(0) &&
                remoteToLocalAddress[remote][remoteChainId] == address(0),
                "WrappedBridge:Already register");
        localToRemoteAddress[local][remoteChainId] = remote;
        remoteToLocalAddress[remote][remoteChainId] = local;
        emit RegisterToken(local, remoteChainId, remote);
    }

    function setBridgeFeeBps(uint16 _feeBps)external onlyOwner{
        require(_feeBps < TOTAL_BPS,"WrappedBridge:Invalid fee bps");
        bridgeFeeBps = _feeBps;
        emit SetBridgeFee(_feeBps);
    }

    function estimateGasFee(
        uint16 remoteChainId,
        bool useZero,
        bytes calldata adapterParam
        )external view returns (uint nativeFee, uint zroFee)
    {
        bytes memory payload = abi.encode(PT_UNLOCK,address(this),address(this),0,0,false);
        return lzEndpoint.estimateFees(remoteChainId, address(this), payload, useZero, adapterParam);
    }

    function bridge(
        address localToken,
        uint16 remoteChainId,
        address to,
        uint amountInto,
        bool unwrapWeth, 
        LzLib.CallParams calldata callParams, 
        bytes memory adapterParams) 
        external 
        payable nonReentrant
    {   
        require(to != address(0) && amountInto > 0,"WrappedBridge:Invalid to address and amount params");
        _checkAdapterParams(remoteChainId, PT_UNLOCK, adapterParams);
        address remoteToken = localToRemoteAddress[localToken][remoteChainId];
        require(remoteToken!=address(0),"WrappedBridge:Invalid token address");
        require(totalValueLocked[remoteChainId][remoteToken] >= amountInto,"WrappedBridge:Invalid cross amount");

        totalValueLocked[remoteChainId][remoteToken] -= amountInto;
        IWrappedERC20(localToken).burn(msg.sender,amountInto);

        uint withdrawAmount = amountInto;
        if (bridgeFeeBps > 0){
            uint bridgeFee = withdrawAmount * bridgeFeeBps / TOTAL_BPS;
            withdrawAmount -= bridgeFee;
        }
        bytes memory payload = abi.encode(PT_UNLOCK,remoteToken,to,withdrawAmount,amountInto,unwrapWeth);
        _lzSend(remoteChainId, payload, callParams.refundAddress, callParams.zroPaymentAddress, adapterParams, msg.value);
        emit Unwrapped(localToken, remoteToken, remoteChainId, to, amountInto);
    }


    function _nonblockingLzReceive(
        uint16 srcChainId, 
        bytes memory, 
        uint64, 
        bytes memory payload
    ) internal virtual override
    {
        
        (uint8 pkType,address remoteToken,address to,uint amount) = abi.decode(payload,(uint8,address,address,uint));
        require(pkType == PT_MINT,"WrappedBridge:Invalid pkType");
        address localToken = remoteToLocalAddress[remoteToken][srcChainId];
        require(localToken != address(0),"WrappedBridge:Invalid local token address");
        
        totalValueLocked[srcChainId][remoteToken] += amount;
        IWrappedERC20(localToken).mint(to,amount);
        emit Wrapped(localToken, remoteToken, srcChainId, to, amount);
    }
}

//ethOriginalBridge:0x057C6c17C1ea13fD4372D1e2592Db7Cb92C3F4A4
//wrappedBridge:0xf9Cb6Df708f99D45CbaaEbaF58cb3F734b272683
//["0x175e79766F7D27dEbe5787ab12a0Afc9488F68E0","0x0000000000000000000000000000000000000000"]
//63 000000000000000000