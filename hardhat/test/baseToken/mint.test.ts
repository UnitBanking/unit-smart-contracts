import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { ethers } from 'ethers'
import { deployBaseTokenFixture } from '../fixtures/deployBaseTokenTestFixture'

describe('BaseToken mint', () => {
  it('owner can mint', async () => {
    const { base, owner } = await loadFixture(deployBaseTokenFixture)
    expect(await base.isMintable(owner.address)).to.be.true

    const totalSupplyBefore = await base.totalSupply()
    const mineBlanceBefore = await base.balanceOf(owner.address)
    const amount = 100n
    await base.mint(amount)
    const totalSupplyAfter = await base.totalSupply()
    const mineBlanceAfter = await base.balanceOf(owner.address)
    expect(totalSupplyAfter).to.equal(totalSupplyBefore + amount)
    expect(mineBlanceAfter).to.equal(mineBlanceBefore + amount)
  })

  it('reverts when mint with other address', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    expect(await base.isMintable(other.address)).to.be.false
    await expect(base.connect(other).mint(100n))
      .to.be.revertedWithCustomError(base, 'MintableUnauthorizedAccount')
      .withArgs(other.address)
  })

  it('set mintable', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await base.setMintable(other.address, true)
    expect(await base.isMintable(other.address)).to.be.true

    await base.setMintable(other.address, false)
    expect(await base.isMintable(other.address)).to.be.false
  })

  it('reverts when set mintable with zero address', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await base.setMintable(other.address, true)

    await expect(base.setMintable(ethers.ZeroAddress, true))
      .to.be.revertedWithCustomError(base, 'MintableInvalidMinterAddress')
      .withArgs(ethers.ZeroAddress)
  })

  it('reverts when set mintable with same address', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await base.setMintable(other.address, true)

    await expect(base.setMintable(other.address, true)).to.be.revertedWithCustomError(
      base,
      'MintableDuplicatedOperation',
    )
  })

  it('should emit event when set mintable', async () => {
    const { base, other } = await loadFixture(deployBaseTokenFixture)
    await expect(base.setMintable(other.address, true)).to.emit(base, 'MintableSet').withArgs(other.address, true)
    await expect(base.setMintable(other.address, false)).to.emit(base, 'MintableSet').withArgs(other.address, false)
  })
})
