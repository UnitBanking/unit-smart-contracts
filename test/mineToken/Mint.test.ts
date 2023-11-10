import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployMineFixture } from '../fixtures/deployMineFixture'

// create test cases for permission mint
describe('permission mint', () => {
  it('owner can mint', async () => {
    const { mine, owner } = await loadFixture(deployMineFixture)
    expect(await mine.isMintable(owner.getAddress())).to.be.true
  })

  it('other address can not mint', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    expect(await mine.isMintable(other.getAddress())).to.be.false
  })

  it('set mintable', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    await mine.setMintable(other.getAddress(), true)
    expect(await mine.isMintable(other.getAddress())).to.be.true

    await mine.setMintable(other.getAddress(), false)
    expect(await mine.isMintable(other.getAddress())).to.be.false
  })

  it('set same address mintable', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    await mine.setMintable(other.getAddress(), true)

    // revert with error MintableDuplicatedOperation
    await expect(mine.setMintable(other.getAddress(), true)).to.be.revertedWithCustomError(
      mine,
      'MintableDuplicatedOperation',
    )
  })

  it('should emit event when set mintable', async () => {
    const { mine, other } = await loadFixture(deployMineFixture)
    const otherAddress = await other.getAddress()
    await expect(mine.setMintable(other.getAddress(), true)).to.emit(mine, 'MintableSet').withArgs(otherAddress, true)
    await expect(mine.setMintable(other.getAddress(), false)).to.emit(mine, 'MintableSet').withArgs(otherAddress, false)
  })
})
