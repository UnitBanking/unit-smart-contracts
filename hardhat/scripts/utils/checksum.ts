import fs from 'fs'
import pathLib from 'path'
import crypto from 'crypto'
import { PROJECT_ROOT } from './driver'

export function compute(path: string) {
  if (!pathLib.isAbsolute(path)) {
    path = pathLib.join(PROJECT_ROOT, path)
  }
  if (!fs.existsSync(path)) {
    throw new Error(`Checksum compute: File not found: ${path}`)
  }
  const content = fs.readFileSync(path, 'utf-8')
  const hashSum = crypto.createHash('sha256').update(content)
  return hashSum.digest('hex')
}

export function verify(checksum: string, path: string) {
  return checksum === compute(path)
}
