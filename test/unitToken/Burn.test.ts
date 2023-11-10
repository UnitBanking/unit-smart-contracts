import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployUnitFixture } from '../fixtures/deployUnitFixture'

// create test cases for permission burn
describe('permission burn', () => {
  it('owner can burn', async () => {
    const { unit, owner } = await loadFixture(deployUnitFixture)
    expect(await unit.isBurnable(owner.address)).to.be.true
  })

  it('other address can not burn', async () => {
    const { unit, other } = await loadFixture(deployUnitFixture)
    expect(await unit.isBurnable(other.getAddress())).to.be.false
  })

  it('set burnable', async () => {
    const { unit, other } = await loadFixture(deployUnitFixture)
    await unit.setBurnable(other.getAddress(), true)
    expect(await unit.isBurnable(other.getAddress())).to.be.true

    await unit.setBurnable(other.getAddress(), false)
    expect(await unit.isBurnable(other.getAddress())).to.be.false
  })

  it('set same address burnable', async () => {
    const { unit, other } = await loadFixture(deployUnitFixture)
    await unit.setBurnable(other.getAddress(), true)

    // revert with error BurnableDuplicatedOperation
    await expect(unit.setBurnable(other.getAddress(), true)).to.be.revertedWithCustomError(
      unit,
      'BurnableDuplicatedOperation',
    )
  })

  it('should emit event when set burnable', async () => {
    const { unit, other } = await loadFixture(deployUnitFixture)
    const otherAddress = await other.getAddress()
    await expect(unit.setBurnable(other.getAddress(), true)).to.emit(unit, 'BurnableSet').withArgs(otherAddress, true)

    await expect(unit.setBurnable(other.getAddress(), false)).to.emit(unit, 'BurnableSet').withArgs(otherAddress, false)
  })

  it('only allows owner to set burnable', async () => {
    const { unit, other } = await loadFixture(deployUnitFixture)
    await expect(unit.connect(other).setBurnable(other.address, true)).to.be.revertedWithCustomError(
      unit,
      'OwnableUnauthorizedAccount',
    )
  })
})
