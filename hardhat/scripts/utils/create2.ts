import { type ParamType, ethers } from 'ethers'

interface EncodeParams {
  types: ReadonlyArray<string | ParamType>
  values: readonly any[]
}

export interface Create2Meta {
  address: string
  saltHex: string
  deployBytecode: string
  deployBytecodeHash: string
}

export function encode(params: EncodeParams) {
  const coder = ethers.AbiCoder.defaultAbiCoder()
  const encoded = coder.encode(params.types, params.values)
  return encoded.slice(2)
}

export function getCreate2Meta(from: string, salt: string, bytecode: string, constructor: EncodeParams) {
  const encodedConstructor = encode(constructor)
  const deployBytecode = bytecode + encodedConstructor
  const deployBytecodeHash = ethers.keccak256(bytecode + encodedConstructor)
  const saltHex = ethers.id(salt)
  const address = ethers.getCreate2Address(from, saltHex, deployBytecodeHash)
  return { address, saltHex, deployBytecode, deployBytecodeHash }
}
