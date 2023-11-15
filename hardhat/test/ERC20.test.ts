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
    const totalSupplyBefore = await erc20.totalSupply()

    // Act
    await erc20.mint(wallet.address, value)

    // Assert
    const balanceAfter = await erc20.balanceOf(wallet.address)

    // Assert
    const totalSupplyAfter = await erc20.totalSupply()
    expect(balanceAfter).to.equal(balanceBefore + value)
    expect(totalSupplyAfter).to.equal(totalSupplyBefore + value)
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

  it('burn using allowance', async () => {
    // Arrange
    const [wallet, burner] = await ethers.getSigners()
    const erc20 = await ethers.deployContract('ERC20', [wallet.address], {})
    const mintValue = BigInt(10)
    const burnValue = BigInt(5)
    await erc20.mint(wallet.address, mintValue)
    const balanceBefore = await erc20.balanceOf(wallet.address)
    const approveValue = BigInt(100)

    // Act
    await erc20.approve(burner, approveValue)
    await erc20.connect(burner).burn(wallet.address, burnValue)

    // Assert
    const balanceAfter = await erc20.balanceOf(wallet.address)
    const remainingAllowance = await erc20.allowance(wallet, burner)
    expect(balanceBefore - balanceAfter).to.eq(mintValue - burnValue)
    expect(remainingAllowance).to.eq(approveValue - burnValue)
  })
})
