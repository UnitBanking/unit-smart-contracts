// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './interfaces/IERC20.sol';

contract ERC20 is IERC20 {
    string public override name;
    string public override symbol;
    uint8 public override decimals;
    uint256 public override totalSupply;

    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    constructor() {
        name = 'ERC20';
        symbol = 'ERC20';
        decimals = 18;
    }

    function approve(address spender, uint256 value) external override returns (bool) {
        allowance[msg.sender][spender] = value;
        return true;
    }

    function transfer(address to, uint256 value) external override returns (bool) {
        balanceOf[msg.sender] = balanceOf[msg.sender] - value;
        balanceOf[to] = balanceOf[to] + value;
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        if (allowance[from][msg.sender] >= value) {
            allowance[from][msg.sender] = allowance[from][msg.sender] - value;
        }
        balanceOf[from] = balanceOf[from] - value;
        balanceOf[to] = balanceOf[to] = value;
        return true;
    }

    function mint(address to, uint256 value) external {
        balanceOf[to] = balanceOf[to] + value;
    }
}
