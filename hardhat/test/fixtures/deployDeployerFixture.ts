import { ethers } from 'hardhat'
import { type HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { type Deployer } from '../../build/types'

interface DeployerFixtureReturnType {
  deployer: Deployer
  deployerAddress: string
  owner: HardhatEthersSigner
  other: HardhatEthersSigner
  another: HardhatEthersSigner
}

export async function deployDeployerFixture(): Promise<DeployerFixtureReturnType> {
  const [owner, other, another] = await ethers.getSigners()
  const deployer = await ethers.deployContract('Deployer', [], { signer: owner })
  const address = await deployer.getAddress()
  return { deployer, deployerAddress: address, owner, other, another }
}
