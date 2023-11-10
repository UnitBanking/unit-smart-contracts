import { expect } from 'chai'
import { ethers } from 'hardhat'

describe('InflationOracle', () => {
  it('get inflation rate', async () => {
    const oracle = await ethers.deployContract('InflationOracle', [], {})
    const price = await oracle.getInflationRate()
    expect(price).to.be.gt(BigInt(0))
  })
})
