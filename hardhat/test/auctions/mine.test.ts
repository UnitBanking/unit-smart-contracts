import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { DEFAULT_AUCTION_INTERVAL, DEFAULT_SETTLE_TIME, mineAuctionFixture } from '../fixtures/deployMineAuctionFixture'
import { expect } from 'chai'
import { getEvents, getLatestBlock } from '../utils'
import { type MineToken, type IERC20, type MineAuction } from '../../build/types'
import { increase, setNextBlockTimestamp } from '@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time'
import { type HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { simulateAnAuction } from './auctionOperations'

describe('Mine Auctions', () => {
  let auction: MineAuction
  let owner: HardhatEthersSigner
  let other: HardhatEthersSigner
  let another: HardhatEthersSigner
  let token: IERC20
  let mine: MineToken
  beforeEach(async () => {
    const fixtures = await loadFixture(mineAuctionFixture)
    auction = fixtures.auction
    owner = fixtures.owner
    token = fixtures.token
    mine = fixtures.mine
    other = fixtures.other
    another = fixtures.another
  })

  describe('Before auction start', () => {
    beforeEach(async () => {
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
    })

    it('allows to change auction interval', async () => {
      const newInterval = 2 * 60 * 60
      await expect(auction.setAuctionInterval(newInterval)).to.emit(auction, 'AuctionIntervalSet').withArgs(newInterval)
      expect(await auction.auctionInterval()).to.equal(newInterval)
    })

    it('allows to change auction settle time', async () => {
      const settle = 60 * 30
      await expect(auction.setAuctionSettleTime(settle)).to.emit(auction, 'AuctionSettleTimeSet').withArgs(settle)
      expect(await auction.auctionSettleTime()).to.equal(settle)
    })
  })

  describe('Auction started and before settlement', () => {
    beforeEach(async () => {
      const tx = await auction.bid(100)
      const events = await getEvents('AuctionStarted', tx)
      await expect(tx)
        .to.emit(auction, 'AuctionStarted')
        .withArgs(0, events[0].args[1], DEFAULT_SETTLE_TIME, DEFAULT_AUCTION_INTERVAL)
        .to.emit(auction, 'AuctionBid')
        .withArgs(0, owner.address, 100n)
      const [totalBidAmount, rewardAmount] = await auction.getAuction(0)
      expect(totalBidAmount).to.equal(100n)
      expect(rewardAmount).to.be.greaterThan(0n)
    })

    it('can bid', async () => {
      await increase(5 * 60)

      const tx = await auction.bid(101)
      await expect(tx)
        .to.emit(auction, 'AuctionBid')
        .withArgs(0, owner.address, 101n)
        .to.not.emit(auction, 'AuctionStarted')
      const [totalBidAmount, rewardAmount] = await auction.getAuction(0)
      expect(totalBidAmount).to.equal(100n + 101n)
      expect(rewardAmount).to.be.greaterThan(0n)
      expect(await token.balanceOf(await auction.bondingCurve())).to.equal(100n + 101n)
    })

    it('reverts when config auction', async () => {
      const block = await getLatestBlock(owner)
      await expect(auction.setAuctionStartTime(block.timestamp)).to.be.revertedWithCustomError(
        auction,
        'AuctionBiddingInProgress'
      )
      await expect(auction.setAuctionInterval(60)).to.be.revertedWithCustomError(auction, 'AuctionBiddingInProgress')
      await expect(auction.setAuctionSettleTime(30)).to.be.revertedWithCustomError(auction, 'AuctionBiddingInProgress')
    })

    it('reverts if auction is not approved for bid token', async () => {
      await token.approve(await auction.getAddress(), 0)
      await expect(auction.bid(100)).to.be.revertedWithCustomError(token, 'ERC20InsufficientAllowance')
    })
  })
  describe('In settlement and before auction ends', () => {})
  describe('Auction ended', () => {})
  describe('At any time', () => {
    it('reverts when bid amount is zero', async () => {})
    it('allows to claim', async () => {
      await simulateAnAuction(auction, owner, other)
      await increase(DEFAULT_AUCTION_INTERVAL)

      const balanceBeforeOwner = await mine.balanceOf(owner.address)
      const balanceBeforeOther = await mine.balanceOf(other.address)
      await expect(auction.claim(0, 100)).to.emit(auction, 'AuctionClaimed').withArgs(0, owner.address, 100n)
      await expect(auction.connect(other).claim(0, 101))
        .to.emit(auction, 'AuctionClaimed')
        .withArgs(0, other.address, 101n)

      const balanceAfterOwner = await mine.balanceOf(owner.address)
      const balanceAfterOther = await mine.balanceOf(other.address)
      expect(balanceAfterOwner - balanceBeforeOwner).to.equal(100n)
      expect(balanceAfterOther - balanceBeforeOther).to.equal(101n)
    })

    it('allows to partial claim', async () => {})
  })

  it('can bid when auction is skipped', async () => {})

  it('can bid in continuous auctions', async () => {
    await expect(auction.bid(100))
      .to.emit(auction, 'AuctionStarted')
      .to.emit(auction, 'AuctionBid')
      .withArgs(0, owner.address, 100n)
    await expect(auction.connect(other).bid(101))
      .to.emit(auction, 'AuctionBid')
      .withArgs(0, other.address, 101n)
      .to.not.emit(auction, 'AuctionStarted')
    await increase(DEFAULT_AUCTION_INTERVAL * 2 + 1)
    await auction.bid(100)
    await expect(auction.connect(other).bid(101)).to.emit(auction, 'AuctionBid').withArgs(1, other.address, 101n)
  })

  it('set start time between auctions', async () => {
    await expect(auction.bid(100))
      .to.emit(auction, 'AuctionBid')
      .withArgs(0, owner.address, 100n)
      .to.emit(auction, 'AuctionStarted')
    await expect(auction.connect(other).bid(101))
      .to.emit(auction, 'AuctionBid')
      .withArgs(0, other.address, 101n)
      .to.not.emit(auction, 'AuctionStarted')
    // be able to set start time
    await increase(DEFAULT_AUCTION_INTERVAL)

    const startTime = await auction.auctionStartTime()
    const newStartTime = startTime + BigInt(DEFAULT_AUCTION_INTERVAL * 2) + 1n
    await auction.setAuctionStartTime(newStartTime)
    await expect(auction.bid(1)).to.be.revertedWithCustomError(auction, 'AuctionNotStarted')
    // increase to new start time left boundary
    await setNextBlockTimestamp(newStartTime)

    await expect(auction.bid(100))
      .to.emit(auction, 'AuctionBid')
      .withArgs(1, owner.address, 100n)
      .to.emit(auction, 'AuctionStarted')
    await expect(auction.connect(other).bid(101))
      .to.emit(auction, 'AuctionBid')
      .withArgs(1, other.address, 101n)
      .to.not.emit(auction, 'AuctionStarted')
    await expect(auction.connect(another).bid(101))
      .to.emit(auction, 'AuctionBid')
      .withArgs(1, another.address, 101n)
      .to.not.emit(auction, 'AuctionStarted')
  })
})
