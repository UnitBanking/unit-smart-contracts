import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import {
  DEFAULT_AUCTION_INTERVAL,
  DEFAULT_SETTLE_TIME,
  mineAuctionFixture,
  mineAuctionWithoutInitializationFixture,
} from '../fixtures/deployMineAuctionFixture'
import { expect } from 'chai'
import { getEvents, getLatestBlock } from '../utils'
import { type MineAuction } from '../../build/types'
import { increase } from '@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time'

describe('Mine Auctions', () => {
  describe('Current time is before auction start time', () => {
    let auction: MineAuction

    beforeEach(async () => {
      const { auction: _auction, owner } = await loadFixture(mineAuctionWithoutInitializationFixture)
      auction = _auction
      const block = await getLatestBlock(owner)
      await auction.setAuctionStartTime(block.timestamp + 1 * 60 * 60)
    })

    it('reverts when bid', async () => {
      await expect(auction.bid(100)).to.be.revertedWithCustomError(auction, 'AuctionNotStarted')
      await increase(5 * 60)
      await expect(auction.bid(100)).to.be.revertedWithCustomError(auction, 'AuctionNotStarted')
    })
  })

  describe('Current time is after auction start time and before auction settle time', () => {
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
  describe('Current time is after auction settle time and before auction end time', () => {})
  describe('Current time is after auction end time', () => {})
})
