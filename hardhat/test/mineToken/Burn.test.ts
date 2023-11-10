import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployMineFixture } from '../fixtures/deployMineFixture'

describe('permission burn', () => {
  it('owner can burn', async () => {
    const { mine, owner } = await loadFixture(deployMineFixture)
    expect(await mine.isBurnable(owner.getAddress())).to.be.true
  })

  it('other address can not burn', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    expect(await mine.isBurnable(other.getAddress())).to.be.false
  })

  it('set burnable', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    await mine.setBurnable(other.getAddress(), true)
    expect(await mine.isBurnable(other.getAddress())).to.be.true

    await mine.setBurnable(other.getAddress(), false)
    expect(await mine.isBurnable(other.getAddress())).to.be.false
  })

  it('set same address burnable', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    await mine.setBurnable(other.getAddress(), true)

    // revert with error BurnableDuplicatedOperation
    await expect(mine.setBurnable(other.getAddress(), true)).to.be.revertedWithCustomError(
      mine,
      'BurnableDuplicatedOperation',
    )
  })

  it('should emit event when set burnable', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    const otherAddress = await other.getAddress()
    await expect(mine.setBurnable(other.getAddress(), true)).to.emit(mine, 'BurnableSet').withArgs(otherAddress, true)

    await expect(mine.setBurnable(other.getAddress(), false)).to.emit(mine, 'BurnableSet').withArgs(otherAddress, false)
  })
})
