import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployMineFixture } from '../fixtures/deployMineFixture'

// create test cases for ownerable
describe('ownerable', () => {
  it('owner can transfer ownership', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    await mine.setOwner(other.getAddress())
    expect(await mine.owner()).to.equal(await other.getAddress())
  })

  it('other address can not transfer ownership', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    await expect(mine.connect(other).setOwner(other.getAddress())).to.be.revertedWithCustomError(
      mine,
      'OwnableUnauthorizedAccount',
    )
  })

  it('set owner', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    await mine.setOwner(other.getAddress())
    expect(await mine.owner()).to.equal(await other.getAddress())
  })

  it('set same address owner', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    await mine.setOwner(other.getAddress())

    // revert with error OwnerableDuplicatedOperation
    await expect(mine.connect(other).setOwner(other.getAddress())).to.be.revertedWithCustomError(
      mine,
      'OwnerDuplicatedOperation',
    )
  })

  it('should emit event when set owner', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    const otherAddress = await other.getAddress()
    await expect(mine.setOwner(other.getAddress())).to.emit(mine, 'OwnerSet').withArgs(otherAddress)
  })
})
