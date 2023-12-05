import { ethers } from 'hardhat'
import { type HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { type ProxiableTest, ProxiableTest__factory, type Proxy } from '../../build/types'

interface ProxyFixtureReturnType {
  contract: ProxiableTest
  contractAddress: string
  proxyAsContract: ProxiableTest
  proxy: Proxy
  proxyAddress: string
  owner: HardhatEthersSigner
  other: HardhatEthersSigner
  another: HardhatEthersSigner
}

export async function proxyFixture(): Promise<ProxyFixtureReturnType> {
  const [owner, other, another] = await ethers.getSigners()
  const factory = await ethers.getContractFactory('ProxiableTest', { signer: owner })
  const contract = await factory.deploy()
  const contractAddress = await contract.getAddress()

  const initialize = factory.interface.encodeFunctionData('initialize', [])
  const proxy = await ethers.deployContract('Proxy', [owner.address], { signer: owner })
  await proxy.upgradeToAndCall(contractAddress, initialize)
  const proxyAddress = await proxy.getAddress()
  const proxyAsContract = ProxiableTest__factory.connect(proxyAddress, owner)

  return { contract, contractAddress, proxyAsContract, proxy, proxyAddress, owner, other, another }
}
