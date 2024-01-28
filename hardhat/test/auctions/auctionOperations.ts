import { setNextBlockTimestamp } from '@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time'
import { getLatestBlock } from '../utils'
import { type MineAuction } from '../../build/types'
import { type HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { DEFAULT_AUCTION_INTERVAL, DEFAULT_SETTLE_TIME } from '../fixtures/deployMineAuctionFixture'

export async function simulateAnAuction(
  auction: MineAuction,
  owner: HardhatEthersSigner,
  other: HardhatEthersSigner,
  startTime?: bigint
) {
  if (startTime) {
    const block = await getLatestBlock(owner)
    startTime = BigInt(block.timestamp) + 1n
    await setNextBlockTimestamp(startTime)
    await auction.setAuctionGroup(startTime, DEFAULT_SETTLE_TIME, DEFAULT_AUCTION_INTERVAL)
  }

  const block = await getLatestBlock(owner)
  const [groupId, auctionId] = await getBiddingAuctionIdAt(BigInt(block.timestamp), auction)
  await auction.bid(groupId, auctionId, 100)
  await auction.connect(other).bid(groupId, auctionId, 101)
  return [groupId, auctionId]
}

export async function simulateAnContinuousAuction(
  auction: MineAuction,
  owner: HardhatEthersSigner,
  other: HardhatEthersSigner
) {
  const block = await getLatestBlock(owner)
  const newStartTime = BigInt(block.timestamp) + 1n
  await simulateAnAuction(auction, owner, other, newStartTime)
}

export async function getAuctionIdsAt(
  timestamp: bigint,
  auction: MineAuction,
  groupId?: bigint
): Promise<[bigint, bigint]> {
  if (groupId === 0n) {
    throw new Error('given timestamp is before first auction start time OR gourpId is zero')
  }
  groupId = groupId ?? (await auction.currentAuctionGroupId())
  const [startTime, , interval] = await auction.getAuctionGroup(groupId.toString())
  if (timestamp < startTime) {
    return await getAuctionIdsAt(timestamp, auction, groupId - 1n)
  }
  const auctionId = (timestamp - startTime) / interval
  return [groupId, auctionId]
}

export async function getBiddingAuctionIdAt(timestamp: bigint, auction: MineAuction) {
  const [auctionGroupId, startTime, settleTime, bidTime] = await auction.getCurrentAuctionGroup()
  const interval = settleTime + bidTime
  if (timestamp < startTime) {
    throw new Error('given timestamp is before first auction start time')
  }
  const auctionId = (timestamp - startTime) / interval
  const elapsed = (timestamp - startTime) % interval
  if (elapsed > interval - settleTime) {
    throw new Error(`given timestamp is in settlement of auction ${auctionId}`)
  }
  return [auctionGroupId, auctionId]
}

export async function getBiddingAuctionIdAtLatestBlock(auction: MineAuction, owner: HardhatEthersSigner) {
  const block = await getLatestBlock(owner)
  return await getBiddingAuctionIdAt(BigInt(block.timestamp), auction)
}

export async function setNextBlockTimestampToSettlement(auction: MineAuction, owner: HardhatEthersSigner) {
  const block = await getLatestBlock(owner)
  const [, startTime, settleTime, bidTime] = await auction.getCurrentAuctionGroup()
  const interval = bidTime + settleTime
  const auctionId = (BigInt(block.timestamp) - startTime) / interval
  const nextBlockTimestamp = auctionId * interval + interval - settleTime
  await setNextBlockTimestamp(nextBlockTimestamp)
  return nextBlockTimestamp
}
