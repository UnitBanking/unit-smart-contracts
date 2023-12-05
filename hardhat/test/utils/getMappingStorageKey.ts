import { ethers } from 'ethers'

export function getMappingStorageKey(key: string, slot: number | string) {
  if (!ethers.isHexString(key)) {
    key = ethers.hexlify(ethers.toUtf8Bytes(key))
  }
  if (typeof slot !== 'number' && !ethers.isHexString(slot)) {
    slot = ethers.hexlify(ethers.toUtf8Bytes(slot))
  }
  const paddedKey = ethers.zeroPadValue(key, 32)
  const paddedSlot =
    typeof slot === 'number'
      ? ethers.zeroPadValue(ethers.hexlify(new Uint8Array([slot])), 32)
      : ethers.zeroPadValue(slot, 32)
  return ethers.keccak256(ethers.concat([paddedKey, paddedSlot]))
}
