const { expect } = require("chai")
const { ethers } = require("hardhat")
const { utils, constants } = require("ethers")

describe("WrappedBridge", () => {

    const originalChainId = 0
    const wrappedChainId = 1
    const amount = utils.parseEther("10")
    const pkMint = 0

    let owner, user
    let originalToken, wrappedToken
    let wrappedBridge
    let wrappedEndpoint, wrappedBridgeFactory
    let callParams, adapterParams

    const createPayload = (pk = pkMint, token = originalToken.address) => utils.defaultAbiCoder.encode(["uint8", "address", "address", "uint256"], [pk, token, user.address, amount])
    beforeEach(async () => {
        [owner, user] = await ethers.getSigners()

        const endpointFactory = await ethers.getContractFactory("LayerZeroEndpointStub")
        const originalEndpoint = await endpointFactory.deploy()
        wrappedEndpoint = await endpointFactory.deploy()

        const wethFactory = await ethers.getContractFactory("WETH9")
        const weth = await wethFactory.deploy()

        const originalBridgeFactory = await ethers.getContractFactory("OriginalBridge")
        const originalBridge = await originalBridgeFactory.deploy(originalEndpoint.address, wrappedChainId, weth.address)

        wrappedBridgeFactory = await ethers.getContractFactory("WrappedTokenBridgeHarness")
        wrappedBridge = await wrappedBridgeFactory.deploy(wrappedEndpoint.address)

        const ERC20Factory = await ethers.getContractFactory("MintableERC20Mock")
        originalToken = await ERC20Factory.deploy("TEST", "TEST")
        const originalERC20Decimals = await originalToken.decimals()

        const wrappedERC20Factory = await ethers.getContractFactory("WrappedERC20")
        wrappedToken = await wrappedERC20Factory.deploy(wrappedBridge.address, "WTEST", "WTEST", originalERC20Decimals)

        await wrappedBridge.setTrustedRemoteAddress(originalChainId, originalBridge.address)

        callParams = { refundAddress: user.address, zroPaymentAddress: constants.AddressZero }
        adapterParams = "0x"
    })

    it("doesn't renounce ownership", async () => {
        await wrappedBridge.renounceOwnership()
        expect(await wrappedBridge.owner()).to.be.eq(owner.address)
    })


    describe("registerToken", () => {
        it("reverts when called by non owner", async () => {
            await expect(wrappedBridge.connect(user).registerToken(wrappedToken.address, originalChainId, originalToken.address))
            .to.be.revertedWith("Ownable: caller is not the owner")
        })

        it("reverts when local token is address zero", async () => {
            await expect(wrappedBridge.registerToken(constants.AddressZero, originalChainId, originalToken.address))
            .to.be.revertedWith("WrappedBridge:Invalid local/romte address")
        })

        it("reverts when remote token is address zero", async () => {
            await expect(wrappedBridge.registerToken(wrappedToken.address, originalChainId, constants.AddressZero))
            .to.be.revertedWith("WrappedBridge:Invalid local/romte address")
        })

        it("reverts if token already registered", async () => {
            await wrappedBridge.registerToken(wrappedToken.address, originalChainId, originalToken.address)
            await expect(wrappedBridge.registerToken(wrappedToken.address, originalChainId, originalToken.address))
            .to.be.revertedWith("WrappedBridge:Already register")
        })

        it("registers tokens", async () => {
            await wrappedBridge.registerToken(wrappedToken.address, originalChainId, originalToken.address)

            expect(await wrappedBridge.localToRemoteAddress(wrappedToken.address, originalChainId))
            .to.be.eq(originalToken.address)
            expect(await wrappedBridge.remoteToLocalAddress(originalToken.address, originalChainId))
            .to.be.eq(wrappedToken.address)
        })
    })

    describe("setWithdrawalFeeBps", () => {
        const withdrawalFeeBps = 10
        //TOTAL_BPS bridgeFeeBps setBridgeFeeBps
        it("reverts when fee bps is greater than or equal to 100%", async () => {
            await expect(wrappedBridge.setBridgeFeeBps(10000)).to.be.revertedWith("WrappedBridge:Invalid fee bps")
        })

        it("reverts when called by non owner", async () => {
            await expect(wrappedBridge.connect(user).setBridgeFeeBps(withdrawalFeeBps))
            .to.be.revertedWith("Ownable: caller is not the owner")
        })

        it("sets withdrawal fee bps", async () => {
            await wrappedBridge.setBridgeFeeBps(withdrawalFeeBps)
            expect(await wrappedBridge.bridgeFeeBps()).to.be.eq(withdrawalFeeBps)
        })
    })

    describe("_nonblockingLzReceive", () => {
        it("reverts when payload has incorrect packet type", async () => {
            const pkInvalid = 1
            await expect(wrappedBridge.simulateNonblockingLzReceive(originalChainId, createPayload(pkInvalid)))
            .to.be.revertedWith("WrappedBridge:Invalid pkType")
        })

        it("reverts when tokens aren't registered", async () => {
            await expect(wrappedBridge.simulateNonblockingLzReceive(originalChainId, createPayload()))
            .to.be.revertedWith("WrappedBridge:Invalid local token address")
        })

        it("mints wrapped tokens", async () => {
            await wrappedBridge.registerToken(wrappedToken.address, originalChainId, originalToken.address)
            await wrappedBridge.simulateNonblockingLzReceive(originalChainId, createPayload())

            expect(await wrappedToken.totalSupply()).to.be.eq(amount)
            expect(await wrappedToken.balanceOf(user.address)).to.be.eq(amount)
            expect(await wrappedBridge.totalValueLocked(originalChainId, originalToken.address)).to.be.eq(amount)
        })
    })

    describe("bridge", () => {
        let fee
        beforeEach(async () => {
            fee = (await wrappedBridge.estimateGasFee(originalChainId, false, adapterParams)).nativeFee
        })

        it("reverts when token is address zero", async () => {
            await expect(wrappedBridge.connect(user).bridge(constants.AddressZero, originalChainId, user.address, amount, false, callParams, adapterParams, { value: fee }))
            .to.be.revertedWith("WrappedBridge:Invalid token address")
        })

        it("reverts when to is address zero", async () => {
            await expect(wrappedBridge.connect(user).bridge(wrappedToken.address, originalChainId,constants.AddressZero, amount, false, callParams, adapterParams, { value: fee }))
            .to.be.revertedWith("WrappedBridge:Invalid to address and amount params")
        })

        it("reverts when useCustomAdapterParams is false and non-empty adapterParams are passed", async () => {
            const adapterParamsV1 = ethers.utils.solidityPack(["uint16", "uint256"], [1, 200000])
            await expect(wrappedBridge.connect(user).bridge(wrappedToken.address, originalChainId, user.address, amount,false, callParams, adapterParamsV1, { value: fee }))
            .to.be.revertedWith("BridgeBase:adapterParams must be empty")
        })

        // address localToken,
        // uint16 remoteChainId,
        // address to,
        // uint amountInto,
        // bool unwrapWeth, 
        // LzLib.CallParams calldata callParams, 
        // bytes memory adapterParams

        it("reverts when token is not registered", async () => {
            await expect(wrappedBridge.connect(user).bridge(wrappedToken.address, originalChainId, user.address, amount, false, callParams, adapterParams, { value: fee }))
            .to.be.revertedWith("WrappedBridge:Invalid token address")
        })

        it("reverts when amount is 0", async () => {
            await wrappedBridge.registerToken(wrappedToken.address, originalChainId, originalToken.address)
            await expect(wrappedBridge.connect(user).bridge(wrappedToken.address, originalChainId, user.address, 0, false, callParams, adapterParams, { value: fee }))
            .to.be.revertedWith("WrappedBridge:Invalid to address and amount params")
        })

        it("burns wrapped tokens", async () => {
            await wrappedBridge.registerToken(wrappedToken.address, originalChainId, originalToken.address)

            // Tokens minted
            await wrappedBridge.simulateNonblockingLzReceive(originalChainId, createPayload())

            expect(await wrappedToken.totalSupply()).to.be.eq(amount)
            expect(await wrappedToken.balanceOf(user.address)).to.be.eq(amount)
            expect(await wrappedBridge.totalValueLocked(originalChainId, originalToken.address)).to.be.eq(amount)

            // Tokens burned
            await wrappedBridge.connect(user).bridge(wrappedToken.address, originalChainId, user.address, amount, false, callParams, adapterParams, { value: fee })

            expect(await wrappedToken.totalSupply()).to.be.eq(0)
            expect(await wrappedToken.balanceOf(user.address)).to.be.eq(0)
            expect(await wrappedBridge.totalValueLocked(originalChainId, originalToken.address)).to.be.eq(0)
        })
    })
//WrappedBridge 
})