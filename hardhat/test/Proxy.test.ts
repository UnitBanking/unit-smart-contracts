import { ethers as e } from 'ethers'
import { ethers } from 'hardhat'
import { expect } from 'chai'
import { proxyFixture } from './fixtures/proxyFixture'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { FakeAddress } from './utils'
import { ProxiableContract__factory } from '../build/types'

describe('Proxy', () => {
  it('can output implementation address', async () => {
    const { contractAddress, proxy } = await loadFixture(proxyFixture)
    const implementationAddress = await proxy.implementation()
    expect(contractAddress).to.equal(implementationAddress)
  })

  it('can upgrade', async () => {
    const { proxy, proxyAddress, owner } = await loadFixture(proxyFixture)

    const upgraded = await ethers.deployContract('ProxiableContractUpgraded', { signer: owner })
    const upgradedAddress = await upgraded.getAddress()
    await expect(proxy.upgradeTo(upgradedAddress)).to.emit(proxy, 'Upgraded').withArgs(upgradedAddress)

    const proxyAsUpgraded = ProxiableContract__factory.connect(proxyAddress, owner)
    expect(await proxyAsUpgraded.initialized()).to.equal(true)
    expect(await proxyAsUpgraded.feature()).to.equal('Upgraded Feature Output')
  })

  it('reverts when upgrade if not admin', async () => {
    const { proxy, other } = await loadFixture(proxyFixture)
    await expect(proxy.connect(other).upgradeTo(FakeAddress)).to.revertedWithCustomError(
      proxy,
      'UpgradableUnauthorized',
    )
  })

  it('reverts when upgrade if address is zero', async () => {
    const { proxy } = await loadFixture(proxyFixture)
    await expect(proxy.upgradeTo(e.ZeroAddress))
      .to.revertedWithCustomError(proxy, 'UpgradableInvalidImplementation')
      .withArgs(e.ZeroAddress)
  })

  it('reverts when upgrade to same address', async () => {
    const { proxy, contractAddress } = await loadFixture(proxyFixture)
    await expect(proxy.upgradeTo(contractAddress)).to.revertedWithCustomError(proxy, 'UpgradableDuplicatedOperation')
  })

  it('can change admin', async () => {
    const { proxy, other } = await loadFixture(proxyFixture)
    await proxy.changeAdmin(other.address)
    await expect(proxy.connect(other).upgradeTo(FakeAddress)).to.not.revertedWithCustomError(
      proxy,
      'UpgradableUnauthorized',
    )
  })

  it('reverts when changeAdmin if not admin', async () => {
    const { proxy, other } = await loadFixture(proxyFixture)
    await expect(proxy.connect(other).changeAdmin(other.address)).to.revertedWithCustomError(
      proxy,
      'UpgradableUnauthorized',
    )
  })

  it('reverts when changeAdmin if address is zero', async () => {
    const { proxy } = await loadFixture(proxyFixture)
    await expect(proxy.changeAdmin(e.ZeroAddress))
      .to.revertedWithCustomError(proxy, 'UpgradableInvalidAdmin')
      .withArgs(e.ZeroAddress)
  })

  it('reverts when changeAdmin to same address', async () => {
    const { proxy, owner } = await loadFixture(proxyFixture)
    await expect(proxy.changeAdmin(owner.address)).to.revertedWithCustomError(proxy, 'UpgradableDuplicatedOperation')
  })

  it('reverts when initialize implementation again after upgrade', async () => {
    const { proxyAsContract } = await loadFixture(proxyFixture)
    await expect(proxyAsContract.initialize()).to.revertedWithCustomError(proxyAsContract, 'ProxiableAlreadyDelegated')
  })
})
