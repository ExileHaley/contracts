


#### mapping(uint256 => address) private _owners;
计算方式：
    mstore(0x00,id) 0x00开始存储token id
    mstore(0x1c,SEED) 0x1c开始存储常量种子
    主键计算方式如下：
         0x00-0x20会存储seed的开头部分，然后对这部分数据进行hash，然后再把id加上2次
        （1）keccak256(0x00,0x20)计算hash值，为防止主键碰撞做两次id加法操作
        （2）add(id,add(id,keccak256(0x00,0x20)))两次加法操作，改值作为主键标识存储槽
        （3）存储方式:插槽原值与to地址取或


#### mapping(address => uint256) private _balances;
计算方式：
    mstore(0x1c,SEED) 从0x1c开始存储种子常量
    mstore(0x00,addr) 32个字节开始存储20字节长度的地址，遵循低位对齐，所以有效数据从0x0c开始
    主键计算方式：
        主键/插槽 = keccak(0x0c,0x1c) keccak从0x0c开始到0x0c+0x1c
    存储方式：取插槽原值 + 1，判断是否超出最大值




#### mapping(uint256 => address) private _tokenApprovals;
计算方式：
    先计算_owners的主键/插槽，插槽加1的位置作为主键/插槽，存储_tokenApprovals的值


#### mapping(address => mapping(address => bool)) private _operatorApprovals;
计算方式：
    mstore(0x1c,operator) 将被授权地址加载到0x1c开始的内存位置，会作为计算种子
    mstore(0x08,SEED_MASKED) 将常量加载到0x08开始的位置
    mstore(0x00,caller()) 将调用者地址加载到0x00开始的内存,从0x0c是地址真正开始的位置
    主键/存储槽计算如下：
        keccak256(0x0c,0x30) keccak从0x0c开始到0x0c+0x30结束，共计48个字节
