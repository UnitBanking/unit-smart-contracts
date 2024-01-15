import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import {
  DEFAULT_BID_TIME,
  DEFAULT_AUCTION_INTERVAL,
  DEFAULT_SETTLE_TIME,
  mineAuctionFixture,
} from '../fixtures/deployMineAuctionFixture'
import { expect } from 'chai'
import { getLatestBlock } from '../utils'
import { type MineToken, type IERC20, type MineAuction } from '../../build/types'
import { increase, setNextBlockTimestamp } from '@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time'
import { type HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import {
  getBiddingAuctionIdAt,
  getBiddingAuctionIdAtLatestBlock,
  setNextBlockTimestampToSettlement,
  simulateAnAuction,
} from './auctionOperations'
import { ethers } from 'hardhat'

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
      await setNextBlockTimestampToSettlement(auction, owner)
      await auction.setAuctionGroup(block.timestamp + DEFAULT_BID_TIME + 10, DEFAULT_SETTLE_TIME, DEFAULT_BID_TIME)
    })

    it('reverts when bid', async () => {
      const auctionId = 0
      await expect(auction.bid(auctionId, 100)).to.be.revertedWithCustomError(auction, 'AuctionNotCurrentAuctionId')
      await increase(5 * 60)
      await expect(auction.bid(auctionId, 100)).to.be.revertedWithCustomError(auction, 'AuctionNotCurrentAuctionId')
    })

    it('allows to change auction group settings', async () => {
      await ethers.provider.send('evm_mine')
      const block = await getLatestBlock(owner)
      const newStartTime = BigInt(block.timestamp) + 100n

      const newBidTime = 2 * 60 * 60
      const newSettle = 60 * 30

      await expect(auction.setAuctionGroup(newStartTime, newSettle, newBidTime))
        .to.emit(auction, 'AuctionGroupSet')
        .withArgs(2, newStartTime, newSettle, newBidTime)
      const [startTime, settleTime, bidTime] = await auction.getAuctionGroup(
        (await auction.getAuctionGroupCount()) - 1n
      )
      expect(startTime).to.equal(newStartTime)
      expect(settleTime).to.equal(newSettle)
      expect(bidTime).to.equal(newBidTime)
    })
  })

  describe('Auction started and before settlement', () => {
    let auctionStartTime: bigint
    let auctionId: bigint
    beforeEach(async () => {
      const block = await getLatestBlock(owner)
      const currentAuctionId = await getBiddingAuctionIdAt(BigInt(block.timestamp), auction)
      auctionId = currentAuctionId + 1n
      const [startTime, settleTime, bidTime] = await auction.getCurrentAuctionGroup()
      auctionStartTime = startTime + auctionId * (settleTime + bidTime)
      await setNextBlockTimestamp(auctionStartTime)
      await ethers.provider.send('evm_mine')
    })

    it('can bid', async () => {
      const tx = await auction.bid(auctionId, 101)
      await expect(tx).to.emit(auction, 'AuctionBid').withArgs(0, auctionId, owner.address, 101n)
      const [totalBidAmount, rewardAmount] = await auction.getAuction(0, auctionId)
      expect(totalBidAmount).to.equal(101n)
      expect(rewardAmount).to.be.greaterThan(0n)
      expect(await token.balanceOf(await auction.bondingCurve())).to.equal(101n)
    })

    it('reverts when config auction', async () => {
      const newInterval = 2 * 60 * 60
      const newSettle = 60 * 30
      await expect(auction.setAuctionGroup(auctionStartTime, newSettle, newInterval)).to.be.revertedWithCustomError(
        auction,
        'AuctionBiddingInProgress'
      )
    })

    it('reverts if auction is not approved for bid token', async () => {
      await token.approve(await auction.getAddress(), 0)
      await expect(auction.bid(auctionId, 100)).to.be.reverted
    })
  })
  describe('In settlement and before auction ends', () => {})
  describe('Auction ended', () => {})
  describe('Auction view valid check', () => {
    it('reverts when groupId is too large', async () => {
      const [groupId, auctionId] = await simulateAnAuction(auction, owner, other)
      await increase(DEFAULT_BID_TIME + DEFAULT_SETTLE_TIME)
      await expect(auction.getAuction(groupId + 1n, auctionId)).to.be.revertedWithCustomError(
        auction,
        'AuctionAuctionGroupIdTooLarge'
      )
      await expect(auction.getAuctionGroup(groupId + 1n)).to.be.revertedWithCustomError(
        auction,
        'AuctionAuctionGroupIdTooLarge'
      )
      await expect(auction.getClaimed(groupId + 1n, auctionId, owner.address)).to.be.revertedWithCustomError(
        auction,
        'AuctionAuctionGroupIdTooLarge'
      )
      await expect(auction.getBid(groupId + 1n, auctionId, owner.address)).to.be.revertedWithCustomError(
        auction,
        'AuctionAuctionGroupIdTooLarge'
      )
    })
    it('reverts when auctionId is too large', async () => {
      const [groupId, auctionId] = await simulateAnAuction(auction, owner, other)
      await expect(auction.getAuction(groupId, auctionId + 1n)).to.be.revertedWithCustomError(
        auction,
        'AuctionAuctionIdTooLarge'
      )
      await expect(auction.getClaimed(groupId, auctionId + 1n, owner.address)).to.be.revertedWithCustomError(
        auction,
        'AuctionAuctionIdTooLarge'
      )
      await expect(auction.getBid(groupId, auctionId + 1n, owner.address)).to.be.revertedWithCustomError(
        auction,
        'AuctionAuctionIdTooLarge'
      )
    })
  })
  describe('At any time', () => {
    it('reverts when bid amount is zero', async () => {})
    it('revert when claim amount is too large', async () => {
      const [groupId, auctionId] = await simulateAnAuction(auction, owner, other)
      await increase(DEFAULT_AUCTION_INTERVAL)
      await expect(auction.claim(groupId, auctionId, ethers.MaxUint256)).to.be.revertedWithCustomError(
        auction,
        'AuctionInvalidClaimAmount'
      )
    })
    it('allows to claim', async () => {
      const [groupId, auctionId] = await simulateAnAuction(auction, owner, other)
      await increase(DEFAULT_AUCTION_INTERVAL)

      const balanceBeforeOwner = await mine.balanceOf(owner.address)
      const balanceBeforeOther = await mine.balanceOf(other.address)
      await expect(auction.claim(groupId, auctionId, 100))
        .to.emit(auction, 'AuctionClaimed')
        .withArgs(groupId, auctionId, owner.address, 100n)
      await expect(auction.connect(other).claim(groupId, auctionId, 101))
        .to.emit(auction, 'AuctionClaimed')
        .withArgs(groupId, auctionId, other.address, 101n)

      const balanceAfterOwner = await mine.balanceOf(owner.address)
      const balanceAfterOther = await mine.balanceOf(other.address)
      expect(balanceAfterOwner - balanceBeforeOwner).to.equal(100n)
      expect(balanceAfterOther - balanceBeforeOther).to.equal(101n)
    })

    it('allows to partial claim', async () => {})
  })

  it('can bid when auction is skipped', async () => {})

  it('can bid in continuous auctions', async () => {
    const groupId = await auction.currentAuctionGroupId()
    const auctionId0 = await getBiddingAuctionIdAtLatestBlock(auction, owner)
    await expect(auction.bid(auctionId0, 100))
      .to.emit(auction, 'AuctionBid')
      .withArgs(groupId, auctionId0, owner.address, 100n)
    await expect(auction.connect(other).bid(auctionId0, 101))
      .to.emit(auction, 'AuctionBid')
      .withArgs(groupId, auctionId0, other.address, 101n)
    await increase(DEFAULT_AUCTION_INTERVAL * 2 + 1)
    const auctionId1 = await getBiddingAuctionIdAtLatestBlock(auction, owner)
    await expect(auction.bid(auctionId1, 100))
      .to.emit(auction, 'AuctionBid')
      .withArgs(groupId, auctionId1, owner.address, 100n)
    await expect(auction.connect(other).bid(auctionId1, 101))
      .to.emit(auction, 'AuctionBid')
      .withArgs(groupId, auctionId1, other.address, 101n)
  })

  it('set new auction group between auctions', async () => {
    const groupId0 = await auction.currentAuctionGroupId()
    const auctionId0 = await getBiddingAuctionIdAtLatestBlock(auction, owner)
    await expect(auction.bid(auctionId0, 100))
      .to.emit(auction, 'AuctionBid')
      .withArgs(groupId0, auctionId0, owner.address, 100n)
    await expect(auction.connect(other).bid(auctionId0, 101))
      .to.emit(auction, 'AuctionBid')
      .withArgs(groupId0, auctionId0, other.address, 101n)

    // be able to set start time
    await setNextBlockTimestampToSettlement(auction, owner)
    const [startTime, ,] = await auction.getCurrentAuctionGroup()
    const newStartTime = startTime + BigInt(DEFAULT_AUCTION_INTERVAL) * (auctionId0 + 2n)
    await auction.setAuctionGroup(newStartTime, DEFAULT_SETTLE_TIME, DEFAULT_BID_TIME)
    await expect(auction.bid(0, 1)).to.be.revertedWithCustomError(auction, 'AuctionNotCurrentAuctionId')
    // increase to new start time left boundary
    await setNextBlockTimestamp(newStartTime)
    await ethers.provider.send('evm_mine')

    // console.log(new Date(Number(newStartTime) * 1000))

    const groupId2 = await auction.currentAuctionGroupId()
    expect(groupId2).to.equal(1)
    const auctionId1 = await getBiddingAuctionIdAt(newStartTime, auction)
    await expect(auction.bid(auctionId1, 100))
      .to.emit(auction, 'AuctionBid')
      .withArgs(groupId2, auctionId1, owner.address, 100n)
    await expect(auction.connect(other).bid(auctionId1, 101))
      .to.emit(auction, 'AuctionBid')
      .withArgs(groupId2, auctionId1, other.address, 101n)
    await expect(auction.connect(another).bid(auctionId1, 101))
      .to.emit(auction, 'AuctionBid')
      .withArgs(groupId2, auctionId1, another.address, 101n)
  })
})
