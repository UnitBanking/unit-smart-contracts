import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployMineFixture } from '../fixtures/deployMineFixture'
import { expect } from 'chai'
import { ZeroAddress } from 'ethers'
import { ethers } from 'hardhat'

describe('MineToken delegations', () => {
  it('should delegate vote', async () => {
    const { mine, other, owner } = await loadFixture(deployMineFixture)
    await mine.delegate(other.address)
    expect(await mine.delegates(owner.address)).to.equal(other.address)
  })

  it('delegate should emit event', async () => {
    const { mine, other, owner } = await loadFixture(deployMineFixture)
    const votes = await mine.balanceOf(owner.address)
    await expect(mine.delegate(other.address))
      .to.emit(mine, 'DelegateChanged')
      .withArgs(owner.address, ZeroAddress, other.address)
      .to.emit(mine, 'DelegateVotesChanged')
      .withArgs(other.address, 0, votes)
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

    await mine.setMintable(other.address, true)
    await mine.connect(other).mint(other.address, BigInt(100000) * BigInt(10) ** BigInt(18))
    await mine.connect(other).transfer(owner.address, BigInt(100000) * BigInt(10) ** BigInt(18))

    expect(await mine.getCurrentVotes(other.address)).to.equal(await mine.balanceOf(owner.address))
  })

  it('delegate via signature', async () => {
    const { mine, other, owner } = await loadFixture(deployMineFixture)
    const nonce = await mine.nonces(owner.address)
    const expiration = Date.now() + 100000
    const delegateSignature = await owner.signTypedData(
      {
        name: 'MineToken',
        version: '1',
        chainId: 31337,
        verifyingContract: await mine.getAddress(),
      },
      {
        Delegate: [
          { name: 'delegatee', type: 'address' },
          { name: 'nonce', type: 'uint256' },
          { name: 'expiry', type: 'uint256' },
        ],
      },
      {
        delegatee: other.address,
        nonce,
        expiry: expiration,
      },
    )
    // get v and r of delegateSignature
    const signature = delegateSignature.substring(2)
    const r = '0x' + signature.substring(0, 64)
    const s = '0x' + signature.substring(64, 128)
    const v = parseInt(signature.substring(128, 130), 16)
  })

  it('throw block number is too high error', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    await expect(mine.getPriorVotes(other.address, 1111111111111)).to.be.revertedWithCustomError(
      mine,
      'BlockNumberTooHigh',
    )
  })
})
