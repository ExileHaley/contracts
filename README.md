### document

###### Library/EIP imp link:https://github.com/Vectorized/solady
###### EVM Playground:https://www.evm.codes/playground
###### Blockchain Doc:https://www.bcskill.com/
#### solidity assembly:
###### link1:https://blog.csdn.net/qq_33842966/article/details/125947457
###### link2:https://zhuanlan.zhihu.com/p/531634672
###### link3:https://www.bcskill.com/index.php/2023/02/page/6/


### Solidity EVM
#### solidity存储：
##### 基本类型的存储，从位置0开始连续的放入存储中</br>
###### （1）存储插槽的第一项会以低位对齐（即右对齐）的方式存储；</br>
###### （2）如果存储插槽的剩余空间不足以存储一个基本类型，那么它会被移入下一个存储插槽中；</br>
###### （3） 结构体和数组数据总是会占用一整个新插槽（其中各项会以以上的方式进行打包）；</br>
##### 非固定长度类型</br>
###### （1）如果数据长度小于等于 31 字节，则它存储在高位字节（左对齐)，最低位字节存储 length * 2；</br>
###### （2）如果数据长度超出 31 字节，则在主插槽存储 length * 2 + 1，数据照常存储在 keccak256(slot) 中；</br>
###### （3）读取方式keccak256(abi.encode(1))，如果超出了32字节，那么就是keccak256(abi.encode(1)) + 1，1是插槽位置；</br>
##### 映射</br>
###### （1）所处的插槽空置，不存储内容；</br>
###### （2）mapping 中的数据，存储在插槽 keccak256(key.slot) 中，也就是keccak256(abi.encode(key, slot))；</br>
###### example:
```javascript
contract Storage {
    mapping(uint256 => uint256) public a;
    function foo() public {
        a[1] = 123;
        a[2] = 345;
    }
}
-- 通过 keccak256(abi.encode(1, 0)) 和 keccak256(abi.encode(2, 0))读取；</br>
```
##### 数组
###### （1）所处的插槽，存储数组的长度
###### （2）数组内存储的元素，存储在以 keccak256(slot) 插槽开始的位置
###### example:
```javascript
contract Storage {
    uint256[] public a;

    function foo() public {
        a.push(12);
        a.push(34);
    }
}
运行foo函数后，插槽0值就变成了2，这里注意如果运行了两次foo，那么就变成了4，因为数组的长度变成了4。我们来计算 keccak256(abi.encode(0)) 的值为：
0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563查询其插槽上的值为 12；
再看看下一个插槽【即 keccak256(abi.encode(0)) + 1 】的值为 34，满足规则；
对于组合类型，例如 mapping(uint256 => uint256[])，那么就按照组合的规则，从外到里进行计算即可。
```
#### solidity内存：</br>
##### Solidity 保留了 4 个 32 字节的插槽（slot）：</br>
###### （1）0x00 - 0x3f：用于保存方法（函数）哈希的临时空间;</br>
###### （2）0x40 - 0x5f：当前已分配的 内存memory 大小（又名，空闲 内存memory 指针）;</br>
###### （3）0x60 - 0x7f：0 值插槽;</br>
###### 注：临时空间可以在语句之间使用（即在内联汇编之中）。0 值插槽则用来对动态内存数组进行初始化，且永远不会写入数据（因而可用的初始内存指针为 0x80；
##### 空闲内存指针(偏移量位置 0x40)(*"对内存中第一个未使用字的引用 "*)；
###### （1）内联汇编外部空闲内存指针则会自动更新
###### （2）内联汇编中通过mstore或通过类似的操作码写到内存，如calldatacopy，空闲内存指针不会被自动更新，需要手动更新；
![image](https://github.com/ExileHaley/mstoreEVM/assets/115961813/82898408-bf3c-429d-861d-5841ddbf9c65)

##### 数组
###### 所有的局部变量都在堆栈上，所以要先加载到内存中然后才进行返回，因为return(x,x)从内存中进行返回。


