import hre from 'hardhat'
import { skipVerification } from './utils'
import { deployDeployer } from './shared/deployDeployer'
import { deployUnitToken } from './shared/deployUnitToken'

async function run() {
  if (hre.network.name === 'local') {
    skipVerification()
  }
  await deployDeployer()
  await deployUnitToken()
}

void run()
