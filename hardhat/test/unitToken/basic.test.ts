import { expect } from 'chai'
import { deployUnitFixture } from '../fixtures/deployUnitFixture'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'

describe('UnitToken basics', () => {
  it('has token info', async () => {
    const { unit } = await loadFixture(deployUnitFixture)
    const name = await unit.name()
    const symbol = await unit.symbol()
    const decimals = await unit.decimals()
    expect(name).to.equal('Unit Token')
    expect(symbol).to.equal('UNIT')
    expect(decimals).to.equal(18)
  })
})
