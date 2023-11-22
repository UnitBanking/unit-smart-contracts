// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

contract Deployer {
    event Deployed(address _address);
    
    error DeployerEmptyBytecode();
    error DeployerFailedDeployment(address _address);

    function deploy(bytes memory bytecode, uint256 salt) external {
        if (bytecode.length == 0) {
            revert DeployerEmptyBytecode();
        }
        address _address;
        uint256 size;
        assembly {
            _address := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            size := extcodesize(_address)
        }
        if (size == 0) {
            revert DeployerFailedDeployment(_address);
        }
        emit Deployed(_address);
    }
}
