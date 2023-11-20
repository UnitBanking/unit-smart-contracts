import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployUnitFixture } from '../fixtures/deployUnitFixture'

// create test cases for permission mint
describe('permission mint', () => {
  it('owner can mint', async () => {
    const { unit, owner } = await loadFixture(deployUnitFixture)
    expect(await unit.isMintable(owner.getAddress())).to.be.true

    const totalSupplyBefore = await unit.totalSupply()
    const amount = 100n
    await unit.mint(owner.address, amount)
    const totalSupplyAfter = await unit.totalSupply()
    expect(totalSupplyAfter).to.equal(totalSupplyBefore + amount)
  })

  it('other address can not mint', async () => {
    const { unit, owner, other } = await loadFixture(deployUnitFixture)
    expect(await unit.isMintable(other.getAddress())).to.be.false

    await expect(unit.connect(other).mint(owner.address, 100n))
      .to.be.revertedWithCustomError(unit, 'MintableUnauthorizedAccount')
      .withArgs(other.address)
  })

  it('set mintable', async () => {
    const { unit, other } = await loadFixture(deployUnitFixture)
    await unit.setMintable(other.getAddress(), true)
    expect(await unit.isMintable(other.getAddress())).to.be.true

    await unit.setMintable(other.getAddress(), false)
    expect(await unit.isMintable(other.getAddress())).to.be.false
  })

  it('set same address mintable', async () => {
    const { unit, other } = await loadFixture(deployUnitFixture)
    await unit.setMintable(other.getAddress(), true)

    // revert with error MintableDuplicatedOperation
    await expect(unit.setMintable(other.getAddress(), true)).to.be.revertedWithCustomError(
      unit,
      'MintableDuplicatedOperation',
    )
  })

  it('should emit event when set mintable', async () => {
    const { unit, other } = await loadFixture(deployUnitFixture)
    const otherAddress = await other.getAddress()
    await expect(unit.setMintable(other.getAddress(), true)).to.emit(unit, 'MintableSet').withArgs(otherAddress, true)

    await expect(unit.setMintable(other.getAddress(), false)).to.emit(unit, 'MintableSet').withArgs(otherAddress, false)
  })

  it('only allows owner to set mintable', async () => {
    const { unit, other } = await loadFixture(deployUnitFixture)
    await expect(unit.connect(other).setMintable(other.address, true)).to.be.revertedWithCustomError(
      unit,
      'OwnableUnauthorizedAccount',
    )
  })
})
