let { expect } = require('chai')
let hardhat = require('hardhat')
let { ethers } = hardhat
let constants = require('../config/config.js')
let { deployDiamond } = require('../scripts/deployMainDiamond.js')

describe('Testing the redeem function', function () {
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
    
    positionForStrategy1 = await publicInfoFacet.calculatePositionForStrategy("optimism","velodrome","usdcdai")
    positionForStrategy2 = await publicInfoFacet.calculatePositionForStrategy("optimism","velodrome","usdcmai")
    positionForStrategy3 = await publicInfoFacet.calculatePositionForStrategy("optimism","velodrome","usdcdola")
  })

  describe('Testing the requirements', function () {
    it.skip('Should not allow to redeem if owner is the address zero', async function () {
      await expect(vaultFacet.connect(userA).redeem(ethers.constants.AddressZero, ethers.utils.parseEther('5000')))  
        .to.be.revertedWith('Vault_Zero_Address_Is_Invalid')
    })

    it.skip('Should not allow to redeem more than the maximum of 1USD tokens', async function () {
      await expect(vaultFacet.connect(userA).redeem(userA.address, ethers.utils.parseEther('10001')))  
        .to.be.revertedWith('Vault_Witdrawal_Limit_Reached')
    })

    it.skip('Should not allow to redeem zero 1USD tokens', async function () {
      await expect(vaultFacet.connect(userA).redeem(userA.address, 0))  
        .to.be.revertedWith('Vault_Witdrawal_Limit_Reached')
    })

    it.skip('Should not allow to redeem if the vault is closed', async function () {
      await expect(vaultFacet.connect(userA).redeem(userA.address, ethers.utils.parseEther('5000')))  
        .to.be.revertedWith('Vault_Is_Not_Open')
    })

    it.skip('Should not allow to redeem if the total allocation is not 100%', async function () {
      await managementFacet.connect(diamondOwner).changeStatus(1)

      await expect(vaultFacet.connect(userA).redeem(userA.address, ethers.utils.parseEther('5000')))  
        .to.be.revertedWith('Vault_Invalid_Total_Allocation')
    })
  })

  describe('Testing the correct functionality of reedem', function () {
    beforeEach(async function () {
      tokensToEnable = [constants.usdc]

      positionForStrategy1 = await publicInfoFacet.calculatePositionForStrategy("optimism","velodrome","usdcdai")
      positionForStrategy2 = await publicInfoFacet.calculatePositionForStrategy("optimism","velodrome","usdcmai")
      positionForStrategy3 = await publicInfoFacet.calculatePositionForStrategy("optimism","velodrome","usdcdola")

      await managementFacet.connect(diamondOwner).enableTokens(tokensToEnable, true)

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
  
      await usdcContract.connect(userA).approve(diamondAddress, ethers.utils.parseUnits('1000000',6))
     
      await vaultFacet.connect(userA).deposit(constants.usdc, userA.address, ethers.utils.parseUnits('7000',6))
    })

    it.skip('Should not allow to redeem if the block is not valid', async function () {
      await hre.network.provider.send("hardhat_mine", ["0x3"])
  
      await expect(vaultFacet.connect(userA).redeem(userA.address, ethers.utils.parseEther('5000')))  
        .to.be.revertedWith('Vault_Cannot_Withdraw_In_This_Block')
    })

    it.skip('Should not allow to redeem if the spender is not approved', async function () {
      await hre.network.provider.send("hardhat_mine", ["0x40"])
  
      await expect(vaultFacet.connect(userB).redeem(userA.address, ethers.utils.parseEther('5000')))  
        .to.be.revertedWith('Vault_Not_Enough_Allowance')
    })

    it.skip('Should not allow to redeem if one strategy does not have money', async function () {
      await hre.network.provider.send("hardhat_mine", ["0x40"])
  
      await managementFacet.connect(diamondOwner).changeStatus(0)
  
      await managementFacet.connect(diamondOwner).deActivateStrategy(diamondOwner.address, positionForStrategy1)
      await managementFacet.connect(diamondOwner).activateStrategy(50, positionForStrategy1)
  
      await managementFacet.connect(diamondOwner).changeStatus(1)
  
      await expect(vaultFacet.connect(userA).redeem(userA.address, ethers.utils.parseEther('5000')))  
        .to.be.revertedWith('Vault_Too_Much_Slippage')
    })

    it.skip('Should not allow to redeem if owner do not owns the 1USD amount to be burned', async function () {
      await hre.network.provider.send("hardhat_mine", ["0x40"])
  
      await expect(vaultFacet.connect(userA).redeem(userA.address, ethers.utils.parseEther('10000')))  
        .to.be.revertedWith('ERC20: burn amount exceeds balance')
    })

    it.skip('Should allow to redeem and check correct state', async function () {
      await hre.network.provider.send("hardhat_mine", ["0x40"])
      
      const usdcBalanceBefore = await usdcContract.balanceOf(userA.address)

      await expect(vaultFacet.connect(userA).redeem(userA.address, ethers.utils.parseEther('3500')))  
        .to.emit(vaultFacet, "Redeem")

      const usdcBalanceAfter = await usdcContract.balanceOf(userA.address)
      
      expect(usdcBalanceAfter).to.be.gt(usdcBalanceBefore)
      console.log(usdcBalanceAfter - usdcBalanceBefore)
  
      // expect(await vaultFacet.balanceOf(userA.address)).to.be.gt(ethers.utils.parseUnits('1993',18))
      // expect(await vaultFacet.balanceOf(userA.address)).to.be.lt(ethers.utils.parseUnits('2010',18))
    })

    it.skip('Should allow to redeem if the contract thas enough usdc taking the withdrawal fee', async function () {
      await hre.network.provider.send("hardhat_mine", ["0x40"])

      await usdcContract.connect(userA).transfer(diamondAddress, ethers.utils.parseUnits('6000', 6))
      
      const usdcBalanceBefore = await usdcContract.balanceOf(userA.address)

      await expect(vaultFacet.connect(userA).redeem(userA.address, ethers.utils.parseEther('5000')))  
        .to.emit(vaultFacet, "Redeem")
        .to.emit(usdcContract, 'Transfer')
        .withArgs(diamondAddress, userA.address, ethers.utils.parseUnits('4997.5', 6))

      const usdcBalanceAfter = await usdcContract.balanceOf(userA.address)
      
      expect(usdcBalanceAfter).to.be.gt(usdcBalanceBefore)

      expect(await vaultFacet.balanceOf(diamondAddress)).to.equal(ethers.utils.parseEther('2.5'))
      expect(await vaultFacet.balanceOf(userA.address)).to.be.gt(ethers.utils.parseUnits('1993',18))
      expect(await vaultFacet.balanceOf(userA.address)).to.be.lt(ethers.utils.parseUnits('2010',18))
    })

    it.skip('Should allow to redeem if the contract thas enough usdc when a user is whitelisted', async function () {
      await hre.network.provider.send("hardhat_mine", ["0x40"])

      await managementFacet.connect(diamondOwner).whitelistAddress(userA.address, true)
      await usdcContract.connect(usdcWhale).transfer(diamondAddress, ethers.utils.parseUnits('6000', 6))
      
      const usdcBalanceBefore = await usdcContract.balanceOf(userA.address)

      await expect(vaultFacet.connect(userA).redeem(userA.address, ethers.utils.parseEther('5000')))  
        .to.emit(vaultFacet, "Redeem")
        .to.emit(usdcContract, 'Transfer')
        .withArgs(diamondAddress, userA.address, ethers.utils.parseUnits('5000', 6))

      const usdcBalanceAfter = await usdcContract.balanceOf(userA.address)
      
      expect(usdcBalanceAfter).to.be.gt(usdcBalanceBefore)

      expect(await vaultFacet.balanceOf(userA.address)).to.be.gt(ethers.utils.parseUnits('1993',18))
      expect(await vaultFacet.balanceOf(userA.address)).to.be.lt(ethers.utils.parseUnits('2010',18))
    })

    it.skip('Should allow to redeem someone that is whitelisted and check correct state', async function () {

      expect(await publicInfoFacet.getIfFeeCharged(userA.address)).to.be.equal(false)

      await managementFacet.connect(diamondOwner).whitelistAddress(userA.address, true)

      expect(await publicInfoFacet.getIfFeeCharged(userA.address)).to.be.equal(true)

      await hre.network.provider.send("hardhat_mine", ["0x40"])

      const usdcBalanceBefore = await usdcContract.balanceOf(userA.address)
  
      await expect(vaultFacet.connect(userA).redeem(userA.address, ethers.utils.parseEther('5000')))  
        .to.emit(vaultFacet, "Redeem")
      
      const usdcBalanceAfter = await usdcContract.balanceOf(userA.address)
      
      expect(usdcBalanceAfter).to.be.gt(usdcBalanceBefore)
      expect(await vaultFacet.balanceOf(userA.address)).to.be.gt(ethers.utils.parseUnits('1993',18))
      expect(await vaultFacet.balanceOf(userA.address)).to.be.lt(ethers.utils.parseUnits('2010',18))
    })
  })
})
