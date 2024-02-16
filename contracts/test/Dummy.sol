// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract Dummy {
    uint256 public num;

    function setNum(uint256 newNum) external {
        num = newNum;
    }

    receive() external payable {}
}
