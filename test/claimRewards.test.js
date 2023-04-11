const { expect } = require('chai')
const hardhat = require('hardhat')
const { ethers } = hardhat
const constants = require('../config/config.js')
const { deployDiamond } = require('../scripts/deployMainDiamond.js')

describe('Testing claimRewards functions', function () {
  
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

    veloContract = await ethers.getContractAt('VaultFacet', constants.velo)
  })

  describe('Testing requirements', function () {
    it.skip('Should not allow to withdraw rewards if msg.sender is not the owner', async function () {
      await expect(vaultFacet.connect(userA).claimRewards(userA.address))
        .to.be.revertedWith('LibDiamond: Must be contract owner')
    })  
  
    it.skip('Should not allow to withdraw rewards if the recipient is the zero address', async function () {
      await expect(vaultFacet.connect(diamondOwner).claimRewards(ethers.constants.AddressZero))
        .to.be.revertedWith('Vault_Zero_Address_Is_Invalid')
    })
  })

  describe('Testing correct functionality of claim rewards', function () {
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

    it('Should allow to withdraw rewards and check for correct balances', async function () {
      await hre.network.provider.send("hardhat_mine", ["0x323"])
    
      await expect(vaultFacet.connect(diamondOwner).claimRewards(diamondOwner.address))
        .to.emit(vaultFacet, 'RewardsWithdrawed')
        .withArgs(diamondOwner.address)
  
      const veloBalance = await veloContract.balanceOf(diamondOwner.address)
      console.log(veloBalance)
    }) 
  })
})