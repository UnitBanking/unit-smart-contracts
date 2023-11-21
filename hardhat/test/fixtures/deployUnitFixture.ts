import { ethers } from 'hardhat'
import { type HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { type UnitToken, UnitToken__factory } from '../../build/types'

interface UnitFixtureReturnType {
  unit: UnitToken
  owner: HardhatEthersSigner
  other: HardhatEthersSigner
  another: HardhatEthersSigner
}

export async function deployUnitFixture(): Promise<UnitFixtureReturnType> {
  const [owner, other, another] = await ethers.getSigners()
  const factory = await ethers.getContractFactory('UnitToken', { signer: owner })
  const unit = await factory.deploy()
  const unitAddress = await unit.getAddress()

  const initialize = factory.interface.encodeFunctionData('initialize', [])
  const proxy = await ethers.deployContract('Proxy', [owner.address], { signer: owner })
  await proxy.upgradeToAndCall(unitAddress, initialize)
  const proxyAddress = await proxy.getAddress()
  const proxyUnit = UnitToken__factory.connect(proxyAddress, owner)

  await proxyUnit.mint(BigInt(100000) * BigInt(10) ** BigInt(18))
  return { unit: proxyUnit, owner, other, another }
}
