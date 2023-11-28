import { ethers } from 'hardhat'
import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployDeployerFixture } from './fixtures/deployDeployerFixture'
import { getCreate2Meta } from '../scripts/utils/create2'

describe('Deployer', () => {
  it('can deploy contract', async () => {
    const { deployer, deployerAddress } = await loadFixture(deployDeployerFixture)
    const salt = 'Have some flavor'
    const contractfactory = await ethers.getContractFactory('BaseTokenTest')
    const types = contractfactory.interface.deploy.inputs.map((input) => input.type)
    const meta = getCreate2Meta(deployerAddress, salt, contractfactory.bytecode, { types, values: [] })

    await expect(deployer.deploy(meta.deployBytecode, meta.saltHex))
      .to.emit(deployer, 'Deployed')
      .withArgs(meta.address, meta.saltHex)
  })

  it('reverts when contract is already deployed', async () => {
    const { deployer, deployerAddress } = await loadFixture(deployDeployerFixture)
    const salt = 'Have some flavor'
    const contractfactory = await ethers.getContractFactory('BaseTokenTest')
    const types = contractfactory.interface.deploy.inputs.map((input) => input.type)
    const meta = getCreate2Meta(deployerAddress, salt, contractfactory.bytecode, { types, values: [] })

    await deployer.deploy(meta.deployBytecode, meta.saltHex)
    await expect(deployer.deploy(meta.deployBytecode, meta.saltHex)).to.be.revertedWithCustomError(
      deployer,
      'DeployerFailedDeployment',
    )
  })

  it('reverts when contract bytecode code is empty', async () => {
    const { deployer } = await loadFixture(deployDeployerFixture)
    await expect(deployer.deploy('0x', 0)).to.be.revertedWithCustomError(deployer, 'DeployerEmptyBytecode')
  })

  it('can compute create2 address', async () => {
    const { deployer, deployerAddress } = await loadFixture(deployDeployerFixture)
    const salt = 'Have some flavor'
    const contractfactory = await ethers.getContractFactory('BaseTokenTest')
    const types = contractfactory.interface.deploy.inputs.map((input) => input.type)
    const meta = getCreate2Meta(deployerAddress, salt, contractfactory.bytecode, { types, values: [] })
    const address = await deployer.computeAddress(meta.saltHex, meta.deployBytecodeHash)
    expect(address).to.equal(meta.address)
  })

  it('reverts when pause with other signer', async () => {
    const { deployer, other } = await loadFixture(deployDeployerFixture)
    await expect(deployer.connect(other).pause()).to.be.revertedWithCustomError(deployer, 'OwnableUnauthorizedOwner')
  })

  it('reverts when unpause with other signer', async () => {
    const { deployer, other } = await loadFixture(deployDeployerFixture)
    await deployer.pause()
    await expect(deployer.connect(other).unpause()).to.be.revertedWithCustomError(deployer, 'OwnableUnauthorizedOwner')
  })
})
