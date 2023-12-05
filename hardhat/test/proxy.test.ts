import { Log, ethers as e } from 'ethers'
import { ethers } from 'hardhat'
import { assert, expect } from 'chai'
import { proxyFixture } from './fixtures/proxyFixture'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { FakeAddress } from './utils'
import { ProxiableTest__factory } from '../build/types'

describe('Proxy', () => {
  it('can be proxied', async () => {
    const [owner] = await ethers.getSigners()
    const factory = await ethers.getContractFactory('ProxiableTest', { signer: owner })
    const contract = await factory.deploy()
    const contractAddress = await contract.getAddress()

    const initialize = factory.interface.encodeFunctionData('initialize', [])
    const proxy = await ethers.deployContract('Proxy', [owner.address], { signer: owner })

    const tx = await proxy.upgradeToAndCall(contractAddress, initialize)

    // InitializedBy event is in sub delegatedCall
    const eventFragment = factory.interface.getEvent('InitializedBy')
    assert(eventFragment)
    const receipt = await tx.wait()
    assert(receipt)

    const filteredLog = receipt.logs.filter((log) => log instanceof Log && log.topics[0] === eventFragment.topicHash)
    expect(filteredLog.length).to.equal(1)
    const decodedArguments = factory.interface.decodeEventLog(eventFragment, filteredLog[0].data, filteredLog[0].topics)
    expect(decodedArguments[0]).to.equal(owner.address)
  })

  it('can output implementation address', async () => {
    const { contractAddress, proxy } = await loadFixture(proxyFixture)
    const implementationAddress = await proxy.implementation()
    expect(contractAddress).to.equal(implementationAddress)
  })

  it('can upgrade', async () => {
    const { proxy, proxyAddress, owner } = await loadFixture(proxyFixture)

    const upgraded = await ethers.deployContract('ProxiableUpgradedTest', { signer: owner })
    const upgradedAddress = await upgraded.getAddress()
    await expect(proxy.upgradeTo(upgradedAddress)).to.emit(proxy, 'Upgraded').withArgs(upgradedAddress)

    const proxyAsUpgraded = ProxiableTest__factory.connect(proxyAddress, owner)
    expect(await proxyAsUpgraded.initialized()).to.equal(true)
    expect(await proxyAsUpgraded.feature()).to.equal('Upgraded Feature Output')
  })

  it('reverts when upgrade if not admin', async () => {
    const { proxy, other } = await loadFixture(proxyFixture)
    await expect(proxy.connect(other).upgradeTo(FakeAddress)).to.revertedWithCustomError(
      proxy,
      'ProxyUnauthorizedAdmin'
    )
  })

  it('reverts when upgrade if address is zero', async () => {
    const { proxy } = await loadFixture(proxyFixture)
    await expect(proxy.upgradeTo(e.ZeroAddress))
      .to.revertedWithCustomError(proxy, 'ProxyInvalidImplementation')
      .withArgs(e.ZeroAddress)
  })

  it('reverts when upgrade to same address', async () => {
    const { proxy, contractAddress } = await loadFixture(proxyFixture)
    await expect(proxy.upgradeTo(contractAddress)).to.revertedWithCustomError(proxy, 'ProxySameValueAlreadySet')
  })

  it('can change admin', async () => {
    const { proxy, other } = await loadFixture(proxyFixture)
    await proxy.changeAdmin(other.address)
    await expect(proxy.connect(other).upgradeTo(FakeAddress)).to.not.revertedWithCustomError(
      proxy,
      'ProxyUnauthorizedAdmin'
    )
  })

  it('reverts when changeAdmin if not admin', async () => {
    const { proxy, other } = await loadFixture(proxyFixture)
    await expect(proxy.connect(other).changeAdmin(other.address)).to.revertedWithCustomError(
      proxy,
      'ProxyUnauthorizedAdmin'
    )
  })

  it('reverts when changeAdmin if address is zero', async () => {
    const { proxy } = await loadFixture(proxyFixture)
    await expect(proxy.changeAdmin(e.ZeroAddress))
      .to.revertedWithCustomError(proxy, 'ProxyInvalidAdmin')
      .withArgs(e.ZeroAddress)
  })

  it('reverts when changeAdmin to same address', async () => {
    const { proxy, owner } = await loadFixture(proxyFixture)
    await expect(proxy.changeAdmin(owner.address)).to.revertedWithCustomError(proxy, 'ProxySameValueAlreadySet')
  })

  it('reverts when initialize implementation again after upgrade', async () => {
    const { proxyAsContract } = await loadFixture(proxyFixture)
    await expect(proxyAsContract.initialize()).to.revertedWithCustomError(
      proxyAsContract,
      'ProxiableAlreadyInitialized'
    )
  })
})
