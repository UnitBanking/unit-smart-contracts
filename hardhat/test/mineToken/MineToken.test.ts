import { expect } from 'chai'
import { ethers as constants } from 'ethers'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployMineFixture } from '../fixtures/deployMineFixture'

describe('UintToken ERC20 interfaces', () => {
  it('can deploy', async () => {
    const { mine } = await loadFixture(deployMineFixture)
    const address = await mine.getAddress()
    expect(address.length).to.be.gt(0)
  })

  it('has token info', async () => {
    const { mine } = await loadFixture(deployMineFixture)
    const name = await mine.name()
    const symbol = await mine.symbol()
    const decimals = await mine.decimals()
    expect(name).to.equal('Mine Token')
    expect(symbol).to.equal('MINE')
    expect(decimals).to.equal(18)
  })

  it('max supply', async () => {
    const { mine } = await loadFixture(deployMineFixture)
    const maxSupply = await mine.MAX_SUPPLY()
    expect(maxSupply).to.equal(1022700000n * 10n ** 18n)
  })

  it('can transfer', async () => {
    const { mine, owner, other } = await loadFixture(deployMineFixture)
    const balanceBefore = await mine.balanceOf(other.address)

    const tx = await mine.transfer(other.address, 100)
    await expect(tx).to.emit(mine, 'Transfer').withArgs(owner.address, other.address, 100)

    const balanceAfter = await mine.balanceOf(other.address)
    expect(balanceAfter - balanceBefore).to.equal(100)
  })

  it('reverts in transfer when address is zero', async () => {
    const { mine } = await loadFixture(deployMineFixture)
    const tx = mine.transfer(constants.ZeroAddress, 100)
    await expect(tx).to.be.revertedWithCustomError(mine, 'ERC20InvalidReceiver').withArgs(constants.ZeroAddress)
  })

  it('reverts in transfer when balance is low', async () => {
    const { mine, owner, other } = await loadFixture(deployMineFixture)
    const balance = await mine.balanceOf(owner.address)
    const tx = mine.transfer(other.address, balance + 1n)
    await expect(tx)
      .to.be.revertedWithCustomError(mine, 'ERC20InsufficientBalance')
      .withArgs(owner.address, balance, balance + 1n)
  })

  it('can approve', async () => {
    const { mine, owner, other } = await loadFixture(deployMineFixture)
    const allowanceBefore = await mine.allowance(owner.address, other.address)
    expect(allowanceBefore).to.equal(0)

    const tx = await mine.approve(other.address, 100)
    await expect(tx).to.emit(mine, 'Approval').withArgs(owner.address, other.address, 100)

    const allowanceAfter = await mine.allowance(owner.address, other.address)
    expect(allowanceAfter).to.equal(100)
  })

  it('reverts in approve when address is zero', async () => {
    const { mine } = await loadFixture(deployMineFixture)
    const tx = mine.approve(constants.ZeroAddress, 100)
    await expect(tx).to.be.revertedWithCustomError(mine, 'ERC20InvalidSpender').withArgs(constants.ZeroAddress)
  })

  it('allows transfer from other and allowance is updated correctly', async () => {
    const { mine, owner, other } = await loadFixture(deployMineFixture)
    const balanceBefore = await mine.balanceOf(other.address)
    await mine.approve(other.address, 200)
    const allowanceBefore = await mine.allowance(owner.address, other.address)
    expect(allowanceBefore).to.equal(200)

    await mine.connect(other).transferFrom(owner.address, other.address, 100)

    const balanceAfter = await mine.balanceOf(other.address)
    expect(balanceAfter - balanceBefore).to.equal(100)

    const allowanceAfter = await mine.allowance(owner.address, other.address)
    expect(allowanceAfter).to.equal(100)
  })

  it('allows transfer from other to another', async () => {
    const { mine, owner, other, another } = await loadFixture(deployMineFixture)
    const balanceBefore = await mine.balanceOf(another.address)
    await mine.approve(other.address, 200)
    const allowanceBefore = await mine.allowance(owner.address, other.address)
    expect(allowanceBefore).to.equal(200)

    const tx = await mine.connect(other).transferFrom(owner.address, another.address, 100)
    await expect(tx).to.not.emit(mine, 'Approval')

    const balanceAfter = await mine.balanceOf(another.address)
    expect(balanceAfter - balanceBefore).to.equal(100)

    const otherBalanceAfter = await mine.balanceOf(other.address)
    expect(otherBalanceAfter).to.equal(0)

    const allowanceAfter = await mine.allowance(owner.address, other.address)
    expect(allowanceAfter).to.equal(100)
  })

  it('does not update allowance when it is set to unit256.max', async () => {
    const { mine, owner, other } = await loadFixture(deployMineFixture)
    await mine.approve(other.address, constants.MaxUint256)
    const allowanceBefore = await mine.allowance(owner.address, other.address)
    expect(allowanceBefore).to.equal(constants.MaxUint256)

    await mine.connect(other).transferFrom(owner.address, other.address, 100)

    const allowanceAfter = await mine.allowance(owner.address, other.address)
    expect(allowanceAfter).to.equal(constants.MaxUint256)
  })

  it('reverts in transferFrom when allowance is low', async () => {
    const { mine, owner, other } = await loadFixture(deployMineFixture)

    await mine.approve(other.address, 100)
    const tx = mine.connect(other).transferFrom(owner.address, other.address, 101)
    await expect(tx).to.be.revertedWithCustomError(mine, 'ERC20InsufficientAllowance').withArgs(other.address, 100, 101)
  })
})
