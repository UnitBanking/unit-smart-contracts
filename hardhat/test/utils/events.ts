import { assert } from 'chai'
import { type ContractTransactionResponse, EventLog, Log } from 'ethers'
import { ethers } from 'hardhat'

export async function getEvents(name: string, tx: ContractTransactionResponse) {
  const receipt = await tx.wait()
  assert(receipt)
  return receipt.logs.filter((log) => log instanceof EventLog && log.fragment.name === name) as EventLog[]
}

export async function getHiddenEvents(contract: string, name: string, tx: ContractTransactionResponse) {
  const receipt = await tx.wait()
  assert(receipt)
  const factory = await ethers.getContractFactory(contract)
  const fragment = factory.interface.getEvent(name)
  assert(fragment, `Event ${name} not found in ${contract}`)
  const filteredLog = receipt.logs.filter((log) => log instanceof Log && log.topics[0] === fragment.topicHash)
  return filteredLog.map((log) => factory.interface.decodeEventLog(fragment, log.data, log.topics))
}
