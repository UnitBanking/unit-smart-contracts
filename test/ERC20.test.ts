import { expect } from 'chai'
import { ethers } from 'hardhat'

describe('ER20', () => {
  it('deploy', async () => {
    const erc20 = await ethers.deployContract('ERC20', [], {})
    const address = await erc20.getAddress()
    expect(address.length).to.be.gt(0)
  })

  it('mint', async () => {
    // Arrange
    const erc20 = await ethers.deployContract('ERC20', [], {})
    const [wallet] = await ethers.getSigners()
    const value = BigInt(10)
    const balanceBefore = await erc20.balanceOf(wallet.address)

    // Act
    await erc20.mint(wallet.address, value)
    const balanceAfter = await erc20.balanceOf(wallet.address)

    // Assert
    expect(balanceAfter).to.equal(balanceBefore + value)
  })
})
