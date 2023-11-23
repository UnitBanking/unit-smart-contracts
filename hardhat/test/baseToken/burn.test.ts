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

  it('reverts when burn with other address and zero address is not set burnable', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    expect(await base.isBurner(other.address)).to.be.false
    await expect(base.connect(other).burn(100n))
      .to.be.revertedWithCustomError(base, 'BurnableUnauthorizedBurner')
      .withArgs(other.address)
  })

  it('does not revert when burn with other address and zero address is set to burnable', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await base.setBurner(ethers.ZeroAddress, true)
    expect(await base.isBurner(other.address)).to.be.false

    await expect(base.connect(other).burn(100n)).to.not.be.revertedWithCustomError(base, 'BurnableUnauthorizedBurner')
  })

  it('can burn from others', async () => {
    const { base, owner, other } = await loadFixture(deployBaseTokenFixture)
    await base.mint(other.address, 100)
    await base.connect(other).approve(owner.address, 100)

    const amount = 50n
    const totalSupplyBefore = await base.totalSupply()
    const balanceBefore = await base.balanceOf(other.address)

    await base.burnFrom(other.address, amount)

    const totalSupplyAfter = await base.totalSupply()
    const balanceAfter = await base.balanceOf(other.address)
    expect(balanceAfter).to.equal(balanceBefore - amount)
    expect(totalSupplyAfter).to.equal(totalSupplyBefore - amount)
  })

  it('reverts when burn from zero address', async () => {
    const { base } = await loadFixture(deployBaseTokenFixture)
    await expect(base.burnFrom(ethers.ZeroAddress, 100n))
      .to.be.revertedWithCustomError(base, 'ERC20InvalidSender')
      .withArgs(ethers.ZeroAddress)
  })

  it('reverts when burn from others without enough allownace', async () => {
    const { base, owner, other } = await loadFixture(deployBaseTokenFixture)
    await base.mint(other.address, 100)

    await expect(base.burnFrom(other.address, 50))
      .to.be.revertedWithCustomError(base, 'ERC20InsufficientAllowance')
      .withArgs(owner.address, 0, 50)
  })

  it('reverts when burnFrom with other address and zero address is not set burnable', async () => {
    const { base, owner, other } = await loadFixture(deployBaseTokenFixture)
    await base.approve(other.address, 100)
    expect(await base.isBurner(other.address)).to.be.false
    await expect(base.connect(other).burnFrom(owner.address, 100n))
      .to.be.revertedWithCustomError(base, 'BurnableUnauthorizedBurner')
      .withArgs(other.address)
  })

  it('does not revert when burnFrom with other address and zero address is set to burnable', async () => {
    const { base, owner, other } = await loadFixture(deployBaseTokenFixture)
    await base.approve(other.address, 100)
    await base.setBurner(ethers.ZeroAddress, true)
    expect(await base.isBurner(other.address)).to.be.false

    await expect(base.connect(other).burnFrom(owner.address, 100n)).to.not.be.revertedWithCustomError(
      base,
      'BurnableUnauthorizedBurner',
    )
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