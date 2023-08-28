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

    struct Info{
        User    user;
        address inv;
        uint256 income;
    }

    struct Team{
        address recommend;
        uint256 amount;
        uint256 createTime;
    }

    mapping(address => User) public userInfo;
    mapping(address => address) public inviter;
    mapping(address => bool) public initialInviter;
    mapping(address => Team[]) teamInfo;
    uint256 perStakingEarnings;
    uint256 public totalComputility;
    uint256 perBlockAward;
    uint256 lastUpdateBlock;
    uint256 public decimals;
    bool    public permission;

    enum Base{inital,first,two}
    mapping(Base => uint256) blockAwardBase;
    
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

    function initialize(address _receiver,uint256[] calldata _bases,address[] calldata _inviters) external onlyOwner{
        require(_bases.length == 3,"BatchPledage:Invalid block bases");
        uniswapV2Router = 0x4ee133a21B2Bd8EC28d41108082b850B71A3845e;
        wcore = IUniswapV2Router(uniswapV2Router).WETH();
        token = 0xf49e283b645790591aa51f4f6DAB9f0B069e8CdD;
        receiver = _receiver;
        dead = 0x000000000000000000000000000000000000dEaD;
        uniswapV2Factory = IUniswapV2Router(uniswapV2Router).factory();
        perBlockAward = _bases[0] / (86400 / 3);
        blockAwardBase[Base.inital] = _bases[0];
        blockAwardBase[Base.first] = _bases[1];
        blockAwardBase[Base.two] = _bases[2];
        decimals = 1e12;
        lastUpdateBlock = block.number;
        for(uint i=0; i<_inviters.length; i++){
            if(!initialInviter[_inviters[i]]){
                initialInviter[_inviters[i]] = true;
            }
        }
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
        require(_inviter != address(0) && inviter[msg.sender] == address(0),"Invalid inviter");
        if (!initialInviter[_inviter]) {
            User memory user = userInfo[_inviter];
            require(user.computility > 0,"BatchPledage:Not eligible to invite new users");
        }
        inviter[msg.sender] = _inviter;
    }

    function provide(address customer) external payable onlyPermit{
        //这里需要补充msg.value的值最小为100
        require(inviter[customer] != address(0),"BatchPledage:The address of the inviter must be bound");
        uint256 amount = getAmountOut(msg.value,wcore,token);
        sendHelper(customer, amount, msg.value);
        if (totalComputility > 0) updateFarm();
        User storage user = userInfo[customer];
        uint256 computilities = msg.value * 2;
        user.computility += computilities;
        user.rewardDebt = user.rewardDebt + computilities * perStakingEarnings;
        totalComputility += computilities;
    }

    function getAmountOut(uint256 amountIn,address token0,address token1) public view returns(uint256 amountOut){
        (uint reserveIn, uint reserveOut) = UniswapV2Library.getReserves(uniswapV2Factory, token0, token1);
        amountOut = UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function sendHelper(address user,uint256 amount, uint256 value) public{
        //token award
        {   
            address inivter0 = inviter[user];
            if(inivter0 != address(0)){
                User storage user0 = userInfo[inivter0];
                uint256 rewardFee0 = amount * 20 / 100;
                user0.award += rewardFee0;
                teamInfo[inivter0].push(Team(user,rewardFee0,block.timestamp));
                address inivter1 = inviter[inivter0];
                if(inivter1 != address(0)){
                    uint256 rewardFee1 = amount * 10 / 100;
                    User storage user1 = userInfo[inivter1];
                    user1.award += rewardFee1;
                    teamInfo[inivter1].push(Team(user,rewardFee1,block.timestamp));
                }
            }
            uint256 award = amount * 30 / 100;
            TransferHelper.safeTransferFrom(token, user, address(this), award);
            TransferHelper.safeTransferFrom(token, user, dead, amount - award);
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

    function getCurrentPerStakingEarnings() public view returns(uint256){
        if (totalComputility == 0) return 0;
        if(block.number <= lastUpdateBlock) return perStakingEarnings;
        uint256 middleStakingEarnings = (block.number - lastUpdateBlock) * perBlockAward * decimals / totalComputility;
        return middleStakingEarnings + perStakingEarnings;
    }

    function getUserCurrentEarnings(address customer) public view returns(uint256){
        uint256 currentPerStakingEarnings = getCurrentPerStakingEarnings();
        User storage user = userInfo[customer];
        if(user.extractedCore >= user.computility * 3 || user.computility == 0) return 0;
        else{
            uint256 difference = user.computility * 3 - user.extractedCore;
            uint256 currentEarnings = (user.computility * currentPerStakingEarnings - user.rewardDebt) / decimals;
            uint256 deserved = getAmountOut(difference, wcore, token);
            if(currentEarnings <= deserved) return currentEarnings;
            else return deserved;
        }
    }

    function updateFarm() public{

        if(block.number <= lastUpdateBlock || totalComputility == 0){
            lastUpdateBlock = block.number;
            return;
        }
        bool first = totalComputility >= 30000e18 && totalComputility <= 50000e18 && perBlockAward < blockAwardBase[Base.first] / (86400 / 3);
        if(first) perBlockAward = blockAwardBase[Base.first] / (86400 / 3);
        bool two = totalComputility >= 50000e18 && perBlockAward < blockAwardBase[Base.two] / (86400 / 3);
        if(two) perBlockAward = blockAwardBase[Base.two] / (86400 / 3);

        uint256 middlePerStakingEarnings = (block.number - lastUpdateBlock) * perBlockAward * decimals / totalComputility;
        perStakingEarnings += middlePerStakingEarnings;
        lastUpdateBlock = block.number;
    }

    function claim(address customer,uint256 amount) external onlyPermit{
        uint256 deserved = getUserCurrentEarnings(customer);
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
        return Info(userInfo[customer],inviter[customer],getUserCurrentEarnings(customer));
    }

    function getUserOfTeamInfo(address customer) external view returns(Team[] memory){
        return teamInfo[customer];
    }

    function emergencyWithETH(address to,uint256 amount) external onlyOwner{
        TransferHelper.safeTransferETH(to,amount);
    }

    function emergencyWithCOY(address to,uint256 amount) external onlyOwner{
        TransferHelper.safeTransfer(token,to,amount);
    }

}

//000000000000000000
// receiver:0xc7384Aaf0c8231AfE211e52f129ae3B29f358F6A
//5000\7000\10000
//["0xc9fc71fF0Ad342d7D0E6cCBD7C4234E98aC83369","0x0d17B54dc4507D0Abf27bd49cfB248b7eE4056d0","0x427DfD8Ec77a9226E038Ada1A12055eDc544B440"]
//pledage:0x8de0201796591368494CF0fB819Faf9656Ea2417
//proxy:0x8C5dDb0006cFa9C4478f65D9e1ccD24c3843bCbC
