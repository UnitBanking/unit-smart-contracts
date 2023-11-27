import { expect } from 'chai'
import { ethers } from 'hardhat'

describe('BondingCurve', () => {
  it('deploy', async () => {
    // Arrange
    const [wallet] = await ethers.getSigners()
    const inflationOracle = await ethers.deployContract('InflationOracleTest', [], {})
    await inflationOracle.setPriceIndexTwentyYearsAgo(77)
    await inflationOracle.setLatestPriceIndex(121)
    const ethUsdOracle = await ethers.deployContract('EthUsdOracle', [], {})
    const unitToken = await ethers.deployContract('ERC20', [wallet], {})
    const mineToken = await ethers.deployContract('ERC20', [wallet], {})

    // Act
    const bondingCurve = await ethers.deployContract(
      'BondingCurve',
      [unitToken, mineToken, inflationOracle, ethUsdOracle],
      {}
    )

    // Assert
    const address = await bondingCurve.getAddress()
    expect(address.length).to.be.gt(0)
    expect(await bondingCurve.lastInternalPrice()).to.be.eq(1000000000000000000n)
  })

  it('update internals', async () => {
    // Arrange
    const [wallet] = await ethers.getSigners()
    const inflationOracle = await ethers.deployContract('InflationOracleTest', [], {})
    await inflationOracle.setPriceIndexTwentyYearsAgo(77)
    await inflationOracle.setLatestPriceIndex(121)
    const ethUsdOracle = await ethers.deployContract('EthUsdOracle', [], {})
    const unitToken = await ethers.deployContract('ERC20', [wallet], {})
    const mineToken = await ethers.deployContract('ERC20', [wallet], {})
    const bondingCurve = await ethers.deployContract(
      'BondingCurve',
      [unitToken, mineToken, inflationOracle, ethUsdOracle],
      {}
    )

    const lastOracleUpdateTimestampBefore = await bondingCurve.lastOracleUpdateTimestamp()

    // Act
    await bondingCurve.updateInternals()
    const lastOracleUpdateTimestampAfter = await bondingCurve.lastOracleUpdateTimestamp()

    // Assert
    expect(lastOracleUpdateTimestampAfter).to.be.gt(lastOracleUpdateTimestampBefore)
  })

  it('get internal price', async () => {
    // Arrange
    const [wallet] = await ethers.getSigners()
    const inflationOracle = await ethers.deployContract('InflationOracleTest', [], {})
    await inflationOracle.setPriceIndexTwentyYearsAgo(77)
    await inflationOracle.setLatestPriceIndex(121)
    const ethUsdOracle = await ethers.deployContract('EthUsdOracle', [], {})
    const unitToken = await ethers.deployContract('ERC20', [wallet], {})
    const mineToken = await ethers.deployContract('ERC20', [wallet], {})
    const bondingCurve = await ethers.deployContract(
      'BondingCurve',
      [unitToken, mineToken, inflationOracle, ethUsdOracle],
      {}
    )

    // Act
    const internalPrice = await bondingCurve.getInternalPrice()

    // Assert
    expect(internalPrice).to.be.gt(0)
  })

  it('get Unit/ETH price', async () => {
    // Arrange
    const [wallet] = await ethers.getSigners()
    const inflationOracle = await ethers.deployContract('InflationOracleTest', [], {})
    await inflationOracle.setPriceIndexTwentyYearsAgo(77)
    await inflationOracle.setLatestPriceIndex(121)
    const ethUsdOracle = await ethers.deployContract('EthUsdOracle', [], {})
    const unitToken = await ethers.deployContract('ERC20', [wallet], {})
    const mineToken = await ethers.deployContract('ERC20', [wallet], {})
    const bondingCurve = await ethers.deployContract(
      'BondingCurve',
      [unitToken, mineToken, inflationOracle, ethUsdOracle],
      {}
    )

    // Act
    const unitEthPrice = await bondingCurve.getUnitEthPrice()

    // Assert
    expect(unitEthPrice).to.be.gt(0)
  })
})
