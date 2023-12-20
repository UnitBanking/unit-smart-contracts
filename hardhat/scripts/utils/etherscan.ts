import hre from 'hardhat'
import { Etherscan } from '@nomicfoundation/hardhat-verify/etherscan'
import { ETHERSCAN_API_URL, ETHERSCAN_URL, type Network } from './constants'

export type Libraries = Record<string, string>
export interface verifyTaskArguments {
  address: string
  constructorArguments: any[]
  libraries?: Libraries
  contract: string
}

const CONTRACT_PROPAGATION_DELAY = 30

export async function verify(contractName: string, verifyArguments: verifyTaskArguments, skipWait = false) {
  const apiKey = getEtherscanAPIKey()
  const etherscan = createEtherscanInstance(apiKey)
  const verified = await transient<boolean>(
    `Checking verification status on ${verifyArguments.address}...`,
    async () => await etherscan.isVerified(verifyArguments.address)
  )
  if (verified) {
    clearLine()
    console.log(`Contract ${contractName} is already verified on ${verifyArguments.address}`)
    return
  }
  console.log(`Verifying ${contractName}...`)
  try {
    if (!skipWait) {
      await waitPropagation()
    }
    await hre.run('verify:verify', verifyArguments)
    console.log("Contract verification ended. See the above hardhat's logs for more details.")
  } catch (err) {
    if (err instanceof Error && err.message.includes('Uh oh! Unfortunately that page wasn’t found.')) {
      console.log('Problem with etherscan. Try again later.')
      return
    }
    console.log(`Error during verification: ${err instanceof Error ? err.message : String(err)}. Skipping`)
  }
}

function getEtherscanAPIKey() {
  return typeof hre.config.etherscan.apiKey === 'string'
    ? hre.config.etherscan.apiKey
    : hre.config.etherscan.apiKey[hre.network.name]
}

function createEtherscanInstance(apiKey: string) {
  return new Etherscan(
    apiKey,
    ETHERSCAN_API_URL[hre.network.name as Network],
    ETHERSCAN_URL[hre.network.name as Network]
  )
}

const timer = async (t: number, output: (timeLeft: number) => void) => {
  return await new Promise((resolve) => {
    const countDown = setInterval(() => {
      output(t--)
      if (t <= 0) {
        clearInterval(countDown)
        resolve(t)
        clearLine()
        console.log()
      }
    }, 1000)
  })
}

async function waitPropagation() {
  const output = (timeLeft: number) => {
    clearLine()
    process.stdout.write(`Waiting ${timeLeft} seconds to propagate the contract...`)
  }
  await timer(CONTRACT_PROPAGATION_DELAY, output)
}

function clearLine() {
  process.stdout.clearLine(0)
  process.stdout.cursorTo(0)
}

async function transient<T>(message: string, cb: () => Promise<T>) {
  process.stdout.write(message)
  try {
    const result = await cb()
    clearLine()
    return result
  } catch (error) {
    process.stdout.write('\n')
    throw error
  }
}
