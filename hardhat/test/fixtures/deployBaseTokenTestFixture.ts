import { ethers } from 'hardhat'
import { type HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { type BaseTokenTest } from '../../build/types'

interface BaseTokenTestFixtureReturnType {
  base: BaseTokenTest
  owner: HardhatEthersSigner
  other: HardhatEthersSigner
  another: HardhatEthersSigner
}

export async function deployBaseTokenFixture(): Promise<BaseTokenTestFixtureReturnType> {
  const [owner, other, another] = await ethers.getSigners()
  const base = await ethers.deployContract('BaseTokenTest', [], { signer: owner })
  await base.initialize()
  await base.mint(owner.address, BigInt(100000) * BigInt(10) ** BigInt(18))
  return { base, owner, other, another }
}
