import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployUnitFixture } from '../fixtures/deployUnitFixture'

// create test cases for ownerable

describe('ownerable', () => {
  it('owner can transfer ownership', async () => {
    const { unit, other } = await loadFixture(deployUnitFixture)
    await unit.setOwner(other.getAddress())
    expect(await unit.owner()).to.equal(await other.getAddress())
  })

  it('other address can not transfer ownership', async () => {
    const { unit, other } = await loadFixture(deployUnitFixture)
    await expect(unit.connect(other).setOwner(other.getAddress())).to.be.revertedWithCustomError(
      unit,
      'OwnableUnauthorizedAccount',
    )
  })

  it('set owner', async () => {
    const { unit, other } = await loadFixture(deployUnitFixture)
    await unit.setOwner(other.getAddress())
    expect(await unit.owner()).to.equal(await other.getAddress())
  })

  it('set same address owner', async () => {
    const { unit, other } = await loadFixture(deployUnitFixture)
    await unit.setOwner(other.getAddress())

    // revert with error OwnerableDuplicatedOperation
    await expect(unit.connect(other).setOwner(other.getAddress())).to.be.revertedWithCustomError(
      unit,
      'OwnerDuplicatedOperation',
    )
  })

  it('should emit event when set owner', async () => {
    const { unit, other } = await loadFixture(deployUnitFixture)
    const otherAddress = await other.getAddress()
    await expect(unit.setOwner(other.getAddress())).to.emit(unit, 'OwnerSet').withArgs(otherAddress)
  })
})
