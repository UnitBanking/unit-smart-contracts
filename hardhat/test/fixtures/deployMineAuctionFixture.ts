import { ethers } from 'hardhat'
import { type HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { type MineAuction, type Proxy, MineAuction__factory, type BaseToken, type MineToken } from '../../build/types'
import { deployBaseTokenFixture } from './deployBaseTokenTestFixture'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployMineFixture } from './deployMineFixture'
import { getLatestBlock } from '../utils'

interface MineAuctionFixtureReturnType {
  auction: MineAuction
  proxy: Proxy
  token: BaseToken
  mine: MineToken
  owner: HardhatEthersSigner
  other: HardhatEthersSigner
  another: HardhatEthersSigner
}

export const DEFAULT_SETTLE_TIME = 1 * 60 * 60
export const DEFAULT_BID_TIME = 23 * 60 * 60
export const DEFAULT_AUCTION_INTERVAL = DEFAULT_SETTLE_TIME + DEFAULT_BID_TIME

export async function mineAuctionFixture(): Promise<MineAuctionFixtureReturnType> {
  const [owner, other, another] = await ethers.getSigners()
  const factory = await ethers.getContractFactory('MineAuction', { signer: owner })
  const auction = await factory.deploy()
  const auctionAddress = await auction.getAddress()
  const { mine } = await loadFixture(deployMineFixture)
  const { base } = await deployBaseTokenFixture()

  const mineAddress = await mine.getAddress()
  const bidTokenAddress = await base.getAddress()

  const dummyBondingCurve = '0x0000000000000000000000000000000000000001'
  const block = await getLatestBlock(owner)

  const initialize = factory.interface.encodeFunctionData('initialize(address,address,address, uint256)', [
    dummyBondingCurve,
    mineAddress,
    bidTokenAddress,
    block.timestamp,
  ])
  const proxy = await ethers.deployContract('Proxy', [owner.address], { signer: owner })
  await proxy.upgradeToAndCall(auctionAddress, initialize)
  const proxyAddress = await proxy.getAddress()
  const proxyAuction = MineAuction__factory.connect(proxyAddress, owner)

  await mine.setMinter(await proxyAuction.getAddress(), true)

  await base.mint(other.address, 10000n * 10n ** (await base.decimals()))
  await base.mint(another.address, 10000n * 10n ** (await base.decimals()))
  await base.connect(owner).approve(proxyAddress, ethers.MaxUint256)
  await base.connect(other).approve(proxyAddress, ethers.MaxUint256)
  await base.connect(another).approve(proxyAddress, ethers.MaxUint256)
  return { auction: proxyAuction, proxy, token: base, mine, owner, other, another }
}
