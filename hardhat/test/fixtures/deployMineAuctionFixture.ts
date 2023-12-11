import { ethers } from 'hardhat'
import { type HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import {type MineAuction, MineAuction__factory} from '../../build/types'
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
  const auctionAddress = await auction.getAddress()

  const initialize = factory.interface.encodeFunctionData('initialize', [])
  const proxy = await ethers.deployContract('Proxy', [owner.address], { signer: owner })
  await proxy.upgradeToAndCall(auctionAddress, initialize)
  const proxyAddress = await proxy.getAddress()
  const proxyAuction = MineAuction__factory.connect(proxyAddress, owner)

  const block = await owner.provider.getBlock('latest')
  assert(block, 'No block found')
  await proxyAuction.setAuctionStartTime(block.timestamp)
  await proxyAuction.setAuctionInterval(DEFAULT_AUCTION_INTERVAL)
  await proxyAuction.setAuctionSettleTime(DEFAULT_SETTLE_TIME)
  await increaseTime(owner, 5 * 60)

  return { auction: proxyAuction, proxy, owner, other, another }
}
