import hre from 'hardhat'
import { verify as verifyOnEtherscan } from './etherscan'
import { safeReadContractAddress } from './driver'
import { proxyPath, type DeployResult, proxyName } from './deploy'

let _skipVerification = false

export async function verify(name: string, path: string, args: any, [address, skipWait, proxyResult]: DeployResult) {
  if (_skipVerification) {
    return
  }

  await verifyOnEtherscan(
    name,
    {
      address,
      constructorArguments: args,
      contract: `${path}:${name}`,
    },
    skipWait,
  )

  if (proxyResult) {
    const [proxyAddress] = proxyResult
    const [owner] = await hre.ethers.getSigners()
    await verifyOnEtherscan(
      'Proxy',
      {
        address: proxyAddress,
        constructorArguments: [owner.address],
        contract: `${proxyPath}:${proxyName}`,
      },
      true,
    )
  }
}

export async function verifyFromLog(name: string, path: string, args: any, _address?: string) {
  const address = _address ?? safeReadContractAddress(hre.network.name, name)
  await verify(name, path, args, [address, false, undefined])
}

export function skipVerification() {
  _skipVerification = true
}
