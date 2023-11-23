import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { ethers } from 'ethers'
import { deployBaseTokenFixture } from '../fixtures/deployBaseTokenTestFixture'

describe('BaseToken mint', () => {
  it('owner can mint', async () => {
    const { base, owner } = await loadFixture(deployBaseTokenFixture)
    expect(await base.isMinter(owner.address)).to.be.true

    const totalSupplyBefore = await base.totalSupply()
    const mineBlanceBefore = await base.balanceOf(owner.address)
    const amount = 100n
    await base.mint(owner.address, amount)
    const totalSupplyAfter = await base.totalSupply()
    const mineBlanceAfter = await base.balanceOf(owner.address)
    expect(totalSupplyAfter).to.equal(totalSupplyBefore + amount)
    expect(mineBlanceAfter).to.equal(mineBlanceBefore + amount)
  })

  it('reverts when mint with other address', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    expect(await base.isMinter(other.address)).to.be.false
    await expect(base.connect(other).mint(other.address, 100n))
      .to.be.revertedWithCustomError(base, 'MintableUnauthorizedMinter')
      .withArgs(other.address)
  })

  it('set mintable', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await base.setMinter(other.address, true)
    expect(await base.isMinter(other.address)).to.be.true

    await base.setMinter(other.address, false)
    expect(await base.isMinter(other.address)).to.be.false
  })

  it('reverts when set mintable with zero address', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await base.setMinter(other.address, true)

    await expect(base.setMinter(ethers.ZeroAddress, true)).to.be.revertedWithCustomError(base, 'MintableInvalidMinter')
  })

  it('reverts when set mintable with same address', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await base.setMinter(other.address, true)

    await expect(base.setMinter(other.address, true)).to.be.revertedWithCustomError(base, 'MintableSameValueAlreadySet')
  })

  it('should emit event when set mintable', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await expect(base.setMinter(other.address, true)).to.emit(base, 'MinterSet').withArgs(other.address, true)
    await expect(base.setMinter(other.address, false)).to.emit(base, 'MinterSet').withArgs(other.address, false)
  })
})
