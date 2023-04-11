let { expect } = require('chai')
let hardhat = require('hardhat')
let { diamondOwner } = require('../config/config.js')
let { ethers } = hardhat
let constants = require('../config/config.js')
let { deployDiamond } = require('../scripts/deployMainDiamond.js')

describe('Testing the deposit function', function () {
  beforeEach(async function () {
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [constants.diamondOwner],
    });

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [constants.userA],
    });

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [constants.userB],
    });

    diamondOwner = await ethers.getSigner(constants.diamondOwner)
    userA = await ethers.getSigner(constants.userA)
    userB = await ethers.getSigner(constants.userB)
    
    diamondAddress = await deployDiamond(diamondOwner)
    vaultFacet = await ethers.getContractAt('VaultFacet', diamondAddress)
    publicInfoFacet = await ethers.getContractAt('PublicInfoFacet', diamondAddress)
    managementFacet = await ethers.getContractAt('ManagementFacet', diamondAddress)

    usdcContract = await ethers.getContractAt('VaultFacet', constants.usdc)
    
    //positionForStrategy1 = await publicInfoFacet.calculatePositionForStrategy("optimism","velodrome","usdcdai")
    positionForStrategy2 = await publicInfoFacet.calculatePositionForStrategy("optimism","velodrome","usdcmai")
    positionForStrategy3 = await publicInfoFacet.calculatePositionForStrategy("optimism","velodrome","usdcdola")
  })
  
  describe('Testing the requirements', function () {
    beforeEach(async function () {
      tokensToEnable = [constants.usdc]
      await managementFacet.connect(diamondOwner).enableTokens(tokensToEnable, true)
    })

    it.skip('Should not allow to mint 1USD tokens to the zero address', async function () {
      await expect(vaultFacet.connect(userA).deposit(constants.usdc, ethers.constants.AddressZero, ethers.utils.parseUnits('7000',6)))
        .to.be.reverted
    })

    it.skip('Should not allow to deposit a token that is not enabled', async function () {
      await expect(vaultFacet.connect(userA).deposit(constants.mai, userA.address, ethers.utils.parseUnits('7000',18)))
        .to.be.reverted
    })

    it.skip('Should not allow to deposit if vault is closed', async function () {
      await expect(vaultFacet.connect(userA).deposit(constants.usdc, userA.address, ethers.utils.parseUnits('7000',6)))
        .to.be.reverted
    })

    it.skip('Should not allow to deposit if total allocation is not at 100%', async function () {
      await managementFacet.connect(diamondOwner).changeStatus(1)
       
      await expect(vaultFacet.connect(userA).deposit(constants.usdc, userA.address, ethers.utils.parseUnits('7000',6)))
        .to.be.reverted
    })

    it.skip('Should not allow to deposit twice without 5 blocks of difference', async function () {
      await managementFacet.connect(diamondOwner).createVelodromeStrategy(
        positionForStrategy1,
        constants.dai, 
        constants.usdc_dai_lp,
        constants.usdc_dai_gauge,
        0
      )

      await managementFacet.connect(diamondOwner).createVelodromeStrategy(
        positionForStrategy2,
        constants.mai, 
        constants.usdc_mai_lp,
        constants.usdc_mai_gauge,
        0
      )

      await managementFacet.connect(diamondOwner).createVelodromeStrategy(
        positionForStrategy3,
        constants.dola, 
        constants.usdc_dola_lp,
        constants.usdc_dola_gauge,
        0
      )

      await managementFacet.connect(diamondOwner).activateStrategy(50, positionForStrategy1)
      await managementFacet.connect(diamondOwner).activateStrategy(25, positionForStrategy2)
      await managementFacet.connect(diamondOwner).activateStrategy(25, positionForStrategy3)
     
      await managementFacet.connect(diamondOwner).changeStatus(1)
  
      await usdcContract.connect(userA).approve(diamondAddress, ethers.utils.parseUnits('100000',6))
      
      await vaultFacet.connect(userA).deposit(constants.usdc, userA.address, ethers.utils.parseUnits('7000',6))

      const balance1USD = await vaultFacet.balanceOf(userA.address)
      console.log(balance1USD)
  
      await hre.network.provider.send("hardhat_mine", ["0x3"])
  
      await expect(vaultFacet.connect(userA).deposit(constants.usdc, userA.address, ethers.utils.parseEther('8000')))
        .to.be.reverted
    })

    it.skip('Should not allow to deposit less than 10 USDC', async function () {

      const MasterChefFactory = await ethers.getContractFactory('MasterChefStrategy')
      this.MasterChefContract = await MasterChefFactory.deploy()

      positionForStrategy1 = await publicInfoFacet.calculatePositionForStrategy("masterchef","spiritswap","usdcfrax")
    
      await managementFacet.connect(diamondOwner).createMasterChefStrategy(
        positionForStrategy1,
        this.MasterChefContract.address, 
        config.name1,
        config.poolId1,
        config.routerFRAXUSDC,
        config.spiritRouter,
        config.usdc_frax_lpToken,
        config.spiritToken,
        config.spiritMasterChef
      )

      await managementFacet.connect(diamondOwner).activateStrategy(100, positionForStrategy1)
     
      await managementFacet.connect(diamondOwner).changeStatus(1)
  
      await usdcContract.connect(userA).approve(diamondAddress, ethers.utils.parseUnits('100000',6))
      
      await expect(vaultFacet.connect(userA).deposit(config.usdc, userA.address, ethers.utils.parseUnits('9',6)))
        .to.be.revertedWith('Vault_Invalid_Deposit') 
    })

    it.skip('Should not allow to deposit more than the maximum', async function () {

      const MasterChefFactory = await ethers.getContractFactory('MasterChefStrategy')
      this.MasterChefContract = await MasterChefFactory.deploy()

      positionForStrategy1 = await publicInfoFacet.calculatePositionForStrategy("masterchef","spiritswap","usdcfrax")
    
      await managementFacet.connect(diamondOwner).createMasterChefStrategy(
        positionForStrategy1,
        this.MasterChefContract.address, 
        config.name1,
        config.poolId1,
        config.routerFRAXUSDC,
        config.spiritRouter,
        config.usdc_frax_lpToken,
        config.spiritToken,
        config.spiritMasterChef
      )

      await managementFacet.connect(diamondOwner).activateStrategy(100, positionForStrategy1)
     
      await managementFacet.connect(diamondOwner).changeStatus(1)
  
      await usdcContract.connect(userA).approve(diamondAddress, ethers.utils.parseUnits('100000',6))
      
      await expect(vaultFacet.connect(userA).deposit(config.usdc, userA.address, ethers.utils.parseUnits('11000',6)))
        .to.be.revertedWith('Vault_Invalid_Deposit') 
    })
  })

  describe('Testing the correct functionality of deposit', function () {
    beforeEach(async function () {
      tokensToEnable = [constants.usdc]

      //positionForStrategy1 = await publicInfoFacet.calculatePositionForStrategy("optimism","velodrome","usdcdai")
      positionForStrategy2 = await publicInfoFacet.calculatePositionForStrategy("optimism","velodrome","usdcmai")
      positionForStrategy3 = await publicInfoFacet.calculatePositionForStrategy("optimism","velodrome","usdcdola")

      await managementFacet.connect(diamondOwner).enableTokens(tokensToEnable, true)

      // await managementFacet.connect(diamondOwner).createVelodromeStrategy(
      //   positionForStrategy1,
      //   constants.dai, 
      //   constants.usdc_dai_lp,
      //   constants.usdc_dai_gauge,
      //   0
      // )

      await managementFacet.connect(diamondOwner).createVelodromeStrategy(
        positionForStrategy2,
        constants.mai, 
        constants.usdc_mai_lp,
        constants.usdc_mai_gauge,
        0
      )

      await managementFacet.connect(diamondOwner).createVelodromeStrategy(
        positionForStrategy3,
        constants.dola, 
        constants.usdc_dola_lp,
        constants.usdc_dola_gauge,
        0
      )

      //await managementFacet.connect(diamondOwner).activateStrategy(50, positionForStrategy1)
      await managementFacet.connect(diamondOwner).activateStrategy(50, positionForStrategy2)
      await managementFacet.connect(diamondOwner).activateStrategy(50, positionForStrategy3)
      
      await managementFacet.connect(diamondOwner).changeStatus(1)
      
      await managementFacet.connect(diamondOwner).changeMaxUSDC(ethers.utils.parseUnits('20000',6))
    })
    
    it('Should allow a user to deposit USDC', async function () {
      await usdcContract.connect(userA).approve(diamondAddress, ethers.utils.parseUnits('10000',6))
     
      await expect(vaultFacet.connect(userA).deposit(constants.usdc, userA.address, ethers.utils.parseUnits('7000',6)))
        .to.emit(usdcContract, 'Transfer')
        .withArgs(userA.address, diamondAddress, ethers.utils.parseUnits('7000',6))
        .to.emit(vaultFacet, 'Transfer')
        .to.emit(vaultFacet, 'Deposit')

      let balance1USD = await vaultFacet.balanceOf(userA.address)
      console.log(balance1USD)

      await hre.network.provider.send("hardhat_mine", ["0x90"])
      
      let usdcBalanceBefore = await usdcContract.balanceOf(userA.address)

      await expect(vaultFacet.connect(userA).redeem(userA.address, ethers.utils.parseEther('6000')))  
        .to.emit(vaultFacet, "Redeem")

      let usdcBalanceAfter = await usdcContract.balanceOf(userA.address)
      
      console.log(usdcBalanceAfter - usdcBalanceBefore)
    })

    it.skip('Should allow a user to deposit after 5 blocks of the last time deposit was called', async function () {
      await usdcContract.connect(userA).approve(diamondAddress, ethers.utils.parseUnits('1000000',6))
     
      await vaultFacet.connect(userA).deposit(constants.usdc, userA.address, ethers.utils.parseUnits('7000',6))
  
      await hre.network.provider.send("hardhat_mine", ["0x6"])
  
      await expect(vaultFacet.connect(userA).deposit(constants.usdc, userA.address, ethers.utils.parseUnits('8000', 6)))
        .to.emit(usdcContract, 'Transfer')
        .withArgs(userA.address, diamondAddress, ethers.utils.parseUnits('8000',6))
        .to.emit(vaultFacet, 'Transfer')
        .to.emit(vaultFacet, 'Deposit')
    })
    
    it.skip('Should allow a user to deposit and send the 1USD tokens to other account', async function () {
      await usdcContract.connect(userA).approve(diamondAddress, ethers.utils.parseUnits('100000',6))
      
      await expect(vaultFacet.connect(userA).deposit(constants.usdc, userB.address, ethers.utils.parseUnits('7000',6)))
        .to.emit(usdcContract, 'Transfer')
        .withArgs(userA.address, diamondAddress, ethers.utils.parseUnits('7000',6))
        .to.emit(vaultFacet, 'Transfer')
        .to.emit(vaultFacet, 'Deposit')
  
      expect(await vaultFacet.balanceOf(userB.address)).to.be.gt(ethers.utils.parseUnits('6972',18))
    })
  })
})
