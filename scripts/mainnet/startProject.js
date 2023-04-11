const { ethers } = require('hardhat')
const constants = require('../../config/config.js')

async function startVault () {
  const [deployer] = await ethers.getSigners();

  let diamondAddress = '0x6E0429Bc7807Bea996Af07716Ad5e1231652F0CD'
 // let synthetic = '0xe5e21ded5F05cE1500aA708FE3C3D79Bb964094B'

  vaultFacet = await ethers.getContractAt('VaultFacet', diamondAddress, deployer)
  publicInfoFacet = await ethers.getContractAt('PublicInfoFacet', diamondAddress, deployer)
  managementFacet = await ethers.getContractAt('ManagementFacet', diamondAddress, deployer)
  ownershipFacet = await ethers.getContractAt('OwnershipFacet', diamondAddress, deployer)

  let tokensToEnable = [constants.usdc]

  //positionForStrategy1 = await publicInfoFacet.calculatePositionForStrategy("optimism","velodrome","usdcdai")
  // positionForStrategy2 = await publicInfoFacet.calculatePositionForStrategy("optimism","velodrome","usdcmai")
  // positionForStrategy3 = await publicInfoFacet.calculatePositionForStrategy("optimism","velodrome","usdcdola")

  // let t = await managementFacet.enableTokens(tokensToEnable, true)
  // console.log('enable tokens tx: ', t.hash)
  // t.wait()

  // let t2 = await managementFacet.createVelodromeStrategy(
  //   positionForStrategy3,
  //   constants.dola, 
  //   constants.usdc_dola_lp,
  //   constants.usdc_dola_gauge,
  //   0
  // )
  // console.log('create 1 tx: ', t2.hash)
  // t2.wait()

  // let t3 = await managementFacet.createVelodromeStrategy(
  //   positionForStrategy2,
  //   constants.mai, 
  //   constants.usdc_mai_lp,
  //   constants.usdc_mai_gauge,
  //   0
  // )
  // console.log('create 2 tx: ', t3.hash)
  // t3.wait()

  // await managementFacet.connect(diamondOwner).activateStrategy(50, positionForStrategy1)
  // await managementFacet.connect(diamondOwner).activateStrategy(25, positionForStrategy2)
  // await managementFacet.connect(diamondOwner).activateStrategy(25, positionForStrategy3)
      
  // await managementFacet.connect(diamondOwner).changeStatus(1)

  // t5 = await managementFacet.activateStrategy(50, positionForStrategy3)
  // console.log('activate 1 tx: ', t5.hash)
  // t5.wait()

  // t6 = await managementFacet.activateStrategy(25, positionForStrategy3)
  // console.log('activate 3 tx: ', t6.hash)
  // t6.wait()

  // t7 = await vaultFacet.deposit(constants.usdc, deployer.address, ethers.utils.parseUnits('33',6))
  // console.log('activate 3 tx: ', t7.hash)
  // t7.wait()

  // t8 = await vaultFacet.redeem(deployer.address, ethers.utils.parseEther('10'))
  // console.log('activate 3 tx: ', t8.hash)
  // t8.wait()

  // t9 = await vaultFacet.approve(synthetic, ethers.utils.parseEther('10000'))
  // console.log('claimed: ', t9.hash)
  // t9.wait()

  // t8 = await managementFacet.changeMaxUSDC(ethers.utils.parseUnits('20000',6))
  // console.log('status changed tx: ', t8.hash)
  // t8.wait()

  let t9 = await ownershipFacet.transferOwnership('0xD349FAf58A86ECafB27F8C875E3AF9fE34a29F30')
  console.log('status ownership change: ', t9.hash)
  t9.wait()

  // console.log(await ownershipFacet.owner())
  

  // await managementFacet.connect(diamondOwner).changeMaxUSDC(ethers.utils.parseUnits('20000',6))
  // console.log('Deposit tx: ', tx.hash)
  // receipt = await tx.wait()
  // if (!receipt.status) {
  //   throw Error(`Deposit failed: ${tx.hash}`)
  // }

  // let tx2 
  // let receipt2 

  // tx2 = await vaultFacet.redeem(deployer.address, ethers.utils.parseEther('12'))
  // console.log('Redeem tx', tx2.hash)
  // receipt2 = await tx2.wait()
  // if (!receipt2.status) {
  //   throw Error(`Deposit failed: ${tx2.hash}`)
  // }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
if (require.main === module) {
  startVault()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error)
      process.exit(1)
    })
}

exports.startVault = startVault