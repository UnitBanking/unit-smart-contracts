import { ethers } from 'hardhat'
import { type HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { type MineAuction, type Proxy, MineAuction__factory, type BaseToken, type MineToken } from '../../build/types'
import { deployBaseTokenFixture } from './deployBaseTokenTestFixture'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployMineFixture } from './deployMineFixture'

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

  const dummyBondingCurve = '0x0000000000000000000000000000000000000001'
  const { base } = await deployBaseTokenFixture()
  const { mine } = await loadFixture(deployMineFixture)
  await proxyAuction.setMine(await mine.getAddress())
  await proxyAuction.setBidToken(await base.getAddress())
  await proxyAuction.setBondingCurve(dummyBondingCurve)
  await mine.setMinter(await proxyAuction.getAddress(), true)

  await base.mint(other.address, 10000n * 10n ** (await base.decimals()))
  await base.mint(another.address, 10000n * 10n ** (await base.decimals()))
  await base.approve(proxyAddress, ethers.MaxUint256)
  await base.connect(other).approve(proxyAddress, ethers.MaxUint256)
  await base.connect(another).approve(proxyAddress, ethers.MaxUint256)
  return { auction: proxyAuction, proxy, token: base, mine, owner, other, another }
}
