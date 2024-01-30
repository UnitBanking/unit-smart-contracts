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
import {
  increase,
  increaseTo,
  setNextBlockTimestamp,
} from '@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time'
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
      const nextBlockTimestamp = await setNextBlockTimestampToSettlement(auction, owner)
      await auction.setAuctionGroup(nextBlockTimestamp, DEFAULT_SETTLE_TIME, DEFAULT_BID_TIME)
    })

    it('reverts when bid', async () => {
      const groupId = await auction.currentAuctionGroupId()
      const auctionId = 1n
      await expect(auction.bid(groupId, auctionId, 100)).to.be.revertedWithCustomError(
        auction,
        'MineAuctionNotCurrentAuctionId'
      )
      await increase(5 * 60)
      await expect(auction.bid(groupId, auctionId, 100)).to.be.revertedWithCustomError(
        auction,
        'MineAuctionNotCurrentAuctionId'
      )
    })

    it('allows to change auction group settings', async () => {
      let block = await getLatestBlock(owner)
      await setNextBlockTimestamp(block.timestamp + DEFAULT_BID_TIME)
      await ethers.provider.send('evm_mine')
      block = await getLatestBlock(owner)
      const newStartTime = BigInt(block.timestamp) + 10n

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

  describe('Auction in bidding phase', () => {
    let auctionStartTime: bigint
    let auctionGroupId: bigint
    let auctionId: bigint
    beforeEach(async () => {
      const block = await getLatestBlock(owner)
      const [currentAuctionGroupId, currentAuctionId] = await getBiddingAuctionIdAt(BigInt(block.timestamp), auction)
      auctionGroupId = currentAuctionGroupId
      auctionId = currentAuctionId + 1n
      const [, startTime, settleTime, bidTime] = await auction.getCurrentAuctionGroup()
      auctionStartTime = startTime + auctionId * (settleTime + bidTime)
      await setNextBlockTimestamp(auctionStartTime)
    })

    it('can bid', async () => {
      const tx = await auction.bid(auctionGroupId, auctionId, 101)
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
        'MineAuctionBiddingInProgress'
      )
    })

    it('reverts if auction is not approved for bid token', async () => {
      await token.approve(await auction.getAddress(), 0)
      await expect(auction.bid(auctionGroupId, auctionId, 100)).to.be.reverted
    })
  })
  describe('In settlement and before auction ends', () => {})
  describe('Auction ended', () => {})
  describe('Auction view valid check', () => {
    it('reverts when groupId is too large', async () => {
      const [groupId, auctionId] = await simulateAnAuction(auction, owner, other)
      const nextBlockTimestamp = await setNextBlockTimestampToSettlement(auction, owner)
      // const [, , settleTime, bidTime] = await auction.getCurrentAuctionGroup()
      // const newStartTime = nextBlockTimestamp + (settleTime + bidTime) * 2n + 10n
      const newStartTime = nextBlockTimestamp + 60n * 30n
      await auction.setAuctionGroup(newStartTime, DEFAULT_SETTLE_TIME, DEFAULT_BID_TIME)
      await expect(auction.getAuction(groupId + 1n, auctionId))
        .to.be.revertedWithCustomError(auction, 'MineAuctionAuctionGroupIdInFuture')
        .withArgs(groupId + 1n)
      await expect(auction.getAuction(groupId + 2n, auctionId))
        .to.be.revertedWithCustomError(auction, 'MineAuctionInvalidAuctionGroupId')
        .withArgs(groupId + 2n)
      await expect(auction.getAuctionGroup(groupId + 2n))
        .to.be.revertedWithCustomError(auction, 'MineAuctionInvalidAuctionGroupId')
        .withArgs(groupId + 2n)
      await expect(auction.getClaimed(groupId + 1n, auctionId, owner.address))
        .to.be.revertedWithCustomError(auction, 'MineAuctionAuctionGroupIdInFuture')
        .withArgs(groupId + 1n)
      await expect(auction.getClaimed(groupId + 2n, auctionId, owner.address))
        .to.be.revertedWithCustomError(auction, 'MineAuctionInvalidAuctionGroupId')
        .withArgs(groupId + 2n)
      await expect(auction.getBid(groupId + 1n, auctionId, owner.address))
        .to.be.revertedWithCustomError(auction, 'MineAuctionAuctionGroupIdInFuture')
        .withArgs(groupId + 1n)
      await expect(auction.getBid(groupId + 2n, auctionId, owner.address))
        .to.be.revertedWithCustomError(auction, 'MineAuctionInvalidAuctionGroupId')
        .withArgs(groupId + 2n)
    })
    it('reverts when auctionId is too large', async () => {
      const [groupId, auctionId] = await simulateAnAuction(auction, owner, other)
      await expect(auction.claim(groupId, auctionId, 10))
        .to.be.revertedWithCustomError(auction, 'MineAuctionAuctionIdInFutureOrCurrent')
        .withArgs(auctionId)
      await expect(auction.getAuction(groupId, auctionId + 1n))
        .to.be.revertedWithCustomError(auction, 'MineAuctionAuctionIdInFuture')
        .withArgs(auctionId + 1n)
      await expect(auction.getClaimed(groupId, auctionId + 1n, owner.address))
        .to.be.revertedWithCustomError(auction, 'MineAuctionAuctionIdInFuture')
        .withArgs(auctionId + 1n)
      await expect(auction.getBid(groupId, auctionId + 1n, owner.address))
        .to.be.revertedWithCustomError(auction, 'MineAuctionAuctionIdInFuture')
        .withArgs(auctionId + 1n)
    })
  })
  describe('At any time', () => {
    it('reverts when bid amount is zero', async () => {})
    it('revert when claim amount is too large', async () => {
      const [groupId, auctionId] = await simulateAnAuction(auction, owner, other)
      await increase(DEFAULT_AUCTION_INTERVAL)
      await expect(auction.claim(groupId, auctionId, ethers.MaxUint256)).to.be.revertedWithCustomError(
        auction,
        'MineAuctionInsufficientClaimAmount'
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
    const [groupId0, auctionId0] = await getBiddingAuctionIdAtLatestBlock(auction, owner)
    await expect(auction.bid(groupId0, auctionId0, 100))
      .to.emit(auction, 'AuctionBid')
      .withArgs(groupId0, auctionId0, owner.address, 100n)
    await expect(auction.connect(other).bid(groupId0, auctionId0, 101))
      .to.emit(auction, 'AuctionBid')
      .withArgs(groupId0, auctionId0, other.address, 101n)
    await increase(DEFAULT_AUCTION_INTERVAL * 2 + 1)
    const [groupId1, auctionId1] = await getBiddingAuctionIdAtLatestBlock(auction, owner)
    await expect(auction.bid(groupId1, auctionId1, 100))
      .to.emit(auction, 'AuctionBid')
      .withArgs(groupId1, auctionId1, owner.address, 100n)
    await expect(auction.connect(other).bid(groupId1, auctionId1, 101))
      .to.emit(auction, 'AuctionBid')
      .withArgs(groupId1, auctionId1, other.address, 101n)
  })

  it('set new auction group between auctions', async () => {
    const [groupId0, auctionId0] = await getBiddingAuctionIdAtLatestBlock(auction, owner)
    await expect(auction.bid(groupId0, auctionId0, 100))
      .to.emit(auction, 'AuctionBid')
      .withArgs(groupId0, auctionId0, owner.address, 100n)
    await expect(auction.connect(other).bid(groupId0, auctionId0, 101))
      .to.emit(auction, 'AuctionBid')
      .withArgs(groupId0, auctionId0, other.address, 101n)

    // be able to set start time
    const nextBlockTimestamp = await setNextBlockTimestampToSettlement(auction, owner)
    const newStartTime = nextBlockTimestamp + 10n
    await auction.setAuctionGroup(newStartTime, DEFAULT_SETTLE_TIME, DEFAULT_BID_TIME)
    expect((await getLatestBlock(owner)).timestamp).to.equal(nextBlockTimestamp)
    await expect(auction.bid(groupId0, auctionId0, 1)).to.be.revertedWithCustomError(auction, 'MineAuctionInSettlement')

    // console.log(new Date(Number(newStartTime) * 1000))

    // increase to new start time left boundary
    await increaseTo(newStartTime)
    const [groupId1, auctionId1] = await getBiddingAuctionIdAt(newStartTime, auction)
    expect(groupId1).to.equal(1)
    await expect(auction.bid(groupId1, auctionId1, 100))
      .to.emit(auction, 'AuctionBid')
      .withArgs(groupId1, auctionId1, owner.address, 100n)
    await expect(auction.connect(other).bid(groupId1, auctionId1, 101))
      .to.emit(auction, 'AuctionBid')
      .withArgs(groupId1, auctionId1, other.address, 101n)
    await expect(auction.connect(another).bid(groupId1, auctionId1, 101))
      .to.emit(auction, 'AuctionBid')
      .withArgs(groupId1, auctionId1, another.address, 101n)
  })
})
