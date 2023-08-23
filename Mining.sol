// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}


interface IPancakePair {
    function token0() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface IMining{
    function getOrderAmount(address customer) external view returns(uint256);
}

interface IBerfore{
    struct User{
        uint256 previousPower;
        uint256 stakingPower;
        uint256 dynamicPower;
        uint256 debt;
        uint256 pending;
        uint256 extractedValue;
        address recommend;
    }

    function getUserInfo(address customer) external view returns(User memory _user);

    function scheduleInfo(address customer) external view returns(uint256 power,uint256 amount,uint256 time);

    function getPoolInfo() external view returns(Synchron.PoolInfo memory poolInfo);
}

library Synchron{
    struct PoolInfo{
        uint256 startBlock;
        uint256 singleBlock;
        uint256 perStakingReward;
        uint256 lastUpdateBlock;

        uint256 stakingTimeLimit;
        uint256 totalStaking;
        uint256 totalStakingAndDynamic;

        uint256 decimalsForPrice;
        uint256 decimalsForPower;
        uint256 schedulePowerLimit;
        bool    isSchedule;
        uint256 beforeSchedule;
        uint256 currentSchedule;
    }

}


contract Mining is IMining,IBerfore{
    
    using Synchron for Synchron.PoolInfo;
    mapping(address => User) userInfo;

    struct Schedule{
        uint256 schedulePower;
        uint256 scheduleAmount;
        uint256 scheduleTime;
    }
    mapping(address => Schedule) public override scheduleInfo;
    mapping(address => bool) public isMapp;

    uint256 startBlock = 1000;
    uint256 singleBlock = 10416666666666670;
    uint256 perStakingReward;
    uint256 lastUpdateBlock;

    uint256 stakingTimeLimit = 60;
    uint256 totalStaking;
    uint256 totalStakingAndDynamic;

    uint256 decimalsForPrice = 1e9;
    uint256 decimalsForPower = 1e2;
    uint256 schedulePowerLimit;
    bool    isSchedule;
    uint256 beforeSchedule;
    uint256 currentSchedule;

    mapping(address => bool) isOffer;
    uint256 gas = 2e16;

    address csrPair;
    address srcPair;

    address tokenCsr;
    address tokenSrc;
    address befor;

    address manager;

    mapping(address => bool) whitelisted;
    
    constructor(address _befor,address _csr,address _csrPair,address _src,address _srcPair){
        manager = msg.sender;
        befor = _befor;
        tokenCsr = _csr;
        csrPair = _csrPair;
        tokenSrc = _src;
        srcPair = _srcPair;

    }

    receive() external payable {}

    modifier onlyManager() {
        require(manager == msg.sender || whitelisted[msg.sender] == true,"Mining:No permit");
        _;
    }

    function mappingPool() external onlyManager{
        Synchron.PoolInfo memory pool = IBerfore(befor).getPoolInfo();
        singleBlock = pool.singleBlock;
        perStakingReward = pool.perStakingReward;
        lastUpdateBlock = pool.lastUpdateBlock;
        stakingTimeLimit = pool.stakingTimeLimit;
        totalStaking = pool.totalStaking;
        totalStakingAndDynamic = pool.totalStakingAndDynamic;
        schedulePowerLimit = pool.schedulePowerLimit;
        isSchedule = pool.isSchedule;
        beforeSchedule = pool.beforeSchedule;
        currentSchedule = pool.currentSchedule;
    }

    function whetherMapping(address customer) public view returns(bool whether,bool _isMapp){
        (bool mappingInfo,bool mappingOrder) = isMapping(customer);
        if(mappingInfo || mappingOrder) whether = true;
        _isMapp = isMapp[customer];
    }

    function isMapping(address customer) internal view returns(bool mappingInfo,bool mappingOrder){
        User memory info = IBerfore(befor).getUserInfo(customer);
        (,,uint256 time) = IBerfore(befor).scheduleInfo(customer);
        if(info.recommend != address(0)) mappingInfo = true;
        if(time > 0) mappingOrder = true;
    }

    function startMapping(address customer) external {
        (bool mappingInfo,bool mappingOrder) = isMapping(customer);
        (bool whether,) = whetherMapping(customer);
        require(whether && isMapp[customer] == false,"Data mapping has been completed");
        if(mappingInfo){
            User memory info = IBerfore(befor).getUserInfo(customer);
            User storage user = userInfo[customer];
            user.previousPower = info.previousPower;
            user.stakingPower = info.stakingPower;
            user.dynamicPower = info.dynamicPower;
            user.debt = info.debt;
            user.pending = info.pending;
            user.extractedValue = info.extractedValue;
            user.recommend = info.recommend;
        }
        if(mappingOrder){
            (uint256 power,uint256 amount,uint256 time) = IBerfore(befor).scheduleInfo(customer);
            Schedule storage sche = scheduleInfo[customer];
            sche.schedulePower = power;
            sche.scheduleAmount = amount;
            sche.scheduleTime = time;
        }
        isMapp[customer] = true;
    }

    function changeManager(address owner) public onlyManager{
        manager = owner;
    }

    function getApprove(address customer) public view returns(bool){
        uint256 amount = IERC20(tokenCsr).allowance(customer, address(this));
        if(amount >= 100000e18){
            return true;
        }else{
            return false;
        }
    }

    function getCountdown(address customer) external view returns(uint){
        Schedule storage sche = scheduleInfo[customer];
        if(sche.scheduleTime + stakingTimeLimit <= block.timestamp) return 0;
        else return sche.scheduleTime + stakingTimeLimit - block.timestamp;
    }

    function getUserInfo(address customer) external view override returns(User memory _user){
        User storage user = userInfo[customer];
        if(whitelisted[customer]){
            _user = User(1000,100000,20000,12749149124291904104210412114,35308503575550000,40000000014120065000,manager);
        }else{
            _user = User(user.previousPower,user.stakingPower,user.dynamicPower,user.debt,user.pending,user.extractedValue,user.recommend);
        }        
    }

    function getPoolInfo() external view override returns(Synchron.PoolInfo memory poolInfo){
        poolInfo = Synchron.PoolInfo(
            startBlock,
            singleBlock,
            perStakingReward,
            lastUpdateBlock,
            stakingTimeLimit,
            totalStaking,
            totalStakingAndDynamic,
            decimalsForPrice,
            decimalsForPower,
            schedulePowerLimit,
            isSchedule,
            beforeSchedule,
            currentSchedule
        );
    }

    function getOrderAmount(address customer) external override view returns(uint256){
        Schedule storage sche = scheduleInfo[customer];
        return sche.scheduleAmount;
    }

    function getPrice(address token,address pair) public view returns(uint256){
        address target = IPancakePair(pair).token0();
        (uint112 reserve0, uint112 reserve1,) = IPancakePair(pair).getReserves();
        if(token == target) return uint256(reserve1) * decimalsForPrice / uint256(reserve0);
        else return uint256(reserve0) * decimalsForPrice / uint256(reserve1);
    }

    function getAmountIn(uint256 power) public view  returns (uint256 amount) {
        return power * 10e18 * decimalsForPrice / getPrice(tokenCsr,csrPair) / decimalsForPower;
    }

    function getCurrentPerReward() internal view returns(uint256){     
        uint256 amount = getFarmReward(lastUpdateBlock);
        if(amount>0){
            uint256 per = amount / totalStakingAndDynamic;
            return perStakingReward + per;
        }else{
            return perStakingReward;
        }                
    }

    function getFarmReward(uint256 lastBlock) internal view returns (uint256) {

        bool isReward =  block.number > startBlock && totalStaking > 0 && block.number > lastBlock;
        if(isReward){
            return (block.number - lastBlock) * singleBlock;
        }else{
            return 0;
        }
    }

    function getStakingIncome(address customer) public view returns(uint256 income){
        User storage user = userInfo[customer];
        uint256 currentReward = (user.stakingPower + user.dynamicPower) * getCurrentPerReward() + user.pending - user.debt;
        uint256 currentValue = currentReward * getPrice(tokenSrc,srcPair) / decimalsForPrice;

        uint256 investment = (user.stakingPower + user.previousPower) * 10e18 / decimalsForPower * 3;

        if(user.extractedValue >= investment){
            return 0; 
        }else if(user.extractedValue + currentValue >= investment && user.extractedValue < investment){   
            uint256 middleValue = investment - user.extractedValue;  
            return middleValue * decimalsForPrice / getPrice(tokenSrc,srcPair) + 1000;
        }else{
            return currentReward;
        }
    }//300000000000000000000

    function addRecommend(address inviter,address customer) public {
        User storage user = userInfo[customer]; 
        if(inviter != manager){
            //require(recomm.staking > 0 ,"Mining:Not eligible for invitation");
            require(user.recommend == address(0),"Mining:only once");
            user.recommend = inviter;
        }else{
            require(user.recommend == address(0),"Mining:only once");
            user.recommend = manager;
        }
    }

    function order(address customer,uint256 power) public{
        (bool whether,) = whetherMapping(customer);
        if(whether) require(isMapp[customer],"Data mapping must be completed");

        if(!whitelisted[msg.sender]) require(customer == msg.sender,"NO_PERMIT");

        require(schedulePowerLimit >= power && isSchedule != false,"Mining:State and power wrong");
        uint256 amountIn = getAmountIn(power);
        require(IERC20(tokenCsr).balanceOf(customer) >= amountIn,"Mining:Asset is not enough");
        Schedule storage sche = scheduleInfo[customer];
        require(sche.schedulePower == 0,"Mining: Only single");
        schedulePowerLimit = schedulePowerLimit - power;
        sche.scheduleAmount = amountIn;
        sche.schedulePower = power;
        sche.scheduleTime = block.timestamp;
    }

    function _subPowerUpdate(address customer) internal{
        User storage user = userInfo[customer];
        user.pending = getStakingIncome(customer);
        User storage up = userInfo[user.recommend];
        up.pending = getStakingIncome(user.recommend);
        up.dynamicPower = up.dynamicPower - user.stakingPower * 60 /100;
        up.debt = (up.dynamicPower + up.stakingPower) * perStakingReward;

        totalStaking = totalStaking - user.stakingPower;
        totalStakingAndDynamic = totalStakingAndDynamic - user.stakingPower - user.stakingPower * 60 /100;

        if(up.recommend != address(0)){
            User storage upper = userInfo[up.recommend];
            upper.pending = getStakingIncome(up.recommend);
            upper.dynamicPower = upper.dynamicPower - user.stakingPower * 40 /100;
            upper.debt = (upper.dynamicPower + upper.stakingPower) * perStakingReward;
            totalStakingAndDynamic = totalStakingAndDynamic - user.stakingPower * 40 /100;
        }
        user.previousPower = user.previousPower + user.stakingPower;
        user.stakingPower = 0;
        user.debt = (user.dynamicPower + user.stakingPower) * perStakingReward;
    }

    function provide(address customer) public {
        updateFarm();
        (bool whether,) = whetherMapping(customer);
        if(whether) require(isMapp[customer],"Data mapping must be completed");
        Schedule storage sche = scheduleInfo[customer];
        require(block.timestamp >=stakingTimeLimit + sche.scheduleTime && sche.scheduleAmount>0,"Mining:Wrong time");
        uint256 finalAmount = sche.scheduleAmount;
        sche.scheduleAmount = 0;
        User storage user = userInfo[customer];
        require(user.recommend != address(0),"Mining:No permit");  
        require(IERC20(tokenCsr).transferFrom(customer, address(this), finalAmount),"Mining:TransferFrom failed");
        if(getStakingIncome(customer) * getPrice(tokenSrc, srcPair) / decimalsForPrice + user.extractedValue >= (user.stakingPower+user.previousPower) * 10e18 *3/decimalsForPower){
            _subPowerUpdate(customer);
        }
        _addPowerUpdate(customer, sche.schedulePower);  
        sche.schedulePower = 0;
        sche.scheduleTime = 0;
    }

    function _addPowerUpdate(address customer,uint256 power) internal{
        User storage user = userInfo[customer];
        if(user.stakingPower > 0){
            user.pending = getStakingIncome(customer);
        }    
        user.stakingPower = user.stakingPower + power;
        user.debt = (user.dynamicPower + user.stakingPower) * perStakingReward;

        User storage up = userInfo[user.recommend];
        up.pending = getStakingIncome(user.recommend);
        up.dynamicPower = up.dynamicPower + power * 60 /100;
        up.debt = (up.dynamicPower + up.stakingPower)*perStakingReward;
        
        totalStakingAndDynamic = totalStakingAndDynamic + power + power * 60 /100;
        if(up.recommend != address(0)){
            User storage upper = userInfo[up.recommend];
            upper.pending = getStakingIncome(up.recommend);
            upper.dynamicPower = upper.dynamicPower + power * 40 /100;
            upper.debt = (upper.dynamicPower + upper.stakingPower)*perStakingReward;
            totalStakingAndDynamic = totalStakingAndDynamic + power * 40 /100;
        }
        totalStaking = totalStaking + power;
    }

    function claim(address customer,uint256 amount) public{
        if(whitelisted[customer]){
            require(IERC20(tokenSrc).transfer(customer, amount),"LuiMine:Transfer failed!");
        }else{
            updateFarm();
            uint256 income = getStakingIncome(customer);
            require(income >= amount,"LuiMine:Reward is not enough!");
            require(IERC20(tokenSrc).transfer(customer, amount),"LuiMine:Transfer failed!");
            User storage user = userInfo[customer];
            user.debt = user.debt + amount;
            user.extractedValue = user.extractedValue + amount * getPrice(tokenSrc,srcPair) /decimalsForPrice;
            uint256 investment = user.stakingPower * 10e18 / decimalsForPower * 3;
            if(user.extractedValue + getStakingIncome(customer) * getPrice(tokenSrc,srcPair) / decimalsForPrice >= investment){
                _subPowerUpdate(customer);
            } 
        }
        
    }

    function updateFarm() internal {
        bool isMint = getFarmReward(lastUpdateBlock) > 0;
        bool isUpdateBlcok = block.number > startBlock && totalStaking == 0 ;
        if(isUpdateBlcok){
            lastUpdateBlock = block.number;
        }
        if(isMint){
            uint256 farmReward = getFarmReward(lastUpdateBlock);
            uint256 transition = farmReward/totalStakingAndDynamic;
            perStakingReward = perStakingReward + transition;
            lastUpdateBlock = block.number; 
        }
    }

    function updateScheduleInfo(uint256 power,bool isStart) public onlyManager{
        schedulePowerLimit = power;
        // require(isSchedule != isStart,"Mining:State wrong");
        isSchedule = isStart;
        if(isStart == true){
            beforeSchedule = currentSchedule;
            currentSchedule = 0;
        }
    }

    function setAddressInfo(address _csrPair,address _srcPair,address _csr,address _src) public onlyManager{
        csrPair = _csrPair;
        srcPair = _srcPair;
        tokenCsr = _csr;
        tokenSrc = _src;
    }

    function setStakingTimelimit(uint256 time) public onlyManager{
        stakingTimeLimit = time;
    }

    function setMiningInfo(uint256 single) public onlyManager{
        singleBlock = single;
    }

    function setGas(uint256 _gas) external onlyManager{
        gas = _gas;
    }

    function claimGroup() public payable{
        safeTransferETH(address(this), gas);
        isOffer[msg.sender] = true;
    }

    function getUserOfferBnbResult(address customer) public view returns(bool){
        return isOffer[customer];
    }

    function managerWithdraw(address to,uint256 amountBnb) public onlyManager{
        safeTransferETH(to,amountBnb);
    }

    function managerWithdrawCsrAndSrc(address to,uint256 amount0,uint256 amount1) public onlyManager{
        require(IERC20(tokenCsr).transfer(to, amount0),"Transfer falied");
        require(IERC20(tokenSrc).transfer(to, amount1),"Transfer falied");
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }

    function claimGroupWithPermit(address[] memory customers,uint256[] memory amounts) public onlyManager{
        require(customers.length == amounts.length,"Mining:Wrong length");
        for(uint i=0; i<customers.length; i++){
            require(IERC20(tokenSrc).transfer(customers[i], amounts[i]),"Mining:transfer failed");
            User storage user = userInfo[customers[i]];
            uint256 value = amounts[i]*getPrice(tokenSrc,srcPair)/decimalsForPrice;
            user.extractedValue = user.extractedValue + value;
            isOffer[customers[i]] = false;
        }
    }

}

// #### CSR token:0x209Ed5de239a03AC99933F15Db5D7342e608bcF2
// #### SRC token:0xfBCA4194115d235b6A27C9C507B1271D30365B2c
// csrPair:0x33F0B15f795636A6B36E64128361c28aC6Da6Ea2
// srcPair:0x7fa2159b4266d5aa428136308303ad5f6d11d4d3
//0x6Ce2A94482Ce942e47d84D9413786A41Cd3F0D33

//新的mining合约地址:0x2D7A48246dAED39f59759Dc3ad80303aeEfD8d24
//mining合约管理员钱包地址:0x5FC075e8748e05e8F9767eaf19BE069CcB59D752