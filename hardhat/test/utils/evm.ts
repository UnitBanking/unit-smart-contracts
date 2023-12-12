import { assert } from 'chai'
import { type ethers } from 'ethers'

export async function getLatestBlock(wallet: ethers.Signer) {
  const block = await (wallet.provider as ethers.JsonRpcProvider).getBlock('latest')
  assert(block, 'No block found')
  return block
}
