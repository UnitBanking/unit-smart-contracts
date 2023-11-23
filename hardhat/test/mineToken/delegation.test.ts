import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployMineFixture } from '../fixtures/deployMineFixture'
import { expect } from 'chai'
import { randomBytes } from 'ethers'
import { ethers } from 'hardhat'

describe('MineToken delegations', () => {
  const DelegationType = {
    Delegation: [
      { name: 'delegatee', type: 'address' },
      { name: 'nonce', type: 'uint256' },
      { name: 'expiry', type: 'uint256' },
    ],
  }
  it('should delegate vote', async () => {
    const { mine, other, owner } = await loadFixture(deployMineFixture)
    await mine.delegate(other.address)
    expect(await mine.delegates(owner.address)).to.equal(other.address)
  })

  it('delegate should emit event', async () => {
    const { mine, other, owner } = await loadFixture(deployMineFixture)
    const votes = await mine.balanceOf(owner.address)
    const defaultDelegatee = await mine.defaultDelegatee()
    await expect(mine.delegate(other.address))
      .to.emit(mine, 'DelegateChanged')
      .withArgs(owner.address, defaultDelegatee, other.address)
      .to.emit(mine, 'DelegateVotesChanged')
      .withArgs(other.address, 0, votes)
  })

  it('should not be able to delegate to zero address', async () => {
    const { mine } = await loadFixture(deployMineFixture)
    await expect(mine.delegate(await mine.defaultDelegatee())).to.be.revertedWithCustomError(
      mine,
      'DelegateToDefaultDelegatee',
    )
  })

  it('initial votes is zero', async () => {
    const { mine, owner } = await loadFixture(deployMineFixture)
    expect(await mine.getCurrentVotes(owner.address)).to.equal(0)
  })

  it('default vote is delegated to default delegatee', async () => {
    const { mine, owner, other } = await loadFixture(deployMineFixture)
    const defaultDelegatee = await mine.defaultDelegatee()
    expect(await mine.getCurrentVotes(defaultDelegatee)).to.equal(await mine.balanceOf(owner.address))

    await mine.mint(owner.address, BigInt(100000) * BigInt(10) ** BigInt(18))

    const expectedVotes = (await mine.balanceOf(owner.address)) + (await mine.balanceOf(other.address))
    expect(await mine.getCurrentVotes(defaultDelegatee)).to.equal(expectedVotes)

    await mine.burn(await mine.balanceOf(owner.address))
    expect(await mine.getCurrentVotes(defaultDelegatee)).to.equal(await mine.balanceOf(other.address))
  })

  it('votes after delegation', async () => {
    const { mine, other, owner } = await loadFixture(deployMineFixture)
    await mine.delegate(other.address)
    expect(await mine.getCurrentVotes(other.address)).to.equal(await mine.balanceOf(owner.address))
  })

  it('get prior votes', async () => {
    const { mine, other, owner } = await loadFixture(deployMineFixture)
    await mine.delegate(other.address)
    const blockNumber = await ethers.provider.getBlockNumber()
    await ethers.provider.send('evm_mine')
    expect(await mine.getPriorVotes(other.address, blockNumber)).to.equal(await mine.balanceOf(owner.address))
  })

  it('get prior votes too low', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    await mine.delegate(other.address)
    const blockNumber = await ethers.provider.getBlockNumber()
    expect(await mine.getPriorVotes(other.address, blockNumber - 1)).to.equal(0)
  })

  it('get prior votes no delegation', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    const blockNumber = await ethers.provider.getBlockNumber()
    expect(await mine.getPriorVotes(other.address, blockNumber)).to.equal(0)
  })

  it('change default delegation, and verify current votes and prior votes', async () => {
    const { mine, other, owner } = await loadFixture(deployMineFixture)
    const defaultDelegatee = await mine.defaultDelegatee()
    expect(await mine.getCurrentVotes(defaultDelegatee)).to.equal(await mine.balanceOf(owner.address))
    const blockNumber = await ethers.provider.getBlockNumber()
    await ethers.provider.send('evm_mine')
    await mine.setDefaultDelegatee(other.address)
    expect(await mine.getCurrentVotes(defaultDelegatee)).to.equal(0)
    expect(await mine.getCurrentVotes(other.address)).to.equal(await mine.balanceOf(owner.address))
    expect(await mine.getPriorVotes(defaultDelegatee, blockNumber)).to.equal(await mine.balanceOf(owner.address))
  })

  it('update votes after mint', async () => {
    const { mine, other, owner } = await loadFixture(deployMineFixture)
    await mine.delegate(other.address)
    const firstBlockNumber = await ethers.provider.getBlockNumber()
    const firstBalance = await mine.balanceOf(owner.address)
    await ethers.provider.send('evm_mine')
    await ethers.provider.send('evm_mine')
    await ethers.provider.send('evm_mine')
    await mine.mint(owner.address, BigInt(100000) * BigInt(10) ** BigInt(18))
    const secondBalance = await mine.balanceOf(owner.address)
    const secondBlockNumber = await ethers.provider.getBlockNumber()

    expect(await mine.getPriorVotes(other.address, firstBlockNumber)).to.equal(firstBalance)
    expect(await mine.getPriorVotes(other.address, secondBlockNumber)).to.equal(secondBalance)
  })

  it('update votes after transfer of token', async () => {
    const { mine, other, owner } = await loadFixture(deployMineFixture)
    await mine.delegate(other.address)

    await mine.setMinter(other.address, true)
    await mine.connect(other).mint(other.address, BigInt(100000) * BigInt(10) ** BigInt(18))
    await mine.connect(other).transfer(owner.address, BigInt(100000) * BigInt(10) ** BigInt(18))

    expect(await mine.getCurrentVotes(other.address)).to.equal(await mine.balanceOf(owner.address))
  })

  it('delegate via signature expired', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    await expect(
      mine.delegateBySig(other.address, 1, 1, 1, randomBytes(32), randomBytes(32)),
    ).to.be.revertedWithCustomError(mine, 'DelegateExpired')
  })

  it('delegate via invalid signature', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    await expect(
      mine.delegateBySig(other.address, 1, Date.now() + 1000, 1, randomBytes(32), randomBytes(32)),
    ).to.be.revertedWithCustomError(mine, 'InvalidDelegateSignature')
  })

  it('delegate via invalid nonce', async () => {
    const { mine, other, owner } = await loadFixture(deployMineFixture)
    const expiry = Date.now() + 100000

    const name = await mine.name()
    const address = await mine.getAddress()
    const chainId = (await ethers.provider.getNetwork()).chainId

    const rawSignature = await owner.signTypedData(
      {
        name,
        chainId,
        verifyingContract: address,
      },
      DelegationType,
      {
        delegatee: other.address,
        nonce: 0,
        expiry,
      },
    )
    const signature = splitSignature(rawSignature)
    await mine.delegateBySig(other.address, 0, expiry, signature.v, signature.r, signature.s)
    await expect(
      mine.delegateBySig(other.address, 0, expiry, signature.v, signature.r, signature.s),
    ).to.be.revertedWithCustomError(mine, 'InvalidDelegateNonce')
  })

  it('delegate via signature', async () => {
    const { mine, other, owner } = await loadFixture(deployMineFixture)
    const expiry = Date.now() + 100000
    const name = await mine.name()
    const address = await mine.getAddress()
    const chainId = (await ethers.provider.getNetwork()).chainId

    const rawSignature = await owner.signTypedData(
      {
        name,
        chainId,
        verifyingContract: address,
      },
      DelegationType,
      {
        delegatee: other.address,
        nonce: 0,
        expiry,
      },
    )
    const signature = splitSignature(rawSignature)
    await mine.delegateBySig(other.address, 0, expiry, signature.v, signature.r, signature.s)
    expect(await mine.getCurrentVotes(other.address)).to.equal(await mine.balanceOf(owner.address))
  })

  it('throw block number is too high error', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    await expect(mine.getPriorVotes(other.address, 1111111111111)).to.be.revertedWithCustomError(
      mine,
      'BlockNumberTooHigh',
    )
  })
})

function splitSignature(signature: string) {
  if (signature.length !== 132) {
    throw new Error('Invalid signature length')
  }

  const r = '0x' + signature.slice(2, 66)
  const s = '0x' + signature.slice(66, 130)
  let v = parseInt('0x' + signature.slice(130, 132), 16)

  if (v < 27) v += 27

  return { r, s, v }
}
