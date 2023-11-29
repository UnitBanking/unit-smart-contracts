import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { randomBytes } from 'ethers'
import { getPermitBySigOptions, permitBySig } from '../utils'
import { deployBaseTokenFixture } from '../fixtures/deployBaseTokenTestFixture'

describe('BaseToken permit', () => {
  it('permit via signature expired', async () => {
    const { base, owner, other } = await loadFixture(deployBaseTokenFixture)
    await expect(
      base.permit(owner.address, other.address, 1, 1, 1, 1, randomBytes(32), randomBytes(32)),
    ).to.be.revertedWithCustomError(base, 'ERC20PermitSignatureExpired')
  })

  it('permit via invalid signature', async () => {
    const { base, owner, other } = await loadFixture(deployBaseTokenFixture)
    await expect(
      base.permit(owner.address, other.address, 1, 1, Date.now() + 1000, 1, randomBytes(32), randomBytes(32)),
    ).to.be.revertedWithCustomError(base, 'ERC20InvalidPermitSignature')
  })

  it('permit via invalid nonce', async () => {
    const { base, other, owner } = await loadFixture(deployBaseTokenFixture)
    const { expiry, v, r, s } = await getPermitBySigOptions(owner.address, other.address, 1, 0, owner, base)
    await base.permit(owner.address, other.address, 1, 0, expiry, v, r, s)
    await expect(base.permit(owner.address, other.address, 1, 0, expiry, v, r, s)).to.be.revertedWithCustomError(
      base,
      'ERC20InvalidPermitNonce',
    )
  })

  it('permit via signature', async () => {
    const { base, other, owner } = await loadFixture(deployBaseTokenFixture)
    await permitBySig(owner.address, other.address, 1, 0, owner, base)
    expect(await base.allowance(owner.address, other.address)).to.equal(1)
  })
})
