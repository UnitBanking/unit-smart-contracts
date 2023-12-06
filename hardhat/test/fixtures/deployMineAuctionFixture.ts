import { ethers } from 'hardhat'
import { type HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { type MineAuction } from '../../build/types'
import { assert } from 'chai'
import { increaseTime } from '../utils/evm'

interface MineAuctionFixtureReturnType {
  auction: MineAuction
  owner: HardhatEthersSigner
  other: HardhatEthersSigner
  another: HardhatEthersSigner
}

export const DEFAULT_SETTLE_TIME = 1 * 60 * 60
export const DEFAULT_AUCTION_INTERVAL = 24 * 60 * 60

export async function deployMineAuctionFixture(): Promise<MineAuctionFixtureReturnType> {
  const [owner, other, another] = await ethers.getSigners()
  const factory = await ethers.getContractFactory('MineAuction', { signer: owner })
  const auction = await factory.deploy()
  const block = await owner.provider.getBlock('latest')
  assert(block, 'No block found')
  await auction.setAuctionStartTime(block.timestamp)
  await auction.setAuctionInterval(DEFAULT_AUCTION_INTERVAL)
  await auction.setAuctionSettleTime(DEFAULT_SETTLE_TIME)
  await increaseTime(owner, 5 * 60)

  return { auction, owner, other, another }
}
