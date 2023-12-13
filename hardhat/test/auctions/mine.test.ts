import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { DEFAULT_AUCTION_INTERVAL, DEFAULT_SETTLE_TIME, mineAuctionFixture } from '../fixtures/deployMineAuctionFixture'
import { expect } from 'chai'
import { getEvents, getLatestBlock } from '../utils'
import { type MineAuction } from '../../build/types'
import { increase, setNextBlockTimestamp } from '@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time'
import { type HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'

describe('Mine Auctions', () => {
  describe('Before auction start', () => {
    let auction: MineAuction
    let owner: HardhatEthersSigner

    beforeEach(async () => {
      const { auction: _auction, owner: _owner } = await loadFixture(mineAuctionFixture)
      auction = _auction
      owner = _owner
      const block = await getLatestBlock(owner)
      await auction.setAuctionStartTime(block.timestamp + DEFAULT_AUCTION_INTERVAL + 10)
    })

    it('reverts when bid', async () => {
      await expect(auction.bid(100)).to.be.revertedWithCustomError(auction, 'AuctionNotStarted')
      await increase(5 * 60)
      await expect(auction.bid(100)).to.be.revertedWithCustomError(auction, 'AuctionNotStarted')
    })

    it('allows to change auction start time', async () => {
      const block = await getLatestBlock(owner)
      const newStartTime = BigInt(block.timestamp) + 1n
      await setNextBlockTimestamp(newStartTime)

      await auction.setAuctionStartTime(newStartTime)
      expect(await auction.auctionStartTime()).to.equal(newStartTime)
      await increase(10n)
      await expect(auction.bid(100)).to.be.emit(auction, 'AuctionStarted')
    })
  })

  describe('Auction started and before settlement', () => {
    it('can bid', async () => {
      const { auction, owner } = await loadFixture(mineAuctionFixture)
      const tx = await auction.bid(100)
      const events = await getEvents('AuctionStarted', tx)
      await expect(tx)
        .to.emit(auction, 'AuctionStarted')
        .withArgs(0, events[0].args[1], DEFAULT_SETTLE_TIME, DEFAULT_AUCTION_INTERVAL)
        .to.emit(auction, 'AuctionBid')
        .withArgs(0, owner.address, 100n)
      {
        const [totalBidAmount, targetAmount] = await auction.getAuction(0)
        expect(totalBidAmount).to.equal(100n)
        expect(targetAmount).to.equal(100n)
      }

      await increase(5 * 60)

      const tx2 = await auction.bid(101)
      await expect(tx2)
        .to.emit(auction, 'AuctionBid')
        .withArgs(0, owner.address, 101n)
        .to.not.emit(auction, 'AuctionStarted')
      {
        const [totalBidAmount, targetAmount] = await auction.getAuction(0)
        expect(totalBidAmount).to.equal(100n + 101n)
        expect(targetAmount).to.equal(100n)
      }
    })
  })
  describe('In settlement and before auction ends', () => {})
  describe('Auction ended', () => {})
})
