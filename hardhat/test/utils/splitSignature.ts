export function splitSignature(signature: string) {
  if (signature.length !== 132) {
    throw new Error('Invalid signature length')
  }

  const r = '0x' + signature.slice(2, 66)
  const s = '0x' + signature.slice(66, 130)
  let v = parseInt('0x' + signature.slice(130, 132), 16)

  if (v < 27) v += 27

  return { r, s, v }
}
