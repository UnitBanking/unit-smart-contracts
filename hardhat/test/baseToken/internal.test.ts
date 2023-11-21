import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { ethers } from 'ethers'
import { deployBaseTokenFixture } from '../fixtures/deployBaseTokenTestFixture'

describe('BaseToken internal', () => {
  it('reverts when mint to zero address', async () => {
    const { base } = await loadFixture(deployBaseTokenFixture)
    await expect(base.mintTo(ethers.ZeroAddress, 100n))
      .to.be.revertedWithCustomError(base, 'ERC20InvalidReceiver')
      .withArgs(ethers.ZeroAddress)
  })

  it('reverts when burn from zero address', async () => {
    const { base } = await loadFixture(deployBaseTokenFixture)
    await expect(base.burnFrom(ethers.ZeroAddress, 100n))
      .to.be.revertedWithCustomError(base, 'ERC20InvalidSender')
      .withArgs(ethers.ZeroAddress)
  })
})
