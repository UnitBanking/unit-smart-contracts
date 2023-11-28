import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployDeployerFixture } from './fixtures/deployDeployerFixture'

describe('Pausable', () => {
  it('can pause', async () => {
    const { deployer, owner } = await loadFixture(deployDeployerFixture)
    await expect(deployer.pause()).to.emit(deployer, 'Paused').withArgs(owner.address)
  })

  it('reverts when pause on paused state', async () => {
    const { deployer } = await loadFixture(deployDeployerFixture)
    await deployer.pause()
    await expect(deployer.pause()).to.be.revertedWithCustomError(deployer, 'PausableEnforcedPause')
  })

  it('can unpause', async () => {
    const { deployer, owner } = await loadFixture(deployDeployerFixture)
    await deployer.pause()
    await expect(deployer.unpause()).to.emit(deployer, 'Unpaused').withArgs(owner.address)
  })

  it('reverts when unpause on unpaused state', async () => {
    const { deployer } = await loadFixture(deployDeployerFixture)
    await expect(deployer.unpause()).to.be.revertedWithCustomError(deployer, 'PausableExpectedPause')
  })

  it('reverts when deploy on paused state', async () => {
    const { deployer } = await loadFixture(deployDeployerFixture)
    await deployer.pause()
    await expect(deployer.deploy('0x', 0)).to.be.revertedWithCustomError(deployer, 'PausableEnforcedPause')
  })
})
