import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployMineFixture } from '../fixtures/deployMineFixture'

describe('MineToken mint', () => {
  it('can be minted', async () => {
    const { mine, owner } = await loadFixture(deployMineFixture)
    const balanceBefore = await mine.balanceOf(owner.address)
    await mine.mint(owner.address, BigInt(100000) * BigInt(10) ** BigInt(18))
    const balanceAfter = await mine.balanceOf(owner.address)
    expect(balanceAfter - balanceBefore).to.equal(BigInt(100000) * BigInt(10) ** BigInt(18))
  })

  it('mint should not exceed max supply', async () => {
    const { mine, owner } = await loadFixture(deployMineFixture)
    const maxSupply = await mine.MAX_SUPPLY()
    await expect(mine.mint(owner.address, maxSupply + BigInt(1))).to.be.revertedWithCustomError(
      mine,
      'MineTokenExceedMaxSupply'
    )
  })
})
