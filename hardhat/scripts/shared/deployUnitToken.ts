import { deploy, verify } from '../utils'

const name = 'UnitToken'
const sourcePath = 'contracts/UnitToken.sol'

export async function deployUnitToken() {
  const deployResult = await deploy({ name, path: sourcePath, args: [], noCreate2: true })
  await verify(name, sourcePath, [], deployResult)
  const [, , proxyAddress] = deployResult

  return proxyAddress
}
