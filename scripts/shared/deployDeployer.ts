import { deploy, verify } from '../utils'

const sourcePath = 'contracts/Deployer.sol'

export async function deployDeployer() {
  const address = await deploy({ name: 'Deployer', path: sourcePath, args: [], noCreate2: true, notUpgradable: true })
  await verify('Deployer', sourcePath, [], address)
  return address[0]
}
