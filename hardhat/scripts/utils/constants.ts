export enum Network {
  Mainnet = 'mainnet',
  Ganache = 'ganache',
  Goerli = 'goerli',
  Sepolia = 'sepolia',
  Test = 'test',
}

export const ETHERSCAN_API_URL = {
  [Network.Mainnet]: 'https://api.etherscan.io/api',
  [Network.Ganache]: '',
  [Network.Goerli]: 'https://api-goerli.etherscan.io/api',
  [Network.Sepolia]: 'https://api-sepolia.etherscan.io/api',
  [Network.Test]: '',
}

export const ETHERSCAN_URL = {
  [Network.Mainnet]: 'https://etherscan.io',
  [Network.Ganache]: '',
  [Network.Goerli]: 'https://goerli.etherscan.io',
  [Network.Sepolia]: 'https://sepolia.etherscan.io',
  [Network.Test]: '',
}

export const CREATE2_SALT = 'UNIT-CREATE2-SALT-00004'
