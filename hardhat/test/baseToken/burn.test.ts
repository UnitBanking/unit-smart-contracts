import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { ethers } from 'ethers'
import { deployBaseTokenFixture } from '../fixtures/deployBaseTokenTestFixture'

describe('BaseToken burn', () => {
  it('owner can burn', async () => {
    const { base, owner } = await loadFixture(deployBaseTokenFixture)
    expect(await base.isBurner(owner.address)).to.be.true

    const totalSupplyBefore = await base.totalSupply()
    const mineBlanceBefore = await base.balanceOf(owner.address)
    const amount = 100n
    await base.burn(amount)
    const totalSupplyAfter = await base.totalSupply()
    const mineBlanceAfter = await base.balanceOf(owner.address)
    expect(totalSupplyAfter).to.equal(totalSupplyBefore - amount)
    expect(mineBlanceAfter).to.equal(mineBlanceBefore - amount)
  })

  it('reverts when burn with other address and zero address is not burner', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    expect(await base.isBurner(other.address)).to.be.false
    await expect(base.connect(other).burn(100n))
      .to.be.revertedWithCustomError(base, 'BurnableUnauthorizedBurner')
      .withArgs(other.address)
  })

  it('does not revert when burn with other address and zero address is burner', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await base.setBurner(ethers.ZeroAddress, true)
    expect(await base.isBurner(other.address)).to.be.false

    await expect(base.connect(other).burn(100n)).to.not.be.revertedWithCustomError(base, 'BurnableUnauthorizedBurner')
  })

  it('set burnable', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await base.setBurner(other.address, true)
    expect(await base.isBurner(other.address)).to.be.true

    await base.setBurner(other.address, false)
    expect(await base.isBurner(other.address)).to.be.false
  })

  it('reverts when set burnable with same address', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await base.setBurner(other.address, true)

    await expect(base.setBurner(other.address, true)).to.be.revertedWithCustomError(base, 'BurnableSameValueAlreadySet')
  })

  it('should emit event when set burnable', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await expect(base.setBurner(other.address, true)).to.emit(base, 'BurnerSet').withArgs(other.address, true)
    await expect(base.setBurner(other.address, false)).to.emit(base, 'BurnerSet').withArgs(other.address, false)
  })
})
