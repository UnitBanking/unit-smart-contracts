import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployUnitFixture } from '../fixtures/deployUnitFixture'
import { ethers } from 'ethers'

describe('ownerable', () => {
  it('can set owner', async () => {
    const { unit, other } = await loadFixture(deployUnitFixture)
    await unit.setOwner(other.address)
    expect(await unit.owner()).to.equal(other.address)
  })

  it('only allows owner to transfer ownership', async () => {
    const { unit, other } = await loadFixture(deployUnitFixture)
    await expect(unit.connect(other).setOwner(other.address)).to.be.revertedWithCustomError(
      unit,
      'OwnableUnauthorizedAccount',
    )
  })

  it('reverts when set owner with same address', async () => {
    const { unit, other } = await loadFixture(deployUnitFixture)
    await unit.setOwner(other.address)

    await expect(unit.connect(other).setOwner(other.address)).to.be.revertedWithCustomError(
      unit,
      'OwnableDuplicatedOperation',
    )
  })

  it('reverts when set owner to zero address', async () => {
    const { unit } = await loadFixture(deployUnitFixture)
    await expect(unit.setOwner(ethers.ZeroAddress))
      .to.be.revertedWithCustomError(unit, 'OwnableInvalidOwnerAddress')
      .withArgs(ethers.ZeroAddress)
  })

  it('should emit event when set owner', async () => {
    const { unit, other } = await loadFixture(deployUnitFixture)
    await expect(unit.setOwner(other.address)).to.emit(unit, 'OwnerSet').withArgs(other.address)
  })
})
