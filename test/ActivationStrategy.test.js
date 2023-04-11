const { expect } = require('chai')
const hardhat = require('hardhat')
const { ethers } = hardhat
const constants = require('../config/config.js')
const { deployDiamond } = require('../scripts/deployMainDiamond.js')

describe('Testing the activation of Strategies', function () {
  beforeEach(async function () {
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [constants.diamondOwner],
    });

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [constants.userA],
    });

    diamondOwner = await ethers.getSigner(constants.diamondOwner)
    userA = await ethers.getSigner(constants.userA)
    
    diamondAddress = await deployDiamond(diamondOwner)
    vaultFacet = await ethers.getContractAt('VaultFacet', diamondAddress)
    publicInfoFacet = await ethers.getContractAt('PublicInfoFacet', diamondAddress)
    managementFacet = await ethers.getContractAt('ManagementFacet', diamondAddress)

    usdcContract = await ethers.getContractAt('VaultFacet', constants.usdc)

    positionForStrategy1 = await publicInfoFacet.calculatePositionForStrategy("optimism","velodrome","usdcmai")
  })

  describe('Testing requirements', function () {
    it.skip('Should not allow to activate a velodrome strategy if not the owner', async function () {
      await expect(managementFacet.connect(userA).activateStrategy(50, positionForStrategy1))
        .to.be.revertedWith('LibDiamond: Must be contract owner')   
    })

    it.skip('Should not allow to activate a velodrome strategy if the final total allocation is going to be more than 100%', async function () {
      await expect(managementFacet.connect(diamondOwner).activateStrategy(101, positionForStrategy1))
        .to.be.reverted
    })

    it.skip('Should not allow to activate a velodrome strategy if the vault is open', async function () {
      await managementFacet.connect(diamondOwner).changeStatus(1)
  
      await expect(managementFacet.connect(diamondOwner).activateStrategy(50, positionForStrategy1))
        .to.be.reverted
    })

    it.skip('Should not allow to activate a velodrome strategy that has not been created', async function () {
      await expect(managementFacet.connect(diamondOwner).activateStrategy(50, positionForStrategy1))
        .to.be.reverted
    })

    it.skip('Should not allow to activate a velodrome strategy twice', async function () {
      await managementFacet.connect(diamondOwner).createVelodromeStrategy(
        positionForStrategy1,
        constants.mai, 
        constants.usdc_mai_lp,
        constants.usdc_mai_gauge,
        0
      )
  
      await managementFacet.connect(diamondOwner).activateStrategy(50, positionForStrategy1)
  
      await expect(managementFacet.connect(diamondOwner).activateStrategy(50, positionForStrategy1))
        .to.be.reverted
    })
  })
  
  describe('Testing the correct functionality', function () {
    beforeEach(async function () {
      await managementFacet.connect(diamondOwner).createVelodromeStrategy(
        positionForStrategy1,
        constants.mai, 
        constants.usdc_mai_lp,
        constants.usdc_mai_gauge,
        0
      )
    })

    it('Should allow to activate a velodrome strategy and check for correct activation', async function () {
      await expect(managementFacet.connect(diamondOwner).activateStrategy(50, positionForStrategy1))
        .to.emit(managementFacet, "StrategyActivated")
        .withArgs(positionForStrategy1, 50)
  
      expect(await publicInfoFacet.getTotalAllocation()).to.be.equal(50)
      expect(await publicInfoFacet.getNumberOfStrategies()).to.be.equal(1)
      expect(await publicInfoFacet.getStrategyPosition(0)).to.be.equal(positionForStrategy1)
      expect(await publicInfoFacet.getIndexOfStrategy(positionForStrategy1)).to.be.equal(0)

      console.log(await publicInfoFacet.getStrategyAddressLogic(positionForStrategy1))
      expect(await publicInfoFacet.getAllocationOfStrategy(positionForStrategy1)).to.be.equal(50)
      expect(await publicInfoFacet.isStrategyActive(positionForStrategy1)).to.be.equal(true)
      expect(await publicInfoFacet.hasStrategyBeenCreated(positionForStrategy1)).to.be.equal(true)
      expect(await publicInfoFacet.calculatePositionForStrategy("optimism","velodrome","usdcmai")).to.be.equal(positionForStrategy1)
    })
  })
})
