import { expect } from 'chai'
import { ethers as constants } from 'ethers'
import { ethers } from 'hardhat'
import { deployUnitFixture } from '../fixtures/deployUnitFixture'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'

describe('UnitToken ERC20 interfaces', () => {
  it('can deploy', async () => {
    const unit = await ethers.deployContract('UnitToken', [], {})
    const address = await unit.getAddress()
    expect(address.length).to.be.gt(0)
  })

  it('has token info', async () => {
    const { unit } = await loadFixture(deployUnitFixture)
    const name = await unit.name()
    const symbol = await unit.symbol()
    const decimals = await unit.decimals()
    expect(name).to.equal('Unit Token')
    expect(symbol).to.equal('UNIT')
    expect(decimals).to.equal(18)
  })

  it('can transfer', async () => {
    const { unit, owner, other } = await loadFixture(deployUnitFixture)
    const balanceBefore = await unit.balanceOf(other.address)

    const tx = await unit.transfer(other.address, 100)
    await expect(tx).to.emit(unit, 'Transfer').withArgs(owner.address, other.address, 100)

    const balanceAfter = await unit.balanceOf(other.address)
    expect(balanceAfter - balanceBefore).to.equal(100)
  })

  it('reverts in transfer when address is zero', async () => {
    const { unit } = await loadFixture(deployUnitFixture)
    const tx = unit.transfer(constants.ZeroAddress, 100)
    await expect(tx).to.be.revertedWithCustomError(unit, 'ERC20InvalidReceiver').withArgs(constants.ZeroAddress)
  })

  it('reverts in transfer when balance is low', async () => {
    const { unit, owner, other } = await loadFixture(deployUnitFixture)
    const balance = await unit.balanceOf(owner.address)
    const tx = unit.transfer(other.address, balance + 1n)
    await expect(tx)
      .to.be.revertedWithCustomError(unit, 'ERC20InsufficientBalance')
      .withArgs(owner.address, balance, balance + 1n)
  })

  it('can approve', async () => {
    const { unit, owner, other } = await loadFixture(deployUnitFixture)
    const allowanceBefore = await unit.allowance(owner.address, other.address)
    expect(allowanceBefore).to.equal(0)

    const tx = await unit.approve(other.address, 100)
    await expect(tx).to.emit(unit, 'Approval').withArgs(owner.address, other.address, 100)

    const allowanceAfter = await unit.allowance(owner.address, other.address)
    expect(allowanceAfter).to.equal(100)
  })

  it('reverts in approve when address is zero', async () => {
    const { unit } = await loadFixture(deployUnitFixture)
    const tx = unit.approve(constants.ZeroAddress, 100)
    await expect(tx).to.be.revertedWithCustomError(unit, 'ERC20InvalidSpender').withArgs(constants.ZeroAddress)
  })

  it('allows transfer from other and allowance is updated correctly', async () => {
    const { unit, owner, other } = await loadFixture(deployUnitFixture)
    const balanceBefore = await unit.balanceOf(other.address)
    await unit.approve(other.address, 200)
    const allowanceBefore = await unit.allowance(owner.address, other.address)
    expect(allowanceBefore).to.equal(200)

    await unit.connect(other).transferFrom(owner.address, other.address, 100)

    const balanceAfter = await unit.balanceOf(other.address)
    expect(balanceAfter - balanceBefore).to.equal(100)

    const allowanceAfter = await unit.allowance(owner.address, other.address)
    expect(allowanceAfter).to.equal(100)
  })

  it('allows transfer from other to another', async () => {
    const { unit, owner, other, another } = await loadFixture(deployUnitFixture)
    const balanceBefore = await unit.balanceOf(another.address)
    await unit.approve(other.address, 200)
    const allowanceBefore = await unit.allowance(owner.address, other.address)
    expect(allowanceBefore).to.equal(200)

    const tx = await unit.connect(other).transferFrom(owner.address, another.address, 100)
    await expect(tx).to.not.emit(unit, 'Approval')

    const balanceAfter = await unit.balanceOf(another.address)
    expect(balanceAfter - balanceBefore).to.equal(100)

    const otherBalanceAfter = await unit.balanceOf(other.address)
    expect(otherBalanceAfter).to.equal(0)

    const allowanceAfter = await unit.allowance(owner.address, other.address)
    expect(allowanceAfter).to.equal(100)
  })

  it('does not update allowance when it is set to unit256.max', async () => {
    const { unit, owner, other } = await loadFixture(deployUnitFixture)
    await unit.approve(other.address, constants.MaxUint256)
    const allowanceBefore = await unit.allowance(owner.address, other.address)
    expect(allowanceBefore).to.equal(constants.MaxUint256)

    await unit.connect(other).transferFrom(owner.address, other.address, 100)

    const allowanceAfter = await unit.allowance(owner.address, other.address)
    expect(allowanceAfter).to.equal(constants.MaxUint256)
  })

  it('reverts in transferFrom when allowance is low', async () => {
    const { unit, owner, other } = await loadFixture(deployUnitFixture)

    await unit.approve(other.address, 100)
    const tx = unit.connect(other).transferFrom(owner.address, other.address, 101)
    await expect(tx).to.be.revertedWithCustomError(unit, 'ERC20InsufficientAllowance').withArgs(other.address, 100, 101)
  })
})
