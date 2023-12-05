import { ethers } from 'hardhat'
import { type HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { BaseTokenTest__factory, type BaseTokenTest, type Proxy } from '../../build/types'

interface BaseTokenTestFixtureReturnType {
  base: BaseTokenTest
  owner: HardhatEthersSigner
  other: HardhatEthersSigner
  another: HardhatEthersSigner
}

export interface BaseTokenTestWithProxyFixtureReturnType extends BaseTokenTestFixtureReturnType {
  proxy: Proxy
}

export async function deployBaseTokenFixture(): Promise<BaseTokenTestFixtureReturnType> {
  const [owner, other, another] = await ethers.getSigners()
  const base = await ethers.deployContract('BaseTokenTest', [], { signer: owner })
  await base.initialize()
  await base.setMinter(owner.address, true)
  await base.setBurner(owner.address, true)
  await base.mint(owner.address, BigInt(100000) * BigInt(10) ** BigInt(18))
  return { base, owner, other, another }
}

export async function deployBaseTokenWithProxyFixture(): Promise<BaseTokenTestWithProxyFixtureReturnType> {
  const [owner, other, another] = await ethers.getSigners()
  const factory = await ethers.getContractFactory('BaseTokenTest', { signer: owner })
  const base = await factory.deploy()
  const baseAddress = await base.getAddress()

  const initialize = factory.interface.encodeFunctionData('initialize', [])
  const proxy = await ethers.deployContract('Proxy', [owner.address], { signer: owner })
  await proxy.upgradeToAndCall(baseAddress, initialize)
  const proxyAddress = await proxy.getAddress()
  const proxyBase = BaseTokenTest__factory.connect(proxyAddress, owner)
  await proxyBase.setMinter(owner.address, true)
  await proxyBase.setBurner(owner.address, true)

  await proxyBase.mint(owner.address, BigInt(100000) * BigInt(10) ** BigInt(18))

  return { base: proxyBase, proxy, owner, other, another }
}
