import { type ethers } from 'ethers'

export async function increaseTime(wallet: ethers.Signer, seconds?: number) {
  await (wallet.provider as ethers.JsonRpcProvider).send('evm_increaseTime', [seconds ?? 1])
  await mineBlock(wallet)
}

export async function mineBlock(wallet: ethers.Signer) {
  await (wallet.provider as ethers.JsonRpcProvider).send('evm_mine', [])
}
