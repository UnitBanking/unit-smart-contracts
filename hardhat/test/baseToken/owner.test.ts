import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { ethers } from 'ethers'
import { deployBaseTokenFixture } from '../fixtures/deployBaseTokenTestFixture'

describe('BaseToken ownerable', () => {
  it('can set owner', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await base.setOwner(other.address)
    expect(await base.owner()).to.equal(other.address)
  })

  it('only allows owner to transfer ownership', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await expect(base.connect(other).setOwner(other.address)).to.be.revertedWithCustomError(
      base,
      'OwnableUnauthorizedOwner'
    )
  })

  it('reverts when set owner with same address', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await base.setOwner(other.address)

    await expect(base.connect(other).setOwner(other.address)).to.be.revertedWithCustomError(
      base,
      'OwnableSameValueAlreadySet'
    )
  })

  it('reverts when set owner to zero address', async () => {
    const { base } = await loadFixture(deployBaseTokenFixture)
    await expect(base.setOwner(ethers.ZeroAddress))
      .to.be.revertedWithCustomError(base, 'OwnableInvalidOwner')
      .withArgs(ethers.ZeroAddress)
  })

  it('should emit event when set owner', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await expect(base.setOwner(other.address)).to.emit(base, 'OwnerSet').withArgs(other.address)
  })
})
