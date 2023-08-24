// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Simple ERC721 implementation with storage hitchhiking.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/tokens/ERC721.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/tree/master/contracts/token/ERC721/ERC721.sol)

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/                              
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
/*.:.*.:.**.:.*.:.**..*.:*ERC721_Haley.*.:.**.:.*.:.**.*.*.:.**/
/*´:°•.°+.*•´.*:˚.°*.˚•´.°:2023.07°•.°•.*:˚.°*.˚•´.°:°•.°+´.*:*/                              
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
abstract contract ERC721{
    /// @dev An account can hold up to 4294967295 tokens.
    uint256 internal constant _MAX_ACCOUNT_BALANCE = 0xffffffff;
    /// @dev Only the token owner or an approved account can manage the token.
    error NotOwnerNorApproved();
    /// @dev The token does not exist.
    error TokenDoesNotExist();
    /// @dev The token already exists.
    error TokenAlreadyExists();
    /// @dev Cannot query the balance for the zero address.
    error BalanceQueryForZeroAddress();
    /// @dev Cannot mint or transfer to the zero address.
    error TransferToZeroAddress();
    /// @dev The token must be owned by `from`.
    error TransferFromIncorrectOwner();
    /// @dev The recipient's balance has overflowed.
    error AccountBalanceOverflow();
    /// @dev Cannot safely transfer to a contract that does not implement
    /// the ERC721Receiver interface.
    error TransferToNonERC721ReceiverImplementer();

    /// @dev Emitted when token `id` is transferred from `from` to `to`.
    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    /// @dev Emitted when `owner` enables `account` to manage the `id` token.
    event Approval(address indexed owner, address indexed account, uint256 indexed id);
    /// @dev Emitted when `owner` enables or disables `operator` to manage all of their tokens.
    event ApprovalForAll(address indexed owner, address indexed operator, bool isApproved);

    /// @dev `keccak256(bytes("Transfer(address,address,uint256)"))`.
    uint256 private constant _TRANSFER_EVENT_SIGNATURE =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
    /// @dev `keccak256(bytes("Approval(address,address,uint256)"))`.
    uint256 private constant _APPROVAL_EVENT_SIGNATURE =
        0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925;
    /// @dev `keccak256(bytes("ApprovalForAll(address,address,bool)"))`.
    uint256 private constant _APPROVAL_FOR_ALL_EVENT_SIGNATURE =
        0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31;

    uint256 private constant _ERC721_MASTER_SLOT_SEED = 0x7d8825530a5a2e7a << 192;
    /// @dev Pre-shifted and pre-masked constant.
    uint256 private constant _ERC721_MASTER_SLOT_SEED_MASKED = 0x0a5a2e7a00000000;

    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    /*.:.*.:.**.:.*.:.**.ERC721_Metadata.*.:.*.:.**.:.*.:.**.:.*.:*/
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/ 

    /// @dev Returns the token collection name.
    function name() public view virtual returns (string memory);

    /// @dev Returns the token collection symbol.
    function symbol() public view virtual returns (string memory);

    /// @dev Returns the Uniform Resource Identifier (URI) for token `id`.
    function tokenURI(uint256 id) public view virtual returns (string memory);
     
    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            let s := shr(224, interfaceId)
            // ERC165: 0x01ffc9a7, ERC721: 0x80ac58cd, ERC721Metadata: 0x5b5e139f.
            result := or(or(eq(s, 0x01ffc9a7), eq(s, 0x80ac58cd)), eq(s, 0x5b5e139f))
        }
    }

    /// @dev Return token amount by `owner`
    function balanceOf(address owner) public view virtual returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly{
            if iszero(owner){
                mstore(0x00, 0x8f4eb604) // `BalanceQueryForZeroAddress()`.
                revert(0x1c, 0x04)
            }
            mstore(0x1c,_ERC721_MASTER_SLOT_SEED)
            mstore(0x00,owner)
            result := and(sload(keccak256(0x0c, 0x1c)), _MAX_ACCOUNT_BALANCE)
        }
    }
    /// @dev Return token of `owner` 
    function _ownerOf(uint256 id) internal view virtual returns (address result){
        /// @solidity memory-safe-assembly
        assembly{
            mstore(0x00,id)
            mstore(0x1c,_ERC721_MASTER_SLOT_SEED)
            result := shr(96, shl(96, sload(add(id, add(id, keccak256(0x00,0x20))))))
        }
    }

    /// @dev Returns the owner of token `id`.
    ///
    /// Requirements:
    /// - Token `id` must exist.
    function ownerOf(uint256 id) public view virtual returns (address result) {
        result = _ownerOf(id);
        /// @solidity memory-safe-assembly
        assembly{
            if iszero(result){
                mstore(0x00, 0xceea21b6) // `TokenDoesNotExist()`.
                revert(0x1c, 0x04)
            }
        } 
    }  

    /// @dev Sets `account` as the approved account to manage token `id`.
    ///
    /// Requirements:
    /// - Token `id` must exist.
    /// - The caller must be the owner of the token,
    ///   or an approved operator for the token owner.
    ///
    /// Emits an {Approval} event.
    function approve(address account, uint256 id) public virtual {
        _approve(msg.sender, account, id);
    }

    /// @dev Equivalent to `_approve(address(0), account, id)`.
    function _approve(address account, uint256 id) internal virtual {
        _approve(address(0), account, id);
    }

    /// @dev Sets `account` as the approved account to manage token `id`, using `by`.
    ///
    /// Requirements:
    /// - Token `id` must exist.
    /// - If `by` is not the zero address, `by` must be the owner
    ///   or an approved operator for the token owner.
    ///
    /// Emits a {Transfer} event.
    function _approve(address by, address account, uint256 id) internal virtual {
        /// @solidity memory-safe-assembly
        assembly{
            // 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff
            let bitmaskAddress := shr(96, not(0))
            // 0x000000000000000000000000ab8483f64d9c6d1ecf9b849ae677dd3315835cb2
            account := and(bitmaskAddress,account)
            by := and(bitmaskAddress,by)

            // load data => get owner`s solt
            mstore(0x00, id)
            mstore(0x1c, or(_ERC721_MASTER_SLOT_SEED, by))
            let ownershipSlot := add(id, add(id, keccak256(0x00, 0x20)))
            //slot取出的是本身值，与bitmaskAddress与操作完成owner地址所在的32字节周围清理干净
            let owner := and(bitmaskAddress,sload(ownershipSlot))
            // revert if token id does not exist.
            if iszero(owner){
                mstore(0x00, 0xceea21b6) // `TokenDoesNotExist()`.'
                revert(0x1c, 0x04)
            }
            // if `by` is not zero address,do the authorization check.
            // Revert if `by` is not the owner, nor approved.
            if iszero(or(iszero(by),eq(by,owner))){
                mstore(0x00, owner)
                if iszero(sload(keccak256(0x0c, 0x30))) {
                    mstore(0x00, 0x4b6e7f18) // `NotOwnerNorApproved()`.
                    revert(0x1c, 0x04)
                }
            }
            sstore(add(1,ownershipSlot),account)
            log4(0x00, 0x00, _APPROVAL_EVENT_SIGNATURE, owner, account, id)

        }
    }

    /// @dev Returns the account approved to manage token `id`.
    ///
    /// Requirements:
    /// - Token `id` must exist.
    function getApproved(uint256 id) public view virtual returns (address result) {
        /// @solidity memory-safe-assembly
        assembly{
            mstore(0x00, id)
            mstore(0x1c, _ERC721_MASTER_SLOT_SEED)
            let ownershipSlot := add(1, add(1, keccak256(0x00,0x20)))
            result := sload(add(ownershipSlot,1))
        }
    }
    /// @dev Authorize all assets
    function setApprovalForAll(address operator, bool isApproved) public virtual {
        /// @solidity memory-safe-assembly
        assembly{
            isApproved := iszero(iszero(isApproved))
            mstore(0x1c, operator)
            mstore(0x08, _ERC721_MASTER_SLOT_SEED_MASKED)
            mstore(0x00, caller())
            sstore(keccak256(0x0c,0x30),isApproved)
            //emit {ApprovalForAll}
            mstore(0x00,isApproved)
            log3(
                0x00, 0x20, _APPROVAL_FOR_ALL_EVENT_SIGNATURE, caller(), shr(96, shl(96, operator))
            )
        }
    }

    /// @dev Returns whether `operator` is approved to manage the tokens of `owner`.
    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        returns (bool result)
    {
        /// @solidity memory-safe-assembly
        assembly{
            mstore(0x1c, operator)
            mstore(0x08, _ERC721_MASTER_SLOT_SEED_MASKED)
            mstore(0x00, owner)
            result := sload(keccak256(0x0c, 0x30))
        }
    }

    /// @dev Transfers token `id` from `from` to `to`.
    function transferFrom(address from, address to, uint256 id) public virtual {
        _beforeTokenTransfer(from, to, id);
        /// @solidity memory-safe-assembly
        assembly{
            let bitmaskAddress := shr(96, not(0))
            from := and(bitmaskAddress, from)
            to := and(bitmaskAddress, to)

            //load the ownership data
            mstore(0x00, id)
            mstore(0x1c, or(_ERC721_MASTER_SLOT_SEED, caller()))
            let ownershipSlot := add(1, add(1, keccak256(0x00,0x20)))
            let ownershipPacked := sload(ownershipSlot)
            let owner := and(bitmaskAddress,ownershipPacked)

            //revert if `from` is not owner,or does not exist.
            if iszero(mul(owner, eq(from,owner))){
                if iszero(owner){
                    mstore(0x00, 0xceea21b6) // `TokenDoesNotExist()`.
                    revert(0x1c, 0x04)
                }
                mstore(0x00, 0xa1148100) // `TransferFromIncorrectOwner()`.
                revert(0x1c, 0x04)
            }
            //revert when `to` is zero address
            if iszero(to){
                mstore(0x00, 0xea553b34) // `TransferToZeroAddress()`.
                revert(0x1c, 0x04)
            }

            //load、check、and update the token approval
            {
                mstore(0x00, from)
                let approvedAddress := sload(add(1,ownershipSlot))
                // Revert if the caller is not the owner, nor approved.
                if iszero(or(eq(caller(), from), eq(caller(), approvedAddress))){
                    if iszero(sload(keccak256(0x00, 0x30))){
                        mstore(0x00, 0x4b6e7f18) // `NotOwnerNorApproved()`.
                        revert(0x1c, 0x04)
                    }
                }
                //delete the approved address if any
                if approvedAddress { sstore(add(1, ownershipSlot), 0) }
            }
            //The above part completes all data verification
            //update new owner
            sstore(ownershipSlot, xor(ownershipPacked, xor(from, to)))
            //decrement the balace of `from`
            {
                let fromBalanceSolt := keccak256(0x0c, 0x1c)
                sstore(fromBalanceSolt,sub(sload(fromBalanceSolt),1))
            }
            //increment the balance of `to`
            {
                mstore(0x00, to)
                let toBalanceSlot := keccak256(0x0c, 0x1c)
                let toBalancePacked := add(sload(toBalanceSlot),1)
                if iszero(and(toBalancePacked, _MAX_ACCOUNT_BALANCE)){
                    mstore(0x00, 0x01336cea) // `AccountBalanceOverflow()`.
                    revert(0x1c, 0x04)
                }
                sstore(toBalanceSlot, toBalancePacked)
            }
            log4(0x00, 0x00, _TRANSFER_EVENT_SIGNATURE, from, to, id)
        }
        _afterTokenTransfer(from, to, id);
    }

    /// @dev Equivalent to `safeTransferFrom(from, to, id, "")`.
    function safeTransferFrom(address from, address to, uint256 id) public payable virtual {
        transferFrom(from, to, id);
        if (_hasCode(to)) _checkOnERC721Received(from, to, id, "");
    }

    /// @dev Equivalent to `safeTransferFrom(from, to, id, "")`.
    function safeTransferFrom(address from, address to, uint256 id, bytes calldata data)
        public
        payable
        virtual
    {
        transferFrom(from, to, id);
        if (_hasCode(to)) _checkOnERC721Received(from, to, id, data);
    }

    /// @dev Returns if token `id` exists.
    function _exists(uint256 id) internal view virtual returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly{
            mstore(0x00, id)
            mstore(0x1c, _ERC721_MASTER_SLOT_SEED)
            result := shl(96, sload(add(id, add(id, keccak256(0x00,0x20)))))
        }
    }

     /// @dev Returns whether `account` is the owner of token `id`, or is approved to manage it.
    ///
    /// Requirements:
    /// - Token `id` must exist.
    function _isApprovedOrOwner(address account, uint256 id)
        internal
        view
        virtual
        returns (bool result)
    {
        /// @solidity memory-safe-assembly
        assembly{
            result := 1
            //clear upper 96 bits
            account := shr(96, shl(96, account))
            //load the ownership data
            mstore(0x00, id)
            mstore(0x1c, or(_ERC721_MASTER_SLOT_SEED,account))
            let ownershipSlot := add(1, add(1, keccak256(0x00,0x20)))
            let owner := shr(96, shl(96, sload(ownershipSlot)))   
            //revert when token isn`t mint
            if iszero(owner) {
                mstore(0x00, 0xceea21b6) // `TokenDoesNotExist()`.
                revert(0x1c, 0x04)
            }        
            //check if `account` is the `owner`
            if iszero(eq(account, owner)){
                mstore(0x00, owner)
                //check is `account` is approved
                if iszero(sload(keccak256(0x0c,0x30))){
                    result := eq(account, sload(add(1, ownershipSlot)))
                }
            }
        }
    }

    /// @dev Mints token `id` to `to`.
    ///
    /// Requirements:
    ///
    /// - Token `id` must not exist.
    /// - `to` cannot be the zero address.
    ///
    /// Emits a {Transfer} event.
    function _mint(address to, uint256 id) internal virtual {
        _beforeTokenTransfer(address(0), to, id);
        /// @solidity memory-safe-assembly
        assembly{
            to := shr(96, shl(96, to))
            if iszero(to){
                mstore(0x00, 0xea553b34) // `TransferToZeroAddress()`.
                revert(0x1c, 0x04)
            }

            // load mint data
            mstore(0x00, id)
            mstore(0x1c, _ERC721_MASTER_SLOT_SEED)
            let ownershipSlot := add(id, add(id, keccak256(0x00, 0x20)))
            let ownershipPacked := sload(ownershipSlot)
            //revert when token id already exist.
            if shl(96, ownershipPacked){
                mstore(0x00, 0xc991cbb1) // `TokenAlreadyExists()`.
                revert(0x1c, 0x04)
            }
            sstore(ownershipSlot, or(ownershipPacked,to))

            {
                mstore(0x00, to)
                let balanceSlot := keccak256(0x0c, 0x1c)
                let balanceSlotPacked := add(sload(balanceSlot), 1)
                if iszero(and(balanceSlotPacked, _MAX_ACCOUNT_BALANCE)){
                    mstore(0x00, 0x01336cea) // `AccountBalanceOverflow()`.
                    revert(0x1c, 0x04)
                }    
                sstore(balanceSlot, balanceSlotPacked)
            }

            log4(0x00, 0x00, _TRANSFER_EVENT_SIGNATURE, 0, to, id)
        }
        _afterTokenTransfer(address(0), to, id);
    }   

    /// @dev Destroys token `id`, using `by`.
    ///
    /// Requirements:
    ///
    /// - Token `id` must exist.
    /// - If `by` is not the zero address,
    ///   it must be the owner of the token, or be approved to manage the token.
    ///
    /// Emits a {Transfer} event.
    function _burn(address by, uint256 id) internal virtual {
        address owner = ownerOf(id);
        _beforeTokenTransfer(owner, address(0), id);
        /// @solidity memory-safe-assembly
        assembly{
            //clear the upper 96 bits
            by := shr(96, shl(96, by))
            //load ownership data
            mstore(0x00, id)
            mstore(0x1c, or(_ERC721_MASTER_SLOT_SEED, by))
            let ownershipSlot := add(id, add(id, keccak256(0x00, 0x20)))
            let ownershipPacked := sload(ownershipSlot)
            owner := shr(96, shl(96, ownershipPacked))
            //revert when token is does`t exist
            if iszero(owner){
                mstore(0x00, 0xceea21b6) // `TokenDoesNotExist()`.
                revert(0x1c, 0x04)
            }
            //load and check token approval
            {
                mstore(0x00, owner)
                let approvedAddress := sload(add(1, ownershipSlot))
                //not the owner, nor approved
                if iszero(or(iszero(by), or(eq(by, owner), eq(by, approvedAddress)))){
                    if iszero(sload(keccak256(0x0c, 0x30))) {
                        mstore(0x00, 0x4b6e7f18) // `NotOwnerNorApproved()`.
                        revert(0x1c, 0x04)
                    }
                }

                if approvedAddress { sstore(add(1, ownershipSlot), 0) }
            }

            //clear owner
            sstore(ownershipSlot, xor(ownershipPacked, owner))

            //decrement the balance of `owner`
            {
                let balanceSlot := keccak256(0x0c, 0x1c)
                sstore(balanceSlot, sub(sload(balanceSlot), 1))
            }
            //emit event
            log4(0x00, 0x00, _TRANSFER_EVENT_SIGNATURE, owner, 0, id)
        }
        _afterTokenTransfer(owner, address(0), id);
    }

    /// @dev Transfers token `id` from `from` to `to`.
    ///
    /// Requirements:
    ///
    /// - Token `id` must exist.
    /// - `from` must be the owner of the token.
    /// - `to` cannot be the zero address.
    /// - If `by` is not the zero address,
    ///   it must be the owner of the token, or be approved to manage the token.
    ///
    /// Emits a {Transfer} event.
    function _transfer(address by, address from, address to, uint256 id) internal virtual {
        _beforeTokenTransfer(from, to, id);
        /// @solidity memory-safe-assembly
        assembly{
            //clear the upper 96 bits
            let bitmaskAddress := shr(96, not(0))
            from := and(bitmaskAddress, from)
            to := and(bitmaskAddress, to)
            by := and(bitmaskAddress, by)
            //load ownership data
            mstore(0x00, id)
            mstore(0x1c, or(_ERC721_MASTER_SLOT_SEED, by))
            let ownershipSlot := add(id, add(id, keccak256(0x00, 0x20)))
            let ownershipPacked := sload(ownershipSlot)
            let owner := and(bitmaskAddress, ownershipPacked)
            //revert if `from` is not owner, or does`t exist
            if iszero(mul(owner, eq(from, owner))){
                if iszero(owner){
                    mstore(0x00, 0xceea21b6) // `TokenDoesNotExist()`.
                    revert(0x1c, 0x04)
                }
                mstore(0x00, 0xa1148100) // `TransferFromIncorrectOwner()`.
                revert(0x1c, 0x04)
            }
            // Revert if `to` is the zero address.
            if iszero(to) {
                mstore(0x00, 0xea553b34) // `TransferToZeroAddress()`.
                revert(0x1c, 0x04)
            }
            //load, check and update approval
            {
                mstore(0x00, from)
                let approvedAddress := sload(add(1, ownershipSlot))
                //not owner, nor approved
                if iszero(or(iszero(by), or(eq(by, from), eq(by, approvedAddress)))){
                    if iszero(sload(keccak256(0x0c, 0x30))){
                        mstore(0x00, 0x4b6e7f18) // `NotOwnerNorApproved()`.
                        revert(0x1c, 0x04)
                    }
                }

                if approvedAddress { sstore(add(1, ownershipSlot), 0) }
            }
            //update the new owner
            //contine.....
            sstore(ownershipSlot, xor(ownershipPacked, xor(from, to)))
            //decrement the balance of `from`
            {
                let fromBalanceSlot := keccak256(0x0c, 0x1c)
                sstore(fromBalanceSlot, sub(sload(fromBalanceSlot), 1))
            }
            //increment the balance of `to`
            {
                mstore(0x00, to)
                let toBalanceSlot := keccak256(0x0c, 0x1c)
                let toBalancePacked := add(sload(toBalanceSlot), 1)
                if iszero(and(toBalancePacked, _MAX_ACCOUNT_BALANCE)){
                   mstore(0x00, 0x01336cea) // `AccountBalanceOverflow()`.
                    revert(0x1c, 0x04)
                }
                sstore(toBalanceSlot, toBalancePacked)
            }
            //emit {Transfer}
            log4(
                0x00, 0x00, _TRANSFER_EVENT_SIGNATURE, from, to, id
            )

        }
        _afterTokenTransfer(from, to, id);
    }



    /// @dev Returns if `a` has bytecode of non-zero length.
    function _hasCode(address a) private view returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := extcodesize(a) // Can handle dirty upper bits.
        }
    }

    /// @dev Perform a call to invoke {IERC721Receiver-onERC721Received} on `to`.
    /// Reverts if the target does not support the function correctly.
    function _checkOnERC721Received(address from, address to, uint256 id, bytes memory data)
        private
    {
        /// @solidity memory-safe-assembly
        assembly {
            // interfaceId
            let m := mload(0x40)
            let onERC721ReceivedSelector := 0x150b7a02
            //load data
            mstore(m, onERC721ReceivedSelector)
            mstore(add(m, 0x20), caller()) // The `operator`, which is always `msg.sender`.
            mstore(add(m, 0x40), shr(96, shl(96, from)))
            mstore(add(m, 0x60), id)
            mstore(add(m, 0x80), 0x80)
            let n := mload(data)
            mstore(add(m, 0xa0), n)
            if n { pop(staticcall(gas(), 4, add(data, 0x20), n, add(m, 0xc0), n)) }
            // Revert if the call reverts.
            if iszero(call(gas(), to, 0, add(m, 0x1c), add(n, 0xa4), m, 0x20)) {
                if returndatasize() {
                    // Bubble up the revert if the call reverts.
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }
                mstore(m, 0)
            }
            // Load the returndata and compare it.
            if iszero(eq(mload(m), shl(224, onERC721ReceivedSelector))) {
                mstore(0x00, 0xd1a57ed6) // `TransferToNonERC721ReceiverImplementer()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Hook that is called before token transfers.
    function _beforeTokenTransfer(address from, address to, uint256 id) internal virtual {}

    /// @dev Hook that is called after token transfers,
    function _afterTokenTransfer(address from, address to, uint256 id) internal virtual {}
} 