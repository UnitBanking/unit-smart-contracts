import { increase, setNextBlockTimestamp } from '@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time'
import { getLatestBlock, getLatestBlockTimestamp } from '../utils'
import { type MineAuction } from '../../build/types'
import { type HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'

export async function increaseToBiddingPhase(auction: MineAuction, owner: HardhatEthersSigner) {
  const [groupId, startTime, settleDuration, bidDuration] = await auction.getCurrentAuctionGroup()
  const blockTimestamp = await getLatestBlockTimestamp(owner)
  let secondsToIncrease: bigint = 0n
  if (blockTimestamp < startTime) {
    secondsToIncrease = startTime - BigInt(blockTimestamp)
  } else {
    const elapsed = (BigInt(blockTimestamp) - startTime) % (bidDuration + settleDuration)
    if (elapsed > bidDuration) {
      const secondsToNextAuction = settleDuration - (elapsed - bidDuration)
      const groupCount = await auction.getAuctionGroupCount()
      const nextGroupStartTime =
        groupCount > groupId + 1n ? (await auction.getAuctionGroup(groupId + 1n))[1] : undefined
      if (nextGroupStartTime && secondsToNextAuction + BigInt(blockTimestamp) > nextGroupStartTime) {
        secondsToIncrease = nextGroupStartTime - BigInt(blockTimestamp)
      } else {
        secondsToIncrease = secondsToNextAuction
      }
    }
  }
  if (secondsToIncrease > 0n) {
    await increase(secondsToIncrease)
  }
}

export async function simulateAnAuction(auction: MineAuction, owner: HardhatEthersSigner, other: HardhatEthersSigner) {
  await increaseToBiddingPhase(auction, owner)
  const block = await getLatestBlock(owner)
  const [groupId, auctionId] = await getBiddingAuctionIdAt(BigInt(block.timestamp), auction)
  await auction.bid(groupId, auctionId, 100)
  await auction.connect(other).bid(groupId, auctionId, 101)
  return [groupId, auctionId]
}

export async function getAuctionIdsAt(
  timestamp: bigint,
  auction: MineAuction,
  groupId?: bigint
): Promise<[bigint, bigint]> {
  if (groupId === 0n) {
    throw new Error('given timestamp is before first auction start time OR gourpId is zero')
  }
  if (!groupId) {
    ;[groupId] = await auction.getCurrentAuctionGroup()
  }
  const [startTime, settleDuration, bidDuration] = await auction.getAuctionGroup(groupId.toString())
  if (timestamp < startTime) {
    return await getAuctionIdsAt(timestamp, auction, groupId - 1n)
  }
  const auctionId = (timestamp - startTime) / (settleDuration + bidDuration)
  return [groupId, auctionId]
}

export async function getBiddingAuctionIdAt(timestamp: bigint, auction: MineAuction) {
  const [auctionGroupId, startTime, settleDuration, bidDuration] = await auction.getCurrentAuctionGroup()
  const interval = settleDuration + bidDuration
  if (timestamp < startTime) {
    throw new Error('given timestamp is before initial auction start time')
  }
  const auctionId = (timestamp - startTime) / interval
  const elapsed = (timestamp - startTime) % interval
  if (elapsed > interval - settleDuration) {
    throw new Error(`given timestamp is in settlement of auction ${auctionId}`)
  }
  return [auctionGroupId, auctionId]
}

export async function getBiddingAuctionIdAtLatestBlock(auction: MineAuction, owner: HardhatEthersSigner) {
  const now = await getLatestBlockTimestamp(owner)
  return await getBiddingAuctionIdAt(BigInt(now), auction)
}

export async function setNextBlockTimestampToSettlement(
  auction: MineAuction,
  owner: HardhatEthersSigner
): Promise<bigint> {
  const blockTimestamp = await getLatestBlockTimestamp(owner)
  const [, startTime, settleDuration, bidDuration] = await auction.getCurrentAuctionGroup()
  const auctionDuration = bidDuration + settleDuration
  const auctionId = (BigInt(blockTimestamp) - startTime) / auctionDuration
  const nextBlockTimestamp = startTime + auctionId * auctionDuration + auctionDuration - settleDuration
  await setNextBlockTimestamp(nextBlockTimestamp)
  return nextBlockTimestamp
}
