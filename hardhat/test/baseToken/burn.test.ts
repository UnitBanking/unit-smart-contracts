import { expect } from 'chai'
import { ethers as constants, ethers } from 'ethers'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployBaseTokenFixture } from '../fixtures/deployBaseTokenTestFixture'

describe('BaseToken burn', () => {
  it('owner can burn', async () => {
    const { base, owner } = await loadFixture(deployBaseTokenFixture)
    expect(await base.isBurner(owner.address)).to.be.true

    const totalSupplyBefore = await base.totalSupply()
    const baseBalanceBefore = await base.balanceOf(owner.address)
    const amount = 100n
    await base.burn(amount)
    const totalSupplyAfter = await base.totalSupply()
    const baseBalanceAfter = await base.balanceOf(owner.address)
    expect(totalSupplyAfter).to.equal(totalSupplyBefore - amount)
    expect(baseBalanceAfter).to.equal(baseBalanceBefore - amount)
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

  it('can burn from with allowance', async () => {
    // Arrange
    const { base, owner, other } = await loadFixture(deployBaseTokenFixture)
    await base.mint(other.address, BigInt(100000) * BigInt(10) ** BigInt(18))
    expect(await base.isBurner(owner.address)).to.be.true
    const approveAmount = 200n
    await base.connect(other).approve(owner.address, approveAmount)

    const totalSupplyBefore = await base.totalSupply()
    const baseBalanceBefore = await base.balanceOf(other.address)
    const amount = 100n

    // Act
    await base.burnFrom(other, amount)

    // Assert
    const totalSupplyAfter = await base.totalSupply()
    const baseBalanceAfter = await base.balanceOf(other.address)
    expect(totalSupplyAfter).to.equal(totalSupplyBefore - amount)
    expect(baseBalanceAfter).to.equal(baseBalanceBefore - amount)
    expect(await base.allowance(other.address, owner.address)).to.eq(approveAmount - amount)
  })

  it('can burn from 0 tokens with allowance', async () => {
    // Arrange
    const { base, owner, other } = await loadFixture(deployBaseTokenFixture)
    await base.mint(other.address, BigInt(100000) * BigInt(10) ** BigInt(18))
    expect(await base.isBurner(owner.address)).to.be.true
    const approveAmount = 200n
    await base.connect(other).approve(owner.address, approveAmount)

    const totalSupplyBefore = await base.totalSupply()
    const baseBalanceBefore = await base.balanceOf(other.address)
    const amount = 0n

    // Act
    await base.burnFrom(other, amount)

    // Assert
    const totalSupplyAfter = await base.totalSupply()
    const baseBalanceAfter = await base.balanceOf(other.address)
    expect(totalSupplyAfter).to.equal(totalSupplyBefore - amount)
    expect(baseBalanceAfter).to.equal(baseBalanceBefore - amount)
    expect(await base.allowance(other.address, owner.address)).to.eq(approveAmount - amount)
  })

  it('cannot burn from without allowance', async () => {
    // Arrange
    const { base, owner, other } = await loadFixture(deployBaseTokenFixture)
    await base.mint(other.address, BigInt(100000) * BigInt(10) ** BigInt(18))
    expect(await base.isBurner(owner.address)).to.be.true
    const amount = 100n

    // Act & Assert
    await expect(base.burnFrom(other, amount))
      .to.be.revertedWithCustomError(base, 'ERC20InsufficientAllowance')
      .withArgs(owner.address, 0, amount)
  })

  it('cannot burn from address zero', async () => {
    // Arrange
    const { base, owner, other } = await loadFixture(deployBaseTokenFixture)
    expect(await base.isBurner(owner.address)).to.be.true
    const amount = 100n

    // Act & Assert
    await expect(base.burnFrom(other, amount))
      .to.be.revertedWithCustomError(base, 'BurnableInvalidTokenOwner')
      .withArgs(constants.ZeroAddress)
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
