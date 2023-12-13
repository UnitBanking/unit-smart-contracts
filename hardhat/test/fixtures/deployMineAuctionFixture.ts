import { ethers as constants } from 'ethers'
import { ethers } from 'hardhat'
import { type HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { type MineAuction, type Proxy, MineAuction__factory, type BaseToken } from '../../build/types'
import { deployBaseTokenFixture } from './deployBaseTokenTestFixture'

interface MineAuctionFixtureReturnType {
  auction: MineAuction
  proxy: Proxy
  token: BaseToken
  owner: HardhatEthersSigner
  other: HardhatEthersSigner
  another: HardhatEthersSigner
}

export const DEFAULT_SETTLE_TIME = 1 * 60 * 60
export const DEFAULT_AUCTION_INTERVAL = 24 * 60 * 60

export async function mineAuctionFixture(): Promise<MineAuctionFixtureReturnType> {
  const [owner, other, another] = await ethers.getSigners()
  const factory = await ethers.getContractFactory('MineAuction', { signer: owner })
  const auction = await factory.deploy()
  const auctionAddress = await auction.getAddress()

  const initialize = factory.interface.encodeFunctionData('initialize', [])
  const proxy = await ethers.deployContract('Proxy', [owner.address], { signer: owner })
  await proxy.upgradeToAndCall(auctionAddress, initialize)
  const proxyAddress = await proxy.getAddress()
  const proxyAuction = MineAuction__factory.connect(proxyAddress, owner)

  const { base } = await deployBaseTokenFixture()
  await base.approve(proxyAddress, constants.MaxUint256)

  return { auction: proxyAuction, proxy, token: base, owner, other, another }
}
