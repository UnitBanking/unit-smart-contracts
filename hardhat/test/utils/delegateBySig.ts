import { type ethers as e } from 'ethers'
import { ethers } from 'hardhat'
import { DelegationSignType, splitSignature } from '.'
import { type IERC20, type IVotes } from '../../build/types'

export async function delegateBySig(nonce: number, signer: e.Signer, delegatee: string, contract: IVotes & IERC20) {
  const { expiry, v, r, s } = await getDelegateBySigOptions(nonce, signer, delegatee, contract)
  await contract.delegateBySig(delegatee, nonce, expiry, v, r, s)
}

export async function getDelegateBySigOptions(
  nonce: number,
  signer: e.Signer,
  delegatee: string,
  contract: IVotes & IERC20,
) {
  const expiry = Date.now() + 100000
  const name = await contract.name()
  const address = await contract.getAddress()
  const chainId = (await ethers.provider.getNetwork()).chainId

  const rawSignature = await signer.signTypedData(
    {
      name,
      chainId,
      verifyingContract: address,
    },
    DelegationSignType,
    {
      delegatee,
      nonce,
      expiry,
    },
  )
  const signature = splitSignature(rawSignature)
  return { delegatee, nonce, expiry, v: signature.v, r: signature.r, s: signature.s }
}
