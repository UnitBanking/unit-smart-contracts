import { expect } from 'chai'
import { ethers as constants } from 'ethers'
import { deployBaseTokenFixture } from '../fixtures/deployBaseTokenTestFixture'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'

describe('ERC20 interfaces', () => {
  it('has token info', async () => {
    const { base } = await loadFixture(deployBaseTokenFixture)
    const name = await base.name()
    const symbol = await base.symbol()
    const decimals = await base.decimals()
    expect(name).to.equal('ERC20 Token')
    expect(symbol).to.equal('ERC20')
    expect(decimals).to.equal(18)
  })

  it('can transfer', async () => {
    const { base, owner, other } = await loadFixture(deployBaseTokenFixture)
    const ownerBalanceBefore = await base.balanceOf(owner.address)
    const otherBalanceBefore = await base.balanceOf(other.address)

    const tx = await base.transfer(other.address, 100)
    await expect(tx).to.emit(base, 'Transfer').withArgs(owner.address, other.address, 100)

    const ownerBalanceAfter = await base.balanceOf(owner.address)
    const otherBalanceAfter = await base.balanceOf(other.address)
    expect(ownerBalanceBefore - ownerBalanceAfter).to.equal(100)
    expect(otherBalanceAfter - otherBalanceBefore).to.equal(100)
  })

  it('reverts in transfer when address is zero', async () => {
    const { base } = await loadFixture(deployBaseTokenFixture)
    const tx = base.transfer(constants.ZeroAddress, 100)
    await expect(tx).to.be.revertedWithCustomError(base, 'ERC20InvalidReceiver').withArgs(constants.ZeroAddress)
  })

  it('reverts in transfer when balance is low', async () => {
    const { base, owner, other } = await loadFixture(deployBaseTokenFixture)
    const balance = await base.balanceOf(owner.address)
    const tx = base.transfer(other.address, balance + 1n)
    await expect(tx)
      .to.be.revertedWithCustomError(base, 'ERC20InsufficientBalance')
      .withArgs(owner.address, balance, balance + 1n)
  })

  it('can approve', async () => {
    const { base, owner, other } = await loadFixture(deployBaseTokenFixture)
    const allowanceBefore = await base.allowance(owner.address, other.address)
    expect(allowanceBefore).to.equal(0)

    const tx = await base.approve(other.address, 100)
    await expect(tx).to.emit(base, 'Approval').withArgs(owner.address, other.address, 100)

    const allowanceAfter = await base.allowance(owner.address, other.address)
    expect(allowanceAfter).to.equal(100)
  })

  it('reverts in approve when address is zero', async () => {
    const { base } = await loadFixture(deployBaseTokenFixture)
    const tx = base.approve(constants.ZeroAddress, 100)
    await expect(tx).to.be.revertedWithCustomError(base, 'ERC20InvalidSpender').withArgs(constants.ZeroAddress)
  })

  it('allows transfer from other and allowance is updated correctly', async () => {
    const { base, owner, other } = await loadFixture(deployBaseTokenFixture)
    const ownerBalanceBefore = await base.balanceOf(owner.address)
    const otherBalanceBefore = await base.balanceOf(other.address)
    await base.approve(other.address, 200)
    const allowanceBefore = await base.allowance(owner.address, other.address)
    expect(allowanceBefore).to.equal(200)

    await base.connect(other).transferFrom(owner.address, other.address, 100)

    const ownerBalanceAfter = await base.balanceOf(owner.address)
    const otherBalanceAfter = await base.balanceOf(other.address)
    expect(ownerBalanceBefore - ownerBalanceAfter).to.equal(100)
    expect(otherBalanceAfter - otherBalanceBefore).to.equal(100)

    const allowanceAfter = await base.allowance(owner.address, other.address)
    expect(allowanceAfter).to.equal(100)
  })

  it('allows transfer from other to another', async () => {
    const { base, owner, other, another } = await loadFixture(deployBaseTokenFixture)
    const ownerBalanceBefore = await base.balanceOf(owner.address)
    const anotherBalanceBefore = await base.balanceOf(another.address)
    await base.approve(other.address, 200)
    const allowanceBefore = await base.allowance(owner.address, other.address)
    expect(allowanceBefore).to.equal(200)
    const otherBalanceBefore = await base.balanceOf(other.address)
    expect(otherBalanceBefore).to.equal(0)

    const tx = await base.connect(other).transferFrom(owner.address, another.address, 100)
    await expect(tx).to.not.emit(base, 'Approval')

    const ownerBalanceAfter = await base.balanceOf(owner.address)
    const anotherBalanceAfter = await base.balanceOf(another.address)
    expect(ownerBalanceBefore - ownerBalanceAfter).to.equal(100)
    expect(anotherBalanceAfter - anotherBalanceBefore).to.equal(100)

    const otherBalanceAfter = await base.balanceOf(other.address)
    expect(otherBalanceAfter).to.equal(0)

    const allowanceAfter = await base.allowance(owner.address, other.address)
    expect(allowanceAfter).to.equal(100)
  })

  it('does not update allowance when it is set to unit256.max', async () => {
    const { base, owner, other } = await loadFixture(deployBaseTokenFixture)
    await base.approve(other.address, constants.MaxUint256)
    const allowanceBefore = await base.allowance(owner.address, other.address)
    expect(allowanceBefore).to.equal(constants.MaxUint256)

    await base.connect(other).transferFrom(owner.address, other.address, 100)

    const allowanceAfter = await base.allowance(owner.address, other.address)
    expect(allowanceAfter).to.equal(constants.MaxUint256)
  })

  it('reverts in transferFrom when allowance is low', async () => {
    const { base, owner, other } = await loadFixture(deployBaseTokenFixture)

    await base.approve(other.address, 100)
    const tx = base.connect(other).transferFrom(owner.address, other.address, 101)
    await expect(tx).to.be.revertedWithCustomError(base, 'ERC20InsufficientAllowance').withArgs(other.address, 100, 101)
  })
})
