import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { ethers } from 'ethers'
import { deployBaseTokenFixture } from '../fixtures/deployBaseTokenTestFixture'

describe('BaseToken mint', () => {
  it('can mint', async () => {
    const { base, owner } = await loadFixture(deployBaseTokenFixture)
    expect(await base.isMinter(owner.address)).to.be.true

    const totalSupplyBefore = await base.totalSupply()
    const tokenBalanceBefore = await base.balanceOf(owner.address)
    const amount = 100n
    await base.mint(owner.address, amount)
    const totalSupplyAfter = await base.totalSupply()
    const mineBalanceAfter = await base.balanceOf(owner.address)
    expect(totalSupplyAfter).to.equal(totalSupplyBefore + amount)
    expect(mineBalanceAfter).to.equal(tokenBalanceBefore + amount)
  })

  it('reverts when mint by other address', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    expect(await base.isMinter(other.address)).to.be.false
    await expect(base.connect(other).mint(other.address, 100n))
      .to.be.revertedWithCustomError(base, 'MintableUnauthorizedMinter')
      .withArgs(other.address)
  })

  it('can mint to others', async () => {
    const { base, owner, other } = await loadFixture(deployBaseTokenFixture)
    expect(await base.isMinter(owner.address)).to.be.true

    const totalSupplyBefore = await base.totalSupply()
    const ownerBalanceBefore = await base.balanceOf(owner.address)
    const otherBalanceBefore = await base.balanceOf(other.address)
    const amount = 100n
    await base.mint(other.address, amount)
    const totalSupplyAfter = await base.totalSupply()
    const ownerBalanceAfter = await base.balanceOf(owner.address)
    const otherBalanceAfter = await base.balanceOf(other.address)
    expect(totalSupplyAfter).to.equal(totalSupplyBefore + amount)
    expect(ownerBalanceAfter).to.equal(ownerBalanceBefore)
    expect(otherBalanceAfter).to.equal(otherBalanceBefore + amount)
  })

  it('reverts when mint to zero address', async () => {
    const { base } = await loadFixture(deployBaseTokenFixture)
    await expect(base.mint(ethers.ZeroAddress, 100n))
      .to.be.revertedWithCustomError(base, 'MintableInvalidReceiver')
      .withArgs(ethers.ZeroAddress)
  })

  it('set mintable', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await base.setMinter(other.address, true)
    expect(await base.isMinter(other.address)).to.be.true

    await base.setMinter(other.address, false)
    expect(await base.isMinter(other.address)).to.be.false
  })

  it('reverts when set minter with zero address', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await base.setMinter(other.address, true)

    await expect(base.setMinter(ethers.ZeroAddress, true)).to.be.revertedWithCustomError(base, 'MintableInvalidMinter')
  })

  it('reverts when set minter with same address', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await base.setMinter(other.address, true)

    await expect(base.setMinter(other.address, true)).to.be.revertedWithCustomError(base, 'MintableSameValueAlreadySet')
  })

  it('should emit event when set minter', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await expect(base.setMinter(other.address, true)).to.emit(base, 'MinterSet').withArgs(other.address, true)
    await expect(base.setMinter(other.address, false)).to.emit(base, 'MinterSet').withArgs(other.address, false)
  })
})
