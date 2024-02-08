import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import {
  DEFAULT_BID_DURATION,
  DEFAULT_AUCTION_DURATION,
  DEFAULT_SETTLE_DURATION,
  mineAuctionFixture,
} from '../fixtures/deployMineAuctionFixture'
import { expect } from 'chai'
import { type MineToken, type IERC20, type MineAuction } from '../../build/types'
import { increase, setNextBlockTimestamp } from '@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time'
import { type HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import {
  getBiddingAuctionIdAtLatestBlock,
  setNextBlockTimestampToSettlement,
  simulateAnAuction,
} from './auctionOperations'
import { ethers } from 'hardhat'

describe('Mine Auctions', () => {
  let auction: MineAuction
  let owner: HardhatEthersSigner
  let other: HardhatEthersSigner
  let token: IERC20
  let mine: MineToken
  beforeEach(async () => {
    const fixtures = await loadFixture(mineAuctionFixture)
    auction = fixtures.auction
    owner = fixtures.owner
    token = fixtures.token
    mine = fixtures.mine
    other = fixtures.other
  })

  describe('Before initial auction starts', () => {
    it('reverts when bid', async () => {
      const [groupId] = await auction.getCurrentAuctionGroup()
      const auctionId = 1n
      await expect(auction.bid(groupId, auctionId, 100)).to.be.revertedWithCustomError(
        auction,
        'MineAuctionNotCurrentAuctionGroupId'
      )
      await increase(5 * 60)
      await expect(auction.bid(groupId, auctionId, 100)).to.be.revertedWithCustomError(
        auction,
        'MineAuctionNotCurrentAuctionGroupId'
      )
    })

    it('allows to set/append auction group', async () => {
      const [startTime, , bidDuration] = await auction.getAuctionGroup(0)
      const expectedStartTime = startTime + bidDuration
      const expectedBidDuration = 2 * 60 * 60
      const expectedSettleDuration = 60 * 30

      await expect(auction.setAuctionGroup(expectedStartTime, expectedSettleDuration, expectedBidDuration))
        .to.emit(auction, 'AuctionGroupSet')
        .withArgs(1, expectedStartTime, expectedSettleDuration, expectedBidDuration)
      const lastGroupId = (await auction.getAuctionGroupCount()) - 1n
      const [actualStartTime, actualSettleDuration, actualBidDuration] = await auction.getAuctionGroup(lastGroupId)
      expect(actualStartTime).to.equal(expectedStartTime)
      expect(actualSettleDuration).to.equal(expectedSettleDuration)
      expect(actualBidDuration).to.equal(expectedBidDuration)
    })

    it('reverts when new start time is too close - less than one bid duration', async () => {
      const [startTime, , bidDuration] = await auction.getAuctionGroup(0)
      const incorrectStartTime = startTime + bidDuration - 1n

      const tx = auction.setAuctionGroup(incorrectStartTime, 300, 300)
      await expect(tx).to.revertedWithCustomError(auction, 'MineAuctionStartTimeTooEarly')
    })
  })

  describe('Auction in bidding phase', () => {
    let auctionStartTime: bigint
    let auctionGroupId: bigint
    let auctionId: bigint
    beforeEach(async () => {
      const [currentAuctionGroupId, startTime] = await auction.getCurrentAuctionGroup()
      auctionStartTime = startTime
      auctionGroupId = currentAuctionGroupId
      auctionId = 0n
      await setNextBlockTimestamp(startTime)
    })

    it('can bid', async () => {
      const tx = await auction.bid(auctionGroupId, auctionId, 101)
      await expect(tx).to.emit(auction, 'AuctionBid').withArgs(0, auctionId, owner.address, 101n)
      const [totalBidAmount, rewardAmount] = await auction.getAuction(0, auctionId)
      expect(totalBidAmount).to.equal(101n)
      expect(rewardAmount).to.be.greaterThan(0n)
      expect(await token.balanceOf(await auction.bondingCurve())).to.equal(101n)
    })

    it('allows to set/append auction group', async () => {
      const [, , , bidDuration] = await auction.getCurrentAuctionGroup()
      const expectedStartTime = auctionStartTime + bidDuration
      const expectedBidDuration = 2 * 60 * 60
      const expectedSettleDuration = 60 * 30

      await expect(auction.setAuctionGroup(expectedStartTime, expectedSettleDuration, expectedBidDuration))
        .to.emit(auction, 'AuctionGroupSet')
        .withArgs(1, expectedStartTime, expectedSettleDuration, expectedBidDuration)
      const lastGroupId = (await auction.getAuctionGroupCount()) - 1n
      const [actualStartTime, actualSettleDuration, actualBidDuration] = await auction.getAuctionGroup(lastGroupId)
      expect(actualStartTime).to.equal(expectedStartTime)
      expect(actualSettleDuration).to.equal(expectedSettleDuration)
      expect(actualBidDuration).to.equal(expectedBidDuration)
    })

    it('reverts if auction is not approved for bid token', async () => {
      await token.approve(await auction.getAddress(), 0)
      await expect(auction.bid(auctionGroupId, auctionId, 100)).to.be.reverted
    })

    it('revert if bid in the gap of two auction group', async () => {
      const [, , settleDuration, bidDuration] = await auction.getCurrentAuctionGroup()
      // explicitly create auctionGroupGap of 10n secs
      const expectedStartTime = auctionStartTime + bidDuration + settleDuration + 10n
      const expectedBidDuration = 2 * 60 * 60
      const expectedSettleDuration = 60 * 30
      await expect(auction.setAuctionGroup(expectedStartTime, expectedSettleDuration, expectedBidDuration))
        .to.emit(auction, 'AuctionGroupSet')
        .withArgs(1, expectedStartTime, expectedSettleDuration, expectedBidDuration)

      await setNextBlockTimestamp(expectedStartTime - 5n)
      await expect(auction.bid(auctionGroupId, auctionId, 100)).to.be.revertedWithCustomError(
        auction,
        'MineAuctionCurrentAuctionDisabled'
      )
    })

    it('revert if invalid bid amount', async () => {
      await expect(auction.bid(auctionGroupId, auctionId, 0)).to.be.revertedWithCustomError(
        auction,
        'MineAuctionInvalidBidAmount'
      )
    })

    it('can bid when there are skipped auctions', async () => {
      const [groupId0, auctionId0] = [auctionGroupId, auctionId]
      await expect(auction.bid(groupId0, auctionId0, 100))
        .to.emit(auction, 'AuctionBid')
        .withArgs(groupId0, auctionId0, owner.address, 100n)
      await expect(auction.connect(other).bid(groupId0, auctionId0, 101))
        .to.emit(auction, 'AuctionBid')
        .withArgs(groupId0, auctionId0, other.address, 101n)
      const [, , settleDuration, bidDuration] = await auction.getCurrentAuctionGroup()
      await increase((settleDuration + bidDuration) * 2n + 1n)
      const [groupId1, auctionId1] = await getBiddingAuctionIdAtLatestBlock(auction, owner)
      await expect(auction.bid(groupId1, auctionId1, 100))
        .to.emit(auction, 'AuctionBid')
        .withArgs(groupId1, auctionId1, owner.address, 100n)
      await expect(auction.connect(other).bid(groupId1, auctionId1, 101))
        .to.emit(auction, 'AuctionBid')
        .withArgs(groupId1, auctionId1, other.address, 101n)
    })
  })

  describe('Auction in settlement phase', () => {
    let auctionGroupId: bigint
    let auctionId: bigint
    beforeEach(async () => {
      const [currentAuctionGroupId, startTime, , bidDuration] = await auction.getCurrentAuctionGroup()
      auctionGroupId = currentAuctionGroupId
      auctionId = 0n
      await setNextBlockTimestamp(startTime + bidDuration)
    })

    it('reverts when bid', async () => {
      await expect(auction.bid(auctionGroupId, auctionId, 100)).to.be.revertedWithCustomError(
        auction,
        'MineAuctionNotCurrentAuctionId'
      )
    })
  })

  describe('Auction view valid check', () => {
    it('reverts when groupId is too large', async () => {
      const [groupId, auctionId] = await simulateAnAuction(auction, owner, other)
      const nextBlockTimestamp = await setNextBlockTimestampToSettlement(auction, owner)
      // const [, , settleTime, bidTime] = await auction.getCurrentAuctionGroup()
      // const newStartTime = nextBlockTimestamp + (settleTime + bidTime) * 2n + 10n
      const newStartTime = nextBlockTimestamp + 60n * 30n
      await auction.setAuctionGroup(newStartTime, DEFAULT_SETTLE_DURATION, DEFAULT_BID_DURATION)
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

    it('get auction info', async () => {
      const [groupId, auctionId] = await simulateAnAuction(auction, owner, other)
      const [
        totalBidAmount,
        rewardAmount,
        startTime,
        settleDuration,
        bidDuration,
        bidAmount,
        claimedAmount,
        claimableAmount,
      ] = await auction.getAuctionInfo(groupId, auctionId, owner.address)
      expect(totalBidAmount).to.equal(201n)
      expect(rewardAmount).to.be.greaterThan(0n)
      expect(startTime).to.be.greaterThan(0n)
      expect(settleDuration).to.be.greaterThan(0n)
      expect(bidDuration).to.be.greaterThan(0n)
      expect(bidAmount).to.equal(100n)
      expect(claimedAmount).to.equal(0n)
      expect(claimableAmount).to.greaterThan(0n)
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
    it('reverts when claim amount is too large', async () => {
      const [groupId, auctionId] = await simulateAnAuction(auction, owner, other)
      await increase(DEFAULT_AUCTION_DURATION)
      await expect(auction.claim(groupId, auctionId, ethers.MaxUint256)).to.be.revertedWithCustomError(
        auction,
        'MineAuctionInsufficientClaimAmount'
      )
    })
    it('allows to claim', async () => {
      const [groupId, auctionId] = await simulateAnAuction(auction, owner, other)
      await increase(DEFAULT_AUCTION_DURATION)

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

    it('claim to other address', async () => {
      const [groupId, auctionId] = await simulateAnAuction(auction, owner, other)
      await increase(DEFAULT_AUCTION_DURATION)

      const balanceBeforeOwner = await mine.balanceOf(owner.address)
      const balanceBeforeOther = await mine.balanceOf(other.address)
      await expect(auction.claimTo(groupId, auctionId, other.address, 100))
        .to.emit(auction, 'AuctionClaimed')
        .withArgs(groupId, auctionId, owner.address, 100n)

      const balanceAfterOwner = await mine.balanceOf(owner.address)
      const balanceAfterOther = await mine.balanceOf(other.address)
      expect(balanceAfterOwner).to.equal(balanceBeforeOwner)
      expect(balanceAfterOther - balanceBeforeOther).to.equal(100n)
    })
  })
})
