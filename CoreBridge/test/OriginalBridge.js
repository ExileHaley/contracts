const { expect } = require("chai")
const { ethers } = require("hardhat")
const { utils, constants, BigNumber } = require("ethers")

describe("OriginalBridge",()=>{
    const originalChainId = 0
    const wrappedChainId = 1
    const amount = utils.parseEther("10")
    const pkUnlock = 1
    const sharedDecimals = 6
    const wethSharedDecimals = 18

    let owner, user
    let originalToken, weth
    let originalBridge
    let originalEndpoint, originalBridgeFactory
    let callParams, adapterParams

    const createPayload = (pk = pkUnlock, token = originalToken.address, withdrawalAmount = amount, totalAmount = amount, unwrapWeth = false) =>
    utils.defaultAbiCoder.encode(["uint8", "address", "address", "uint256", "uint256", "bool"], [pk, token, user.address, withdrawalAmount, totalAmount, unwrapWeth])


    beforeEach(async () => {
        [owner,user] =await ethers.getSigners()
        const wethFactory = await ethers.getContractFactory("WETH9")
        weth = await wethFactory.deploy()

        const endpointFactory = await ethers.getContractFactory("LayerZeroEndpointStub")
        //部署两个endpoint
        originalEndpoint = await endpointFactory.deploy()
        const wrappedEndpoint = await endpointFactory.deploy()

        originalBridgeFactory = await ethers.getContractFactory("OriginalTokenBridgeHarness")
        originalBridge = await originalBridgeFactory.deploy(originalEndpoint.address,wrappedChainId,weth.address)

        const wrppedBridgeFactory = await ethers.getContractFactory("WrappedBridge")
        const wrappedBridge = await wrppedBridgeFactory.deploy(wrappedEndpoint.address)

        const originalERC20Factory = await ethers.getContractFactory("MintableERC20Mock")
        originalToken = await originalERC20Factory.deploy("TEST","TEST")

        await originalBridge.setTrustedRemoteAddress(wrappedChainId, wrappedBridge.address)
        await originalToken.mint(user.address, amount)

        callParams = { refundAddress: user.address, zroPaymentAddress: constants.AddressZero }
        adapterParams = "0x"
    })

    it("WETH is zero address in constructor", async () => {
        await expect(originalBridgeFactory.deploy(originalEndpoint.address, wrappedChainId, constants.AddressZero)).to.be.revertedWith("OriginalBridge:Invalid weth address")
    })

    it("doesn't renounce ownership", async () => {
        await originalBridge.renounceOwnership()
        expect(await originalBridge.owner()).to.be.eq(owner.address)
    })

    describe("registerToken", () => {
        it("reverts when passing address zero", async () => {
            await expect(originalBridge.registerToken(constants.AddressZero, sharedDecimals))
            .to.be.revertedWith("OriginalBridge:Invalid address")
        })

        it("reverts if token already registered", async () => {
            await originalBridge.registerToken(originalToken.address, sharedDecimals)
            await expect(originalBridge.registerToken(originalToken.address, sharedDecimals))
            .to.be.revertedWith("OriginalBridge:Invalid address")
        })

        it("reverts when called by non owner", async () => {
            await expect(originalBridge.connect(user).registerToken(originalToken.address, sharedDecimals))
            .to.be.revertedWith("Ownable: caller is not the owner")
        })

        it("reverts when shared decimals is greater than local decimals", async () => {
            const invalidSharedDecimals = 19
            await expect(originalBridge.registerToken(originalToken.address, invalidSharedDecimals))
            .to.be.revertedWith("OriginalBridge:Shared decimals must be less than or equal to local decimals")
        })

        it("registers token and saves local to shared decimals conversion rate", async () => {
            await originalBridge.registerToken(originalToken.address, sharedDecimals)
            expect(await originalBridge.supportedTokens(originalToken.address)).to.be.true
            expect((await originalBridge.conversionRate(originalToken.address)).toNumber()).to.be.eq(10 ** 12)
        })
    })

    describe("setRemoteChainId", () => {
        const newRemoteChainId = 2
        it("reverts when called by non owner", async () => {
            await expect(originalBridge.connect(user).setRemoteChainId(newRemoteChainId))
            .to.be.revertedWith("Ownable: caller is not the owner")
        })

        it("sets remote chain id", async () => {
            await originalBridge.setRemoteChainId(newRemoteChainId)
            expect(await originalBridge.remoteChainId()).to.be.eq(newRemoteChainId)
        })
    })

    describe("setUseCustomAdapterParams", () => {
        it("reverts when called by non owner", async () => {
            await expect(originalBridge.connect(user).setUseCustomAdapterParams(true))
            .to.be.revertedWith("Ownable: caller is not the owner")
        })

        it("sets useCustomAdapterParams to true", async () => {
            await originalBridge.setUseCustomAdapterParams(true)
            expect(await originalBridge.useCustomAdapterParams()).to.be.true
        })
    })

    describe("Bridge",async()=>{
        let fee
        beforeEach(async () => {
            fee = (await originalBridge.estimateGasFee(false, adapterParams)).nativeFee
            await originalToken.connect(user).approve(originalBridge.address, amount)
        })

        it("wrapped receiver is zero address", async () => {
            await originalBridge.registerToken(originalToken.address,sharedDecimals)
            await expect(originalBridge.connect(user).bridge(originalToken.address,constants.AddressZero,amount,callParams,adapterParams),{value: fee })
            .to.be.revertedWith("OriginalBridge:Invalid address")
        })

        it("original token not register",async ()=>{
            await expect(originalBridge.connect(user).bridge(originalToken.address,user.address,amount,callParams,adapterParams),{value: fee })
            .to.be.revertedWith("OriginalBridge:Invalid address")
        })

        it("useCustomAdapterParams is false and non-empty adapterParams",async ()=> {
            const adapterParamsV1 = ethers.utils.solidityPack(["uint16", "uint256"], [1, 200000])
            await originalBridge.registerToken(originalToken.address,sharedDecimals)
            await expect(originalBridge.connect(user).bridge(originalToken.address,user.address,amount,callParams,adapterParamsV1),{value: fee })
            .to.be.revertedWith("BridgeBase:adapterParams must be empty")
        })

        it("cross amount is 0",async ()=>{
            await originalBridge.registerToken(originalToken.address,sharedDecimals)
            await expect(originalBridge.connect(user).bridge(originalToken.address,user.address,0,callParams,adapterParams),{value: fee })
            .to.be.revertedWith("OriginalBridge:Invalid amount")
        })

        it("msg.sender token is not enough",async ()=> {
            await originalBridge.registerToken(originalToken.address,sharedDecimals)
            const newAmount = amount.add(utils.parseEther("0.1"))
            await originalToken.connect(user).approve(originalBridge.address, newAmount)
            await expect(originalBridge.connect(user).bridge(originalToken.address,user.address,newAmount,callParams,adapterParams,{value: fee }))
            .to.be.revertedWith("TransferHelper: TRANSFER_FROM_FAILED")
        })

        //compare ld=>sd result
        it("local token in contract",async ()=> {
            await originalBridge.registerToken(originalToken.address,sharedDecimals)
            await originalBridge.connect(user).bridge(originalToken.address, user.address, amount, callParams, adapterParams,{ value:fee })
            const ldtosd = await originalBridge.conversionRate(originalToken.address)
            // const locked = await originalBridge.totalValueLocked(originalToken.address)
            
            // // const value = BigNumber.from(ldtosd)
            // // console.log(value)

            // console.log(ldtosd)
            // console.log(amount)
            // console.log(locked)

            expect(await originalBridge.totalValueLocked(originalToken.address)).to.be.eq(amount.div(ldtosd))
            expect(await originalToken.balanceOf(originalBridge.address)).to.be.eq(amount)
            expect(await originalToken.balanceOf(user.address)).to.be.eq(0)
        })

        it("local token in contract and send dust to sender",async ()=>{
            const dust = BigNumber.from("12345")
            const amountWithDust = amount.add(dust)
            await originalBridge.registerToken(originalToken.address, sharedDecimals)
            await originalToken.mint(user.address, dust)
            await originalToken.connect(user).approve(originalBridge.address, amountWithDust)
            await originalBridge.connect(user).bridge(originalToken.address, user.address,amountWithDust,  callParams, adapterParams, { value: fee })

            const LDtoSD = await originalBridge.conversionRate(originalToken.address)
            expect(await originalBridge.totalValueLocked(originalToken.address)).to.be.eq(amount.div(LDtoSD))
            expect(await originalToken.balanceOf(originalBridge.address)).to.be.eq(amount)
            expect(await originalToken.balanceOf(user.address)).to.be.eq(dust)
        })
    //bridge
    })

    describe("Bridge",async()=>{
        let totalAmount
        beforeEach(async () => {
            const fee = (await originalBridge.estimateGasFee(false, adapterParams)).nativeFee
            totalAmount = amount.add(fee)
        })
        
        it("reverts when to is address zero", async () => {
            await originalBridge.registerToken(weth.address, wethSharedDecimals)
            await expect(originalBridge.connect(user).bridgeETH(constants.AddressZero,amount , callParams, adapterParams, { value: totalAmount }))
            .to.be.revertedWith("OriginalBridge:Invalid address")
        })

        it("reverts when WETH is not registered", async () => {
            await expect(originalBridge.connect(user).bridgeETH(user.address,amount,  callParams, adapterParams, { value: totalAmount }))
            .to.be.revertedWith("OriginalBridge:Invalid address")
        })

        it("reverts when useCustomAdapterParams is false and non-empty adapterParams are passed", async () => {
            const adapterParamsV1 = ethers.utils.solidityPack(["uint16", "uint256"], [1, 200000])
            await originalBridge.registerToken(weth.address, wethSharedDecimals)
            await expect(originalBridge.connect(user).bridgeETH(user.address,amount,  callParams, adapterParamsV1, { value: totalAmount }))
            .to.be.revertedWith("BridgeBase:adapterParams must be empty")
        })

        it("reverts when useCustomAdapterParams is true and min gas limit isn't set", async () => {
            const adapterParamsV1 = ethers.utils.solidityPack(["uint16", "uint256"], [1, 200000])
            await originalBridge.registerToken(weth.address, wethSharedDecimals)
            await originalBridge.setUseCustomAdapterParams(true)
            await expect(originalBridge.connect(user).bridgeETH( user.address,amount, callParams, adapterParamsV1, { value: totalAmount }))
            .to.be.revertedWith("LzApp: minGasLimit not set")
        })

        it("reverts when amount is 0", async () => {
            await originalBridge.registerToken(weth.address, wethSharedDecimals)
            await expect(originalBridge.connect(user).bridgeETH(user.address, 0, callParams, adapterParams, { value: totalAmount }))
            .to.be.revertedWith("OriginalBridge:Invalid amount")
        })

        it("reverts when value is less than amount", async () => {
            await originalBridge.registerToken(weth.address, wethSharedDecimals)
            await expect(originalBridge.connect(user).bridgeETH(user.address, amount, callParams, adapterParams, { value: 0 }))
            .to.be.revertedWith("OriginalBridge:Not enough value")
            //OriginalBridge:Not enough value
            // /TransferHelper: ETH_TRANSFER_FAILED
        })

        it("locks WETH in the contract", async () => {
            await originalBridge.registerToken(weth.address, wethSharedDecimals)
            await originalBridge.connect(user).bridgeETH(user.address, amount, callParams, adapterParams, { value: totalAmount })

            expect(await originalBridge.totalValueLocked(weth.address)).to.be.eq(amount)
            expect(await weth.balanceOf(originalBridge.address)).to.be.eq(amount)
        })
    //bridgeETH
    })

    describe("_nonblockingLzReceive", () => {
        beforeEach(async () => {
            await originalBridge.registerToken(originalToken.address, sharedDecimals)
        })

        it("reverts when received from an unknown chain", async () => {
            await expect(originalBridge.simulateNonblockingLzReceive(originalChainId, "0x"))
            .to.be.revertedWith("OriginalBridge:ChainId mismatch")
        })

        it("reverts when payload has incorrect packet type", async () => {
            const pkUnknown = 0
            await expect(originalBridge.simulateNonblockingLzReceive(wrappedChainId, createPayload(pkUnknown)))
            .to.be.revertedWith("OriginalBridge:Pk type mis mismatch")
        })

        it("reverts when a token is not supported", async () => {
            const ERC20Factory = await ethers.getContractFactory("MintableERC20Mock")
            const newToken = await ERC20Factory.deploy("NEW", "NEW")
            await expect(originalBridge.simulateNonblockingLzReceive(wrappedChainId, createPayload(pkUnlock, newToken.address)))
            .to.be.revertedWith("OriginalBridge:Not supported")
        })

        it("unlocks, collects withdrawal fees and transfers funds to the recipient", async () => {
            const LDtoSD = await originalBridge.conversionRate(originalToken.address)
            const bridgingFee = (await originalBridge.estimateGasFee(false, adapterParams)).nativeFee
            const withdrawalFee = amount.div(100)
            const withdrawalAmount = amount.sub(withdrawalFee)
            const withdrawalAmountSD = withdrawalAmount.div(LDtoSD)
            const totalAmountSD = amount.div(LDtoSD)

            // Setup
            await originalToken.connect(user).approve(originalBridge.address, amount)

            // Bridge
            await originalBridge.connect(user).bridge(originalToken.address, user.address,  amount, callParams, adapterParams, { value: bridgingFee })

            expect(await originalToken.balanceOf(user.address)).to.be.eq(0)
            expect(await originalToken.balanceOf(originalBridge.address)).to.be.eq(amount)

            // Receive
            await originalBridge.simulateNonblockingLzReceive(wrappedChainId, createPayload(pkUnlock, originalToken.address, withdrawalAmountSD, totalAmountSD))

            expect(await originalBridge.totalValueLocked(originalToken.address)).to.be.eq(0)
            expect(await originalToken.balanceOf(originalBridge.address)).to.be.eq(withdrawalFee)
            expect(await originalToken.balanceOf(user.address)).to.be.eq(withdrawalAmount)
        })

        it("unlocks WETH and transfers ETH to the recipient", async () => {
            const bridgingFee = (await originalBridge.estimateGasFee(false, adapterParams)).nativeFee
            totalAmount = amount.add(bridgingFee)

            // Setup
            await originalBridge.registerToken(weth.address, wethSharedDecimals)

            // Bridge
            await originalBridge.connect(user).bridgeETH(user.address,amount,  callParams, adapterParams, { value: totalAmount })
            const recipientBalanceBefore = await ethers.provider.getBalance(user.address)

            // Receive
            await originalBridge.simulateNonblockingLzReceive(wrappedChainId, createPayload(pkUnlock, weth.address, amount, amount, true))

            expect(await originalBridge.totalValueLocked(weth.address)).to.be.eq(0)
            expect(await weth.balanceOf(originalBridge.address)).to.be.eq(0)
            expect(await weth.balanceOf(user.address)).to.be.eq(0)
            expect(await ethers.provider.getBalance(user.address)).to.be.eq(recipientBalanceBefore.add(amount))
        })

    //_nonblockingLzReceive
    })

    describe("withdrawFee", () => {
        beforeEach(async () => {
            await originalBridge.registerToken(originalToken.address, sharedDecimals)
        })

        it("reverts when called by non owner", async () => {
            await expect(originalBridge.connect(user).withdrawFee(originalToken.address, owner.address, 1))
            .to.be.revertedWith("Ownable: caller is not the owner")
        })

        it("reverts when not enough fees collected", async () => {
            await expect(originalBridge.withdrawFee(originalToken.address, owner.address, 1))
            .to.be.revertedWith("OriginalBridge:Invalid withdraw amount")
        })

        it("withdraws fees", async () => {
            const LDtoSD = await originalBridge.conversionRate(originalToken.address)
            const bridgingFee = (await originalBridge.estimateGasFee(false, adapterParams)).nativeFee
            const withdrawalFee = amount.div(100)
            const withdrawalAmountSD = amount.sub(withdrawalFee).div(LDtoSD)
            const totalAmountSD = amount.div(LDtoSD)

            await originalToken.connect(user).approve(originalBridge.address, amount)
            await originalBridge.connect(user).bridge(originalToken.address, user.address,amount,  callParams, adapterParams, { value: bridgingFee })
            await originalBridge.simulateNonblockingLzReceive(wrappedChainId, createPayload(pkUnlock, originalToken.address, withdrawalAmountSD, totalAmountSD))

            await originalBridge.withdrawFee(originalToken.address, owner.address, withdrawalFee)
            expect(await originalToken.balanceOf(owner.address)).to.be.eq(withdrawalFee)
        })
    })


//OriginalBridge test end!   
})