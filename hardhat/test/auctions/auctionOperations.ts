import { setNextBlockTimestamp } from '@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time'
import { getLatestBlock } from '../utils'
import { expect } from 'chai'
import { type MineAuction } from '../../build/types'
import { type HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'

export async function simulateAnAuction(
  auction: MineAuction,
  owner: HardhatEthersSigner,
  other: HardhatEthersSigner,
  startTime?: bigint,
) {
  if (startTime) {
    const block = await getLatestBlock(owner)
    startTime = BigInt(block.timestamp) + 1n
    await setNextBlockTimestamp(startTime)
    await auction.setAuctionStartTime(startTime)
    expect(await auction.auctionStartTime()).to.equal(startTime)
  }

  await expect(auction.bid(100)).to.emit(auction, 'AuctionStarted').to.emit(auction, 'AuctionBid')
  await expect(auction.connect(other).bid(101)).to.emit(auction, 'AuctionBid').to.not.emit(auction, 'AuctionStarted')
}

export async function simulateAnContinuousAuction(
  auction: MineAuction,
  owner: HardhatEthersSigner,
  other: HardhatEthersSigner,
) {
  const block = await getLatestBlock(owner)
  const newStartTime = BigInt(block.timestamp) + 1n
  await simulateAnAuction(auction, owner, other, newStartTime)
}
