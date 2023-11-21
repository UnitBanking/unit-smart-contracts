import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployMineFixture } from '../fixtures/deployMineFixture'
import { ethers } from 'ethers'

describe('ownerable', () => {
  it('can set owner', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    await mine.setOwner(other.address)
    expect(await mine.owner()).to.equal(other.address)
  })

  it('only allows owner to transfer ownership', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    await expect(mine.connect(other).setOwner(other.address)).to.be.revertedWithCustomError(
      mine,
      'OwnableUnauthorizedAccount',
    )
  })

  it('reverts when set owner with same address', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    await mine.setOwner(other.address)

    await expect(mine.connect(other).setOwner(other.address)).to.be.revertedWithCustomError(
      mine,
      'OwnableDuplicatedOperation',
    )
  })

  it('reverts when set owner to zero address', async () => {
    const { mine } = await loadFixture(deployMineFixture)
    await expect(mine.setOwner(ethers.ZeroAddress))
      .to.be.revertedWithCustomError(mine, 'OwnableInvalidOwnerAddress')
      .withArgs(ethers.ZeroAddress)
  })

  it('should emit event when set owner', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    await expect(mine.setOwner(other.address)).to.emit(mine, 'OwnerSet').withArgs(other.address)
  })
})
