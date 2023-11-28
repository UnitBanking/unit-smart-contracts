import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployMineFixture } from '../fixtures/deployMineFixture'

describe('MineToken basics', () => {
  it('has token info', async () => {
    const { mine } = await loadFixture(deployMineFixture)
    const name = await mine.name()
    const symbol = await mine.symbol()
    const decimals = await mine.decimals()
    expect(name).to.equal('Mine')
    expect(symbol).to.equal('MINE')
    expect(decimals).to.equal(18)
  })

  it('max supply', async () => {
    const { mine } = await loadFixture(deployMineFixture)
    const maxSupply = await mine.MAX_SUPPLY()
    expect(maxSupply).to.equal(1022700000n * 10n ** 18n)
  })
})
