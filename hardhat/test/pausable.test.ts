import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployDeployerFixture } from './fixtures/deployDeployerFixture'

describe('Pausable', () => {
  it('can pause', async () => {
    const { deployer } = await loadFixture(deployDeployerFixture)
    await expect(deployer.setPaused(true)).to.emit(deployer, 'PausedSet').withArgs(true)
  })

  it('reverts when pause on paused state', async () => {
    const { deployer } = await loadFixture(deployDeployerFixture)
    await deployer.setPaused(true)
    await expect(deployer.setPaused(true)).to.be.revertedWithCustomError(deployer, 'PausableSameValueAlreadySet')
  })

  it('can unpause', async () => {
    const { deployer } = await loadFixture(deployDeployerFixture)
    await deployer.setPaused(true)
    await expect(deployer.setPaused(false)).to.emit(deployer, 'PausedSet').withArgs(false)
  })

  it('reverts when unpause on unpaused state', async () => {
    const { deployer } = await loadFixture(deployDeployerFixture)
    await expect(deployer.setPaused(false)).to.be.revertedWithCustomError(deployer, 'PausableSameValueAlreadySet')
  })
})
