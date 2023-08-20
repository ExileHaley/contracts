// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CurrencyStor{
    address public admin;
    address public implementation;
}

contract CurrencyStorV1 is CurrencyStor{
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;
    uint256 internal _totalSupply;
    string internal _name;
    string internal _symbol;

    mapping(address => bool) whitelist;
    address public uniswapV2Router;
    address public uniswapV2Pair;
    address public marketing;
    address public fundation;
    address public dead;
    uint256 public feeAccumulated;

    address[] public holders;
    mapping(address => uint256) holderIndex;
    uint256 internal  currentIndex;
    uint256 internal minRewardValue = 5e18;
}

contract Proxy is CurrencyStor{

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

interface IUniswapV2Router {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

contract ERC20 is Context, IERC20, IERC20Metadata, CurrencyStorV1{

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }


    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}


contract CoyVersion is ERC20{
    
    receive() external payable{}

    constructor()ERC20("",""){
        admin = msg.sender;
    }

    modifier onlyOwner(){
        require(admin == msg.sender,"ERC20:Caller is not owner");
        _;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual override {

        bool nonWhite = !whitelist[sender] && !whitelist[recipient];

        bool isSellOrPurchase = recipient == uniswapV2Pair || sender == uniswapV2Pair;

        if (feeAccumulated > 0 && !isSellOrPurchase && sender != uniswapV2Router) {
            uint256 feeBalance = feeAccumulated;
            feeAccumulated = 0;
            swapTokensForEth(feeBalance);
            uint256 newBalance = address(this).balance;
            payable(marketing).transfer(newBalance * 34 / 100);
            payable(fundation).transfer(newBalance * 44 / 100);
        }

        uint256 feeAmount = amount * 11 / 100;

        if (isSellOrPurchase && nonWhite) {
            uint256 burnAmount = feeAmount * 2 / 11; // 2% for burning
            uint256 contractAmount = feeAmount - burnAmount; // 9% for the contract
            feeAccumulated += contractAmount;
            // Burn tokens
            super._transfer(sender, dead, burnAmount);

            // Send tokens to the contract
            super._transfer(sender, address(this), contractAmount);

            amount -= feeAmount;
        }

        super._transfer(sender, recipient, amount);

        if(!isSellOrPurchase  && sender != uniswapV2Router){
            processReward(50000);
        }

        if (IERC20(uniswapV2Pair).balanceOf(sender) > 0) addHolder(sender);
        else removeHolder(sender);
        if (IERC20(uniswapV2Pair).balanceOf(recipient) > 0) addHolder(recipient);
        else removeHolder(recipient);
    }


    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = IUniswapV2Router(uniswapV2Router).WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // Perform the swap here
        IUniswapV2Router(uniswapV2Router).swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp + 10
        );
    }

    function processReward(uint256 gas) private {

        uint256 balance = address(this).balance;
        if (balance < minRewardValue) {
            return;
        }
        
        uint256 totalLP = IERC20(uniswapV2Pair).totalSupply();

        address shareHolder;
        uint256 tokenBalance;
        uint256 amount;

        uint256 shareholderCount = holders.length;

        uint256 gasUsed = 0;
        uint256 iterations = 0;
        uint256 gasLeft = gasleft();

        balance = address(this).balance;

        while (gasUsed < gas && iterations < shareholderCount) {
            if (currentIndex >= shareholderCount) {
                currentIndex = 0;
            }
            shareHolder = holders[currentIndex];
            tokenBalance = IERC20(uniswapV2Pair).balanceOf(shareHolder);

            if (tokenBalance > 0) {
                amount = (balance * tokenBalance) / totalLP;

                if (amount > 0 && address(this).balance > amount) {
                    payable(shareHolder).transfer(amount);
                }

            }

            gasUsed = gasUsed + (gasLeft - gasleft());
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }

    }    

    function addHolder(address user) private  {
        uint256 size;
        assembly {
            size := extcodesize(user)
        }
        if (size > 0) {
            return;
        }

        if (holderIndex[user] == 0) {
            if (holders.length ==0 || holders[0] != user) {
                holderIndex[user] = holders.length;
                holders.push(user);
            }
        }
    }

    function removeHolder(address user) private {
        uint256 indexToRemove = holderIndex[user];
        uint256 size;
        assembly {
            size := extcodesize(user)
        }
        if (indexToRemove == 0 || size > 0) {
            return;
        }
        address lastHolder = holders[holders.length - 1];
        holders[indexToRemove] = lastHolder;
        holderIndex[lastHolder] = indexToRemove;
        holders.pop();
        delete holderIndex[user];
    }

    function initialize(address receiver,address _marketing,address _fundation) external onlyOwner{
        require(totalSupply() == 0, "ERC20:Can`t be repeated");
        _name = "COY Version2.0";
        _symbol = "COY";
        _mint(receiver, 100000000e18);
        uniswapV2Router = 0x4ee133a21B2Bd8EC28d41108082b850B71A3845e;
        uniswapV2Pair = IUniswapV2Factory(IUniswapV2Router(uniswapV2Router).factory()).createPair(
            address(this),
            IUniswapV2Router(uniswapV2Router).WETH()
        );
        dead = 0x000000000000000000000000000000000000dEaD;
        marketing = _marketing;
        fundation = _fundation;
        whitelist[address(this)] = true;

    }

    function setReceiver(address _marketing,address _fundation) external onlyOwner{
        marketing = _marketing;
        fundation = _fundation;
    }

    function setWhitelist(address _addr, bool _isWhite)external onlyOwner{
        whitelist[_addr] = _isWhite;
    }

    function setOwner(address _admin) external onlyOwner{
        admin = _admin;
    }

    function setRewardValue(uint256 _value) external onlyOwner{
        minRewardValue = _value;
    }

}

//router:0x4ee133a21B2Bd8EC28d41108082b850B71A3845e
//token:

//marketing:0x427DfD8Ec77a9226E038Ada1A12055eDc544B440
//fundation:0xD3C2540567Fb4360B30ed9FB653800d314032581
//total:0x0d17B54dc4507D0Abf27bd49cfB248b7eE4056d0

// multiTransfer1:0x884B5FA19EE446876e539AfEe5c951B770039356
// multiTransfer2:0xc68d313893383b5b49d338575dD40b314DbFd445
// tokenAddress:0xf49e283b645790591aa51f4f6DAB9f0B069e8CdD