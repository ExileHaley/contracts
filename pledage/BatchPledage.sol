// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

contract PledageStor{
    address public admin;
    address public implementation;
}

contract Proxy is PledageStor{
    receive() external payable {}
    constructor() {
        admin = msg.sender;
    }

    modifier onlyOwner(){
        require(admin == msg.sender,"Proxy:Caller is not owner");
        _;
    }

    function _updateAdmin(address _admin) public onlyOwner{
        admin = _admin;
    }

    function setImplementation(address newImplementation) public onlyOwner{  
        implementation = newImplementation;
    }

    fallback() payable external {
        // delegate all other functions to current implementation
        (bool success, ) = implementation.delegatecall(msg.data);

        assembly {
              let free_mem_ptr := mload(0x40)
              returndatacopy(free_mem_ptr, 0, returndatasize())

              switch success
              case 0 { revert(free_mem_ptr, returndatasize()) }
              default { return(free_mem_ptr, returndatasize()) }
        }
    }
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
        uint256 rewardDebt;
        uint256 award;
    }
    mapping(address => User) public userInfo;
    mapping(address => address) public inivter;
    uint256 perStakingReward;
    uint256 public totalComputility;
    uint256 perBlockAward;
    uint256 lastUpdateBlock;
    uint256 public decimals;
    bool    public permission;

    struct Info{
        User    user;
        address inv;
        uint256 income;
    }
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

    modifier onlyPermit(){
        require(!permission, "Do not approve the current operation");
        _;
    }

    function initialize(address _uniswapV2Router,address _token,address _receiver,uint256 _dayReward) external onlyOwner{
        wcore = IUniswapV2Router(_uniswapV2Router).WETH();
        token = _token;
        receiver = _receiver;
        dead = 0x000000000000000000000000000000000000dEaD;
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Factory = IUniswapV2Router(_uniswapV2Router).factory();
        perBlockAward = _dayReward / (86400 / 3);
        decimals = 1e12;
        lastUpdateBlock = block.number;
    }

    function setInfo(address _receiver) external onlyOwner{
        receiver = _receiver;
        
    }

    function setPerBlockReward(uint256 _dayReward) external onlyOwner{
        perBlockAward = _dayReward / (86400 / 3);
    }

    function setOwner(address _admin) external onlyOwner{
        admin = _admin;
    }

    function setPermission(bool _isPermit)external onlyOwner{
        permission = _isPermit;
    }

    function bind(address _inviter) external onlyPermit{
        require(_inviter != address(0) && inivter[msg.sender] == address(0),"Invalid inviter");
        if (_inviter != admin) {
            User memory user = userInfo[_inviter];
            require(user.computility > 0,"BatchPledage:Not eligible to invite new users");
        }
        inivter[msg.sender] = _inviter;
    }

    function provide(address customer) external payable onlyPermit{
        //这里需要补充msg.value的值最小为100
        require(inivter[customer] != address(0),"BatchPledage:The address of the inviter must be bound");
        uint256 amount = getAmountOut(msg.value,wcore,token);
        sendHelper(customer, amount, msg.value);
        if (totalComputility > 0) updateFarm();
        User storage user = userInfo[customer];
        uint256 computilities = msg.value * 2;
        user.computility += computilities;
        user.rewardDebt = user.rewardDebt + computilities * perStakingReward;
        totalComputility += computilities;
    }

    function getAmountOut(uint256 amountIn,address token0,address token1) public view returns(uint256 amountOut){
        (uint reserveIn, uint reserveOut) = UniswapV2Library.getReserves(uniswapV2Factory, token0, token1);
        amountOut = UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function sendHelper(address user,uint256 amount, uint256 value) public{
        //token award
        {   
            //这里代币写的有问题，30%并没有直接转进来
            // uint256 tokenAmount = amount;
            // address inivter0 = inivter[user];
            // if(inivter0 != address(0)){
            //     User storage user0 = userInfo[inivter0];
            //     uint256 rewardFee0 = tokenAmount * 20 / 100;
            //     user0.award += rewardFee0;
            //     tokenAmount -= rewardFee0;
            //     address inivter1 = inivter[inivter0];
            //     if(inivter1 != address(0)){
            //         uint256 rewardFee1 = tokenAmount * 10 / 100;
            //         User storage user1 = userInfo[inivter1];
            //         user1.award += rewardFee1;
            //         tokenAmount -= rewardFee1;
            //     }
            // }
            // TransferHelper.safeTransferFrom(token, user, address(this), tokenAmount);
            // TransferHelper.safeTransferFrom(token, user, dead, tokenAmount);
        }
        //core transfer and swap
        {
            uint256 swapValue = value * 60 / 100;
            TransferHelper.safeTransferETH(address(this), swapValue);
            TransferHelper.safeTransferETH(receiver, value - swapValue);

            uint256 ethBalance = address(this).balance;
            if (ethBalance > 0) swapETHForCOY(swapValue);
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

    function getCurrentPerStakingReward() public view returns(uint256){
        if(block.number <= lastUpdateBlock){
            return perStakingReward;
        }
        uint256 middleReward = (block.number - lastUpdateBlock) * perBlockAward * decimals / totalComputility;
        return middleReward + perStakingReward;
    }

    function getUserCurrentReward(address customer) public view returns(uint256){
        uint256 currentPerStakingReward = getCurrentPerStakingReward();
        User storage user = userInfo[customer];
        if(user.extractedCore >= user.computility * 3 || user.computility == 0) return 0;
        else{
            uint256 difference = user.computility * 3 - user.extractedCore;
            uint256 currentReward = (user.computility * currentPerStakingReward - user.rewardDebt) / decimals;
            uint256 deserved = getAmountOut(difference, wcore, token);
            if(currentReward <= deserved) return currentReward;
            else return deserved;
        }
    }

    function updateFarm() public{

        if(block.number <= lastUpdateBlock){
            return;
        }

        if(totalComputility >= 10000e18) perBlockAward = perBlockAward * 50 / 100;
        if(totalComputility >= 30000e18) perBlockAward = perBlockAward * 70 / 100;

        uint256 middleReward = (block.number - lastUpdateBlock) * perBlockAward * decimals / totalComputility;
        perStakingReward += middleReward;
        lastUpdateBlock = block.number;
    }

    function claim(address customer,uint256 amount) external onlyPermit{
        uint256 deserved = getUserCurrentReward(customer);
        require(amount <= deserved && amount > 0,"Claim:Invalid claim amount");
        updateFarm();
        uint256 extracted = getAmountOut(amount, token, wcore);
        TransferHelper.safeTransfer(token, customer, amount);
        User storage user = userInfo[customer];
        user.extractedCore += extracted;
        user.rewardDebt = user.rewardDebt + (amount * decimals);
    }

    function claimAward(address customer, uint256 amount) external onlyPermit{
        User storage user = userInfo[customer];
        require(amount <= user.award,"Claim:Invalid award amount");
        TransferHelper.safeTransfer(token, customer, amount);
        user.award -= amount;
    }

    function getUserInfo(address customer) external view returns(Info memory){
        return Info(userInfo[customer],inivter[customer],getUserCurrentReward(customer));
    }

    function emergencyWithETH(address to,uint256 amount) external onlyOwner{
        TransferHelper.safeTransferETH(to,amount);
    }

    function emergencyWithCOY(address to,uint256 amount) external onlyOwner{
        TransferHelper.safeTransfer(token,to,amount);
    }

}

//uniswapV2Router:0x4ee133a21B2Bd8EC28d41108082b850B71A3845e
//token:0xf49e283b645790591aa51f4f6DAB9f0B069e8CdD
//000000000000000000
//coreReceiver:
//pledage:
//proxy:

//19.134936421088622472
//0.347226909722222221