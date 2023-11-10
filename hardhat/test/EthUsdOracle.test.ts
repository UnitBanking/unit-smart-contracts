import { expect } from 'chai'
import { ethers } from 'hardhat'

describe('EthUsdOracle', () => {
  it('get ETH-USD price', async () => {
    const oracle = await ethers.deployContract('EthUsdOracle', [], {})
    const price = await oracle.getEthUsdPrice()
    expect(price).to.be.gt(BigInt(0))
  })
})
