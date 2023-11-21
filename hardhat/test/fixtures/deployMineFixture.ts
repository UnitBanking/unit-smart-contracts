import { ethers } from 'hardhat'
import { type HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { type MineToken, MineToken__factory } from '../../build/types'

interface MineFixtureReturnType {
  mine: MineToken
  owner: HardhatEthersSigner
  other: HardhatEthersSigner
  another: HardhatEthersSigner
}

export async function deployMineFixture(): Promise<MineFixtureReturnType> {
  const [owner, other, another] = await ethers.getSigners()
  const factory = await ethers.getContractFactory('MineToken', { signer: owner })
  const mine = await factory.deploy()
  const mineAddress = await mine.getAddress()

  const initialize = factory.interface.encodeFunctionData('initialize', [])
  const proxy = await ethers.deployContract('Proxy', [owner.address], { signer: owner })
  await proxy.upgradeToAndCall(mineAddress, initialize)
  const proxyAddress = await proxy.getAddress()
  const proxyMine = MineToken__factory.connect(proxyAddress, owner)
  await proxyMine.setDefaultDelegatee('0x0000000000000000000000000000000000000001')

  await proxyMine.mint(BigInt(100000) * BigInt(10) ** BigInt(18))
  return { mine: proxyMine, owner, other, another }
}
