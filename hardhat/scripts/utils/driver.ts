import fs from 'fs'
import pathLib from 'path'

export const PROJECT_ROOT = pathLib.join(__dirname, '../../')
export const LOCATION = pathLib.join(PROJECT_ROOT, './production.json')

export type ContractInfo = {
  address: string
  checksum?: string
  proxy?: string
  proxyChecksum?: string
} & Record<string, any>

export function safeReadContractAddress(network: string, name: string, location: string = LOCATION): string {
  const contractInfo = readContractLog(network, name, location)
  if (contractInfo && contractInfo.address) {
    return contractInfo.address
  } else {
    throw new Error(`Contract ${name} not deployed on ${network}`)
  }
}

export function safeReadContractLog(network: string, name: string, location: string = LOCATION): ContractInfo {
  const path = `${network}.${name}`
  const contractInfo = readLog(path, location) as ContractInfo
  if (contractInfo) {
    return contractInfo
  } else {
    throw new Error(`Section ${name} not found in ${network}`)
  }
}

export function readContractLog(network: string, name: string, location: string = LOCATION): ContractInfo | undefined {
  const path = `${network}.${name}`
  const contractInfo = readLog(path, location) as ContractInfo
  if (contractInfo) {
    return contractInfo
  } else {
    return undefined
  }
}

export function writeContractLog(
  network: string,
  name: string,
  content: ContractInfo,
  replace = true,
  location: string = LOCATION,
) {
  const path = `${network}.${name}`
  writeLog(path, content, replace, location)
}

export function readLog(path: string, location: string = LOCATION): any {
  const paths = path.split('.')
  let value = readFile(location)
  for (const key of paths) {
    value = (value ?? {})[key]
  }
  return value
}

export function writeLog(path: string, content: any, replace = true, location: string = LOCATION): void {
  const paths = path.split('.')
  const target = paths.pop()
  if (!target) {
    throw new Error('Invalid path: ' + path)
  }
  const contents = readFile(location)
  let value = contents
  for (const key of paths) {
    if (value) {
      value[key] = value[key] ?? {}
      value = value[key]
    } else {
      value = {}
    }
  }
  if (replace) {
    value[target] = content
  } else {
    value[target] = { ...value[target], ...content }
  }
  writeFile(contents, location)
}

function writeFile(contents: any, location: string): void {
  fs.writeFileSync(location, JSON.stringify(contents, null, 2) + '\n')
}

function readFile(location: string): any {
  return fs.existsSync(location) ? JSON.parse(fs.readFileSync(location, 'utf-8')) : {}
}
