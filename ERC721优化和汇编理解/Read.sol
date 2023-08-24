// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

contract Read{
    //openzeppelin中称空闲内存指针为“对内存中第一个未使用字的引用”
    function getMemInfo()public pure returns (uint256 freeMemBefore,uint256 freeMemAfter,uint256 memorySize){
        // 第一次加载空闲内存，那返回的是128，因为0x40指向了0x80，所以空闲指针之前是128个字节，4个插槽
        assembly {
            freeMemBefore := mload(0x40)
        }
        //创建一个64字节的数据，虽未被使用，但memory标识已经分配了内存指针
        bytes memory data = hex"cafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafe";
        assembly {
            //重新获取空闲指针之前的内存大小，128 + 64 = 192，汇编外部会自动偏移空闲指针
            freeMemAfter := mload(0x40)
            //freeMemAfter值被加载到内存中去
            let whatIsInThere := mload(freeMemAfter)
            //数据长度是224，128 + 64 + 32 = 224
            memorySize := msize()
        }
    }
    //当进行bytes memory myVariable这样的代码片段时，空闲内存指针被自动获取+更新
    //步骤 1：获取空闲内存指针,EVM首先从内存位置0x40加载空闲内存指针,由mload返回的值是0x80,空闲内存指针告诉我们，在内存中第一个有空闲空间可以写入的地方是偏移量0x80
    //步骤 2：分配内存+用新的空闲内存指针更新,EVM现在将在内存中为 "string test"保留这个位置。它把释放内存指针返回的值保留在堆栈中。在分配和写入内存的任何值之前，它总是更新空闲内存指针。这是为了指向内存中的下一个空闲空间。
    //根据 ABI 规范，一个 "string"由两部分组成：长度+字符串本身。那么下一步就是更新空闲内存指针。EVM 在这里说的是"我将在内存中写入 2 x 32 字节的字。所以新的空闲内存指针将比现在的指针多出 64 字节
    // 在汇编中的内存指针
    // 在内联汇编中，必须小心处理空闲内存指针!

    // 它不仅要被手动获取，而且还要被手动更新!
    function getStringInfo() public {
        string memory data = "about solidity";
    }
    // 当一个memory引用作为参数被传递给一个函数时，该函数的 EVM 字节码依次执行 4 个主要步骤:
    // 1.从calldata中加载字符串偏移到堆栈：用于字符串在calldata中的起始位置。
    // 2.将字符串的长度加载到堆栈中：将用于知道从calldata中复制多少数据。
    // 3.分配一些内存空间，将字符串从calldata中移到memory中：这与 空闲内存指针中描述的相同。
    // 4.使用操作码 calldatacopy将字符串从的calldata转移到的memory。
    function paramMemory(string memory input) public{}

    //函数体内的内存引用
    //data并不持有一个数组，而是持有内存中一个位置的指针
    function testReturns() public {uint256[] memory data;}

    function testPtr() public pure returns (bytes memory) {
        bytes memory data;
        bytes memory greetings = hex"cafecafe";
        //这个位置并未进行赋值
        //而是命令data指向内存中变量greetings所指向的同一位置
        data = greetings;
        data[0] = 0x00;
        data[1] = 0x00;
        return greetings; //0x0000cafe
    }

    function test() public {
        //内存中分配一些空间，但不立即写入内存，同样使用new关键字。
        //当用new关键字创建数组时，必须在括号中指定数组的长度。在函数体内部的内存中只允许固定大小的数组。
        uint[] memory data = new uint[](3);
    }
    //新的内存被分配，变量data将指向内存中的一个新位置。
    //十六进制数值0xC0C0A0C0DE被从内存中加载，并复制到data所指向的内存位置。
    contract Playground {
        bytes storageData = hex"C0C0A0C0DE";
        function test() public {
            bytes memory data = storageData;
        }
    }

}

contract ERCOperate{
    
    address collector = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;

    function erc20BalanceOf(address token) public view returns (uint256 amount){
        assembly{
            mstore(0x80,hex"70a08231")
            mstore(add(0x80,0x04),address())
            let success := staticcall(gas(),token,0x80,0x24,0xc0,0x20)
            if eq(success,1){
                amount := mload(0xc0)
            }
        }
    }

    function erc20Balance(address token) public view returns (uint amount){
        assembly{
            let ptr := mload(0x40)
            mstore(ptr,hex"70a08231")
            let addPtr := add(ptr,0x04)
            mstore(addPtr,address())
            let success := staticcall(gas(), token, ptr, 0x24, add(addPtr,0x20), 0x20)
            if eq(success,1){
                amount := mload(add(addPtr,0x20))
            }
            //这里处理让指针指向下一个可用位置
            // mstore(0x20, add(ptr, 0x44))
        }
    }

    function erc20Transfer(address token) external returns(bool state){
        uint amount = erc20BalanceOf(token);
        assembly{
            mstore(0x80,hex"a9059cbb")
            mstore(add(0x80,0x04),sload(collector.slot))
            mstore(add(add(0x80,0x04),0x20),amount)
            let success := call(gas(), token, 0, 0x80, 0x44, 0, 0x20)
            if eq(success,1){
                state := mload(0x0)
            }
        }
    } 

    function erc20Transfer1(address token) external  returns (bool state){
        uint256 amount = getBalance(token);
        assembly{
            let signPtr := mload(0x40)
            mstore(signPtr,hex"a9059cbb")
            let addrPtr := add(signPtr,0x04)
            mstore(addrPtr,sload(collector.slot))
            let amountPtr := add(addrPtr,0x20)
            mstore(amountPtr,amount)
            let success := call(gas(), token, 0, signPtr, 0x44, 0, 0x20)
            if eq(success,1){
                state := mload(0x0)
            }
        }
    }

    function erc721transfer(address token,uint256 tokenId) external {
        assembly{
            mstore(0x80,hex"42842e0e")
            mstore(add(0x80,0x04),address())
            mstore(add(add(0x80,0x04),0x20),sload(collector.slot))
            mstore(add(0x84,0x40),tokenId)
            let result := call(gas(), token, 0, 0x80, 0x64, 0, 0x20)
            if iszero(result){
                revert(0x0,0x20)
            }
        }
    }
} 