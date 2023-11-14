import chalk from 'chalk'
import { ethers, network } from 'hardhat'
import { Log } from 'ethers'
import {
  type ContractInfo,
  readContractLog,
  safeReadContractAddress,
  writeContractLog,
  safeReadContractLog,
} from './driver'
import { compute, verify } from './checksum'
import { CREATE2_SALT, type Create2Meta, getCreate2Meta } from '.'
import { type Deployer } from '../../build/types'

export type DeployConfig = NoCreate2 | WithCreate2
interface NoCreate2 extends _DeployConfig {
  noCreate2: boolean
}
interface WithCreate2 extends _DeployConfig {
  saltSuffix: string
}
interface _DeployConfig {
  name: string
  path: string
  args: any[]
  notUpgradable?: boolean
  skipCheck?: () => Promise<boolean>
}

export type DeployResult = [string, boolean, ProxyDeployResult | undefined]
export type ProxyDeployResult = [string, boolean]

export const proxyName = 'Proxy'
export const proxyPath = 'contracts/Proxy.sol'

export async function deploy(config: DeployConfig): Promise<DeployResult> {
  const contractInfo = readContractLog(network.name, config.name)
  if ((await basicSkipCheck(config, contractInfo)) && (!config.skipCheck || (await config.skipCheck()))) {
    console.log(`Skipping ${config.name} deployment`)
    // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
    return [contractInfo!.address, true, contractInfo!.proxy ? [contractInfo!.proxy, true] : undefined]
  }

  const address = await _deploy(config)
  const checksum = compute(config.path)
  writeContractLog(network.name, config.name, { address, checksum }, false)
  const updatedContractInfo = safeReadContractLog(network.name, config.name)

  if (!config.notUpgradable) {
    const [proxy, upgradeOnly] = await deployProxy(config, updatedContractInfo)
    writeContractLog(network.name, config.name, { address, checksum, proxy, proxyChecksum: compute(proxyPath) })
    return [address, false, [proxy, upgradeOnly]]
  } else {
    return [address, false, undefined]
  }
}

async function deployProxy(config: DeployConfig, contractInfo: ContractInfo): Promise<ProxyDeployResult> {
  const [owner] = await ethers.getSigners()
  const proxyConfig = { name: proxyName, path: proxyPath, args: [owner.address], saltSuffix: config.name }
  if (await proxySkipCheck(config.name, proxyConfig, contractInfo)) {
    console.log(`Skipping ${config.name} proxy deployment, upgrading ...`)
    // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
    return [contractInfo.proxy!, true]
  } else {
    const address = await _deploy(proxyConfig)
    return [address, false]
  }
}

async function _deploy(config: DeployConfig): Promise<string> {
  console.log(`Deploying ${config.name}...`)
  const address = (config as NoCreate2).noCreate2
    ? await ethersDeploy(config as NoCreate2)
    : await create2Deploy(config as WithCreate2)
  console.log(`${config.name} deployed to ${address}`)
  return address
}

async function proxySkipCheck(name: string, config: DeployConfig, contractInfo?: ContractInfo): Promise<boolean> {
  if (!contractInfo || !contractInfo.proxy || !contractInfo.proxyChecksum) {
    return false
  }

  const reason: string[] = []
  if (
    checksumCheck(config.path, contractInfo.proxyChecksum ?? '', reason) &&
    (await addressCheck(config, contractInfo.proxy ?? '', reason))
  ) {
    return true
  } else {
    console.log(`(Re)Deploy ${name} proxy due to:`)
    console.log(reason.map((reason) => `- ${reason}`).join('\n'))
    return false
  }
}

async function basicSkipCheck(config: DeployConfig, contractInfo?: ContractInfo): Promise<boolean> {
  if (!contractInfo) {
    return false
  }

  const reasons: string[] = []
  if (
    checksumCheck(config.path, contractInfo.checksum ?? '', reasons) &&
    (await addressCheck(config, contractInfo.address, reasons))
  ) {
    return true
  } else {
    console.log(`(Re)Deploy ${config.name} due to:`)
    console.log(reasons.map((reason) => `- ${reason}`).join('\n'))
    return false
  }
}

function checksumCheck(path: string, expected: string, output: string[]) {
  if (verify(expected, path)) {
    return true
  } else {
    output.push(`Checksum mismatch for ${path}`)
    return false
  }
}

async function addressCheck(config: DeployConfig, expected: string, output: string[]) {
  if ((config as NoCreate2).noCreate2) {
    return true
  }
  const deployerAddress = safeReadContractAddress(network.name, DEPLOYER_CONTRACT_NAME)
  const meta = await prepareCreate2MetaFor(config as WithCreate2, deployerAddress)
  if (expected === meta.address) {
    return true
  } else {
    output.push(`Create2 precomputed address mismatch for ${config.name}`)
    return false
  }
}

async function ethersDeploy(config: NoCreate2): Promise<string> {
  const factory = await ethers.getContractFactory(config.name)
  const deployed = await factory.deploy(...config.args)
  await deployed.waitForDeployment()
  const address = await deployed.getAddress()
  return address
}

const DEPLOYER_CONTRACT_NAME = 'Deployer'

async function prepareCreate2MetaFor(config: WithCreate2, deployerAddress: string): Promise<Create2Meta> {
  const salt = `${CREATE2_SALT}-${config.saltSuffix}`
  const contractfactory = await ethers.getContractFactory(config.name)
  const types = contractfactory.interface.deploy.inputs.map((input) => input.type)
  return getCreate2Meta(deployerAddress, salt, contractfactory.bytecode, { types, values: config.args })
}

async function create2Deploy(config: WithCreate2): Promise<string> {
  const deployerFactory = await ethers.getContractFactory(DEPLOYER_CONTRACT_NAME)
  const deployerAddress = safeReadContractAddress(network.name, DEPLOYER_CONTRACT_NAME)
  const deployer = deployerFactory.attach(deployerAddress) as Deployer

  const meta = await prepareCreate2MetaFor(config, deployerAddress)
  try {
    const tx = await deployer.deploy(meta.deployBytecode, meta.saltHex)
    const receipt = await tx.wait()
    if (receipt?.logs) {
      const deployedEvent = deployerFactory.interface.getEvent('Deployed')
      if (!deployedEvent) {
        throw new Error('create2Deploy: Deployed event not found in abi')
      }
      const filtered = receipt.logs.filter((log) => log instanceof Log && log.topics[0] === deployedEvent.topicHash)
      if (filtered.length !== 1) {
        throw new Error(`create2Deploy: Deployed event count ${filtered.length} is incorrect`)
      }
      const decoded = deployerFactory.interface.decodeEventLog(deployedEvent, filtered[0].data, filtered[0].topics)
      if (decoded[0] !== meta.address) {
        throw new Error('create2Deploy: Deployed address mismatch')
      }
    }
  } catch (err: any) {
    if (err.data) {
      const factory = await ethers.getContractFactory(DEPLOYER_CONTRACT_NAME)
      const errorSelector = factory.interface.getError('DeployerFailedDeployment')?.selector
      if (err.data.startsWith(errorSelector)) {
        console.log(chalk.red('error'), `${config.name} deployment revert with DeployerFailedDeployment`)
        console.log(chalk.red('error'), `contract already deployed? check ${meta.address}\n`)
      }
    }
    throw err
  }
  return meta.address
}
