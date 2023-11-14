import { expect } from 'chai'
import { ethers } from 'hardhat'

describe('ER20', () => {
  it('deploy', async () => {
    // Arrange
    const [wallet] = await ethers.getSigners()

    // Act
    const erc20 = await ethers.deployContract('ERC20', [wallet.address], {})

    // Assert
    const address = await erc20.getAddress()
    expect(address.length).to.be.gt(0)
  })

  it('mint', async () => {
    // Arrange
    const [wallet] = await ethers.getSigners()
    const erc20 = await ethers.deployContract('ERC20', [wallet.address], {})
    const value = BigInt(10)
    const balanceBefore = await erc20.balanceOf(wallet.address)

    // Act
    await erc20.mint(wallet.address, value)

    // Assert
    const balanceAfter = await erc20.balanceOf(wallet.address)
    expect(balanceAfter).to.equal(balanceBefore + value)
  })

  it('burn', async () => {
    // Arrange
    const [wallet] = await ethers.getSigners()
    const erc20 = await ethers.deployContract('ERC20', [wallet.address], {})
    const mintValue = BigInt(10)
    const burnValue = BigInt(5)
    await erc20.mint(wallet.address, mintValue)
    const balanceBefore = await erc20.balanceOf(wallet.address)

    // Act
    await erc20.burn(wallet.address, burnValue)

    // Assert
    const balanceAfter = await erc20.balanceOf(wallet.address)
    expect(balanceBefore - balanceAfter).to.eq(mintValue - burnValue)
  })
})
