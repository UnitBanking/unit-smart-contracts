import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import {
  DEFAULT_AUCTION_INTERVAL,
  DEFAULT_SETTLE_TIME,
  deployMineAuctionFixture,
} from '../fixtures/deployMineAuctionFixture'
import { expect } from 'chai'
import { getEvents } from '../utils'
import { deployBaseTokenFixture } from '../fixtures/deployBaseTokenTestFixture'

describe('Mine Auctions', () => {
  it('can bid', async () => {
    const { auction, owner } = await loadFixture(deployMineAuctionFixture)
    const { base } = await deployBaseTokenFixture()
    await base.approve(auction.address, 1000n)
    const tx = await auction.bid(100)
    const events = await getEvents('AuctionStarted', tx)
    await expect(tx)
      .to.emit(auction, 'AuctionStarted')
      .withArgs(0, events[0].args[1], DEFAULT_SETTLE_TIME, DEFAULT_AUCTION_INTERVAL)
      .to.emit(auction, 'AuctionBid')
      .withArgs(0, owner.address, 100n)
  })
})
