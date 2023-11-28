import { ethers } from 'hardhat'
import { assert, expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { deployMineFixture } from './fixtures/deployMineFixture'
import { deployBaseTokenWithProxyFixture } from './fixtures/deployBaseTokenTestFixture'
import { getMappingStorageKey } from './utils/getMappingStorageKey'
import { delegateBySig } from './utils'

const SLOT_BYTES = 32
const ADDRESS_BYTES = 20
const UINT32_BYTES = 4

enum BASETOKEN_SLOTS {
  ownerAndInitialized = 0,
  totalSupply,
  balanceOf,
  allowance,
  isMinter,
  isBurner,
}
enum MINETOKEN_SLOTS {
  defaultDelegatee = 6,
  delegatees,
  checkpoints,
  numCheckpoints,
  nonces,
}

describe('Storage', () => {
  describe('as BaseToken, it has correct storage orders', () => {
    it(`slot ${getSlotInfo(BASETOKEN_SLOTS.ownerAndInitialized)}`, async () => {
      const { base, proxyAddress, provider, coder } = await getBaseTokenProxyStorageFixtures()
      const storage = await provider.getStorage(proxyAddress, BASETOKEN_SLOTS.ownerAndInitialized)
      // slot0 packed from right to left
      // initilized (bool, rest bytes) | owner (address, 20 bytes)
      //     0x000000000000000000000000|0000000000000000000000000000000000000000

      const part0 = ethers.dataSlice(storage, 0, SLOT_BYTES - ADDRESS_BYTES) // initialized
      const part0Result = coder.decode(['bool'], ethers.zeroPadValue(part0, SLOT_BYTES))
      expect(await base.initialized()).to.equal(part0Result[0])

      const part1 = ethers.dataSlice(storage, SLOT_BYTES - ADDRESS_BYTES) // owner
      const part1Result = coder.decode(['address'], ethers.zeroPadValue(part1, SLOT_BYTES))
      expect(await base.owner()).to.equal(part1Result[0])
    })

    it(`slot ${getSlotInfo(BASETOKEN_SLOTS.totalSupply)}`, async () => {
      const { base, proxyAddress, provider, coder } = await getBaseTokenProxyStorageFixtures()
      const storage = await provider.getStorage(proxyAddress, BASETOKEN_SLOTS.totalSupply)
      const result = coder.decode(['uint256'], storage)
      expect(await base.totalSupply()).to.equal(result[0])
    })

    it(`slot ${getSlotInfo(BASETOKEN_SLOTS.balanceOf)}`, async () => {
      const { base, proxyAddress, provider, coder, owner, other } = await getBaseTokenProxyStorageFixtures()
      await base.mint(other.address, 105n)

      const ownerStorageKey = getMappingStorageKey(owner.address, BASETOKEN_SLOTS.balanceOf)
      const otherStorageKey = getMappingStorageKey(other.address, BASETOKEN_SLOTS.balanceOf)
      const ownerStorage = await provider.getStorage(proxyAddress, ownerStorageKey)
      const otherStorage = await provider.getStorage(proxyAddress, otherStorageKey)

      const ownerResult = coder.decode(['uint256'], ownerStorage)
      expect(await base.balanceOf(owner.address)).to.equal(ownerResult[0])

      const otherResult = coder.decode(['uint256'], otherStorage)
      expect(await base.balanceOf(other.address)).to.equal(otherResult[0])
    })

    it(`slot ${getSlotInfo(BASETOKEN_SLOTS.allowance)}`, async () => {
      const { base, proxyAddress, provider, coder, owner, other } = await getBaseTokenProxyStorageFixtures()
      await base.approve(other.address, 123n)
      await base.connect(other).approve(owner.address, 321n)

      const ownerStorageKey = getMappingStorageKey(owner.address, BASETOKEN_SLOTS.allowance)
      const otherStorageKey = getMappingStorageKey(other.address, BASETOKEN_SLOTS.allowance)
      const ownerInnerMappingKey = getMappingStorageKey(other.address, ownerStorageKey)
      const otherInnerMappingKey = getMappingStorageKey(owner.address, otherStorageKey)
      const ownerStorage = await provider.getStorage(proxyAddress, ownerInnerMappingKey)
      const otherStorage = await provider.getStorage(proxyAddress, otherInnerMappingKey)

      const ownerResult = coder.decode(['uint256'], ownerStorage)
      expect(await base.allowance(owner.address, other.address)).to.equal(ownerResult[0])

      const otherResult = coder.decode(['uint256'], otherStorage)
      expect(await base.allowance(other.address, owner.address)).to.equal(otherResult[0])
    })

    it(`slot ${getSlotInfo(BASETOKEN_SLOTS.isMinter)}`, async () => {
      const { base, proxyAddress, provider, coder, owner } = await getBaseTokenProxyStorageFixtures()

      const storageKey = getMappingStorageKey(owner.address, BASETOKEN_SLOTS.isMinter)
      const storage = await provider.getStorage(proxyAddress, storageKey)

      const result = coder.decode(['bool'], storage)
      expect(await base.isMinter(owner.address)).to.equal(result[0])
    })

    it(`slot ${getSlotInfo(BASETOKEN_SLOTS.isBurner)}`, async () => {
      const { base, proxyAddress, provider, coder, owner } = await getBaseTokenProxyStorageFixtures()

      const storageKey = getMappingStorageKey(owner.address, BASETOKEN_SLOTS.isBurner)
      const storage = await provider.getStorage(proxyAddress, storageKey)

      const result = coder.decode(['bool'], storage)
      expect(await base.isBurner(owner.address)).to.equal(result[0])
    })
  })
  describe('as MineToken, it has correct storage orders besides ones in BaseToken', () => {
    it(`slot ${getSlotInfo(MINETOKEN_SLOTS.defaultDelegatee)}`, async () => {
      const { mine, proxyAddress, provider, coder } = await getMineTokenProxyStorageFixtures()
      const storage = await provider.getStorage(proxyAddress, MINETOKEN_SLOTS.defaultDelegatee)
      const result = coder.decode(['address'], storage)
      expect(await mine.defaultDelegatee()).to.equal(result[0])
    })

    it(`slot ${getSlotInfo(MINETOKEN_SLOTS.delegatees)}`, async () => {
      const { mine, proxyAddress, provider, coder, owner, other } = await getMineTokenProxyStorageFixtures()
      await mine.delegate(other.address)
      const storageKey = getMappingStorageKey(owner.address, MINETOKEN_SLOTS.delegatees)
      const storage = await provider.getStorage(proxyAddress, storageKey)
      const result = coder.decode(['address'], storage)
      expect(await mine.delegatees(owner.address)).to.equal(result[0])
    })

    it(`slot ${getSlotInfo(MINETOKEN_SLOTS.checkpoints)}`, async () => {
      const { mine, proxyAddress, provider, coder, other } = await getMineTokenProxyStorageFixtures()
      const tx = await mine.delegate(other.address)
      assert(tx.blockNumber, 'tx.blockNumber is null')
      const checkpointIndex = 0
      const checkpointIndexHex = ethers.hexlify(new Uint8Array([checkpointIndex]))
      const checkpoint = await mine.checkpoints(other.address, 0)

      const storageKey = getMappingStorageKey(other.address, MINETOKEN_SLOTS.checkpoints)
      const innerMappingKey = getMappingStorageKey(checkpointIndexHex, storageKey)
      const storage = await provider.getStorage(proxyAddress, innerMappingKey)

      const part0 = ethers.dataSlice(storage, 0, SLOT_BYTES - UINT32_BYTES) // votes
      const part0Result = coder.decode(['uint96'], ethers.zeroPadValue(part0, SLOT_BYTES))
      expect(checkpoint.votes).to.equal(part0Result[0])

      const part1 = ethers.dataSlice(storage, SLOT_BYTES - UINT32_BYTES) // fromBlock
      const part1Result = coder.decode(['uint32'], ethers.zeroPadValue(part1, SLOT_BYTES))
      expect(checkpoint.fromBlock).to.equal(part1Result[0])
    })

    it(`slot ${getSlotInfo(MINETOKEN_SLOTS.numCheckpoints)}`, async () => {
      const { mine, proxyAddress, provider, coder, other, another } = await getMineTokenProxyStorageFixtures()
      await mine.mint(another.address, 356791)
      await mine.connect(another).delegate(other.address)
      await mine.delegate(other.address)
      const storageKey = getMappingStorageKey(other.address, MINETOKEN_SLOTS.numCheckpoints)
      const storage = await provider.getStorage(proxyAddress, storageKey)
      const result = coder.decode(['uint32'], storage)
      expect(await mine.numCheckpoints(other.address)).to.equal(result[0])
    })

    it(`slot ${getSlotInfo(MINETOKEN_SLOTS.nonces)}`, async () => {
      const { mine, proxyAddress, provider, coder, owner, other, another } = await getMineTokenProxyStorageFixtures()
      await delegateBySig(0, owner, other.address, mine)
      await delegateBySig(1, owner, another.address, mine)
      const storageKey = getMappingStorageKey(owner.address, MINETOKEN_SLOTS.nonces)
      const storage = await provider.getStorage(proxyAddress, storageKey)
      const result = coder.decode(['uint256'], storage)
      expect(await mine.nonces(owner.address)).to.equal(result[0])
    })
  })
})

async function getBaseTokenProxyStorageFixtures() {
  const { base, proxy, owner, other } = await loadFixture(deployBaseTokenWithProxyFixture)
  const proxyAddress = await proxy.getAddress()
  const provider = owner.provider
  const coder = ethers.AbiCoder.defaultAbiCoder()
  return { base, proxy, owner, other, proxyAddress, provider, coder }
}

async function getMineTokenProxyStorageFixtures() {
  const { mine, proxy, owner, other, another } = await loadFixture(deployMineFixture)
  const proxyAddress = await proxy.getAddress()
  const provider = owner.provider
  const coder = ethers.AbiCoder.defaultAbiCoder()
  return { mine, proxy, owner, other, another, proxyAddress, provider, coder }
}

function getSlotInfo(slot: number) {
  return `${slot}: ${BASETOKEN_SLOTS[slot] || MINETOKEN_SLOTS[slot]}`
}
