// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

contract PledageStor{
    address public admin;
}

contract PledageStorV1 is PledageStor{
    address public wcore;
    address public token;
    address public receiver;
    address public dead;
    address public uniswapV2Router;
    address public uniswapV2Factory;

    struct User{
        uint256 computility;
        uint256 extractedCore;
        uint256 reward;
        uint256 rewardDebt;
    }
    mapping(address => User) public userInfo;
    mapping(address => address) public inivter;
    uint256 perStakingReward;
    uint256 public totalComputility;
    uint256 perBlockReward;
    uint256 lastUpdateBlock;
    uint256 decimals;
}

interface IUniswapV2Router{
    function WETH() external pure returns (address);
    function factory() external pure returns (address);
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

library TransferHelper {
    function safeTransfer(address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }
    function safeTransferFrom(address token, address from, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }
    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}

library SafeMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}

library UniswapV2Library {
    using SafeMath for uint;

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'a57c851609a8fcdbd487af40434318d1638415d0d74defa8b4848c9c1b35fa35' // init code hash
            )))));
    }

    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }
}

contract BatchPledage is PledageStorV1{

    constructor(){
        admin = msg.sender;
    }

    receive() external payable{}

    modifier onlyOwner() {
        require(msg.sender == admin,"Caller is not owner");
        _;
    }

    function initialize(address _uniswapV2Router,address token,address _receiver,uint256 _dayReward) external onlyOwner{
        wcore = IUniswapV2Router(_uniswapV2Router).WETH();
        token = token;
        receiver = _receiver;
        dead = 0x000000000000000000000000000000000000dEaD;
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Factory = IUniswapV2Router(_uniswapV2Router).factory();
        perBlockReward = _dayReward / (86400 / 3);
        decimals = 1e12;
        lastUpdateBlock = block.number;
    }

    function setInfo(address _receiver,uint256 _dayReward) external onlyOwner{
        receiver = _receiver;
        perBlockReward = _dayReward / (86400 / 3);
    }

    function setOwner(address _admin) external onlyOwner{
        admin = _admin;
    }

    function provide(address customer,uint256 amount) external payable{
        require(amount == getAmountOut(msg.value,wcore,token),"BatchPledage:Invalid provide token and core amount");
        sendHelper(customer, amount, msg.value);
        updateFarm();
        User storage user = userInfo[customer];
        user.computility = user.computility + (msg.value * 2);
        user.rewardDebt = user.rewardDebt + (msg.value * 2 * perStakingReward);
        totalComputility = totalComputility + (msg.value * 2);

    }

    function getAmountOut(uint256 amountIn,address token0,address token1) public view returns(uint256 amountOut){
        (uint reserveIn, uint reserveOut) = UniswapV2Library.getReserves(uniswapV2Factory, token0, token1);
        amountOut = UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function sendHelper(address user,uint256 amount, uint256 value) public{
        //token transfer
        {
            uint256 tokenAmount = amount;
            address inivter0 = inivter[user];
            if(inivter0 != address(0)){
                uint256 rewardFee0 = tokenAmount * 20 / 100;
                TransferHelper.safeTransferFrom(token, user, inivter0,rewardFee0);
                tokenAmount -= rewardFee0;
                address inivter1 = inivter[inivter0];
                if(inivter1 != address(0)){
                    uint256 rewardFee1 = tokenAmount * 10 / 100;
                    TransferHelper.safeTransferFrom(token, user, inivter1,rewardFee1);
                    tokenAmount -= rewardFee1;
                }
            }
            TransferHelper.safeTransferFrom(token, user, dead, tokenAmount);
        }
        //core transfer
        {
            uint256 swapValue = value * 60 / 100;
            TransferHelper.safeTransferETH(address(this), swapValue);
            TransferHelper.safeTransferETH(receiver, value - swapValue);
            swapETHForCOY(swapValue);
        }
        
    }

    function swapETHForCOY(uint256 amount) public{
        address[] memory path = new address[](2);
        path[0] = IUniswapV2Router(uniswapV2Router).WETH();
        path[1] = token;
        IUniswapV2Router(uniswapV2Router).swapExactETHForTokensSupportingFeeOnTransferTokens{value:amount}(
            0, 
            path, 
            dead, 
            block.timestamp
        );
    }

    function getCurrentBlockReward() public view returns(uint256){
        if(block.number <= lastUpdateBlock){
            return perBlockReward;
        }
        uint256 middleReward = (block.number - lastUpdateBlock) * perBlockReward * decimals / totalComputility;
        return middleReward + perBlockReward;
    }

    function getUserCurrentReward(address customer) public view returns(uint256){
        uint256 currentBlockReward = getCurrentBlockReward();
        User storage user = userInfo[customer];
        if(user.extractedCore >= user.computility * 3) return 0;
        else{
            uint256 difference = user.computility * 3 - user.extractedCore;
            uint256 currentReward = (user.computility * currentBlockReward - user.rewardDebt) / decimals;
            uint256 deserved = getAmountOut(difference, wcore, token);
            if(currentReward <= deserved) return currentReward;
            else return deserved;
        }
    }

    function updateFarm() public{

        if(block.number <= lastUpdateBlock){
            return;
        }

        if(totalComputility >= 10000e18) perBlockReward = perBlockReward * 50 / 100;
        if(totalComputility >= 30000e18) perBlockReward = perBlockReward * 70 / 100;

        uint256 middleReward = (block.number - lastUpdateBlock) * perBlockReward * decimals / totalComputility;
        perStakingReward += middleReward;
        lastUpdateBlock = block.number;
    }

    function claim(address customer,uint256 amount) external{
        uint256 deserved = getUserCurrentReward(customer);
        require(amount <= deserved && amount > 0,"Claim:Invalid claim amount");
        updateFarm();
        uint256 extracted = getAmountOut(amount, token, wcore);
        TransferHelper.safeTransfer(token, customer, amount);
        User storage user = userInfo[customer];
        user.extractedCore += extracted;
        user.rewardDebt = user.rewardDebt + (amount * decimals);
    }

}