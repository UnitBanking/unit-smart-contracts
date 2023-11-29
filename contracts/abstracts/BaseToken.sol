// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './ERC20.sol';
import './Mintable.sol';
import './Burnable.sol';
import './Ownable.sol';
import './Proxiable.sol';
import '../interfaces/IERC20Permit.sol';

abstract contract BaseToken is Ownable, Proxiable, ERC20, Mintable, Burnable, IERC20Permit {
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256('EIP712Domain(string name,uint256 chainId,address verifyingContract)');
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)');

    mapping(address account => uint256 nextNonce) public nonces;

    constructor() ERC20() {}

    function initialize() public virtual override {
        _setOwner(msg.sender);
        super.initialize();
    }

    function setMinter(address minter, bool canMint) external onlyOwner {
        _setMinter(minter, canMint);
    }

    function setBurner(address burner, bool canBurn) external onlyOwner {
        _setBurner(burner, canBurn);
    }

    function mint(address receiver, uint256 amount) public virtual override {
        super.mint(receiver, amount);
        _update(address(0), receiver, amount);
    }

    function burn(uint256 amount) public virtual override {
        super.burn(amount);
        _update(msg.sender, address(0), amount);
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        if (block.timestamp > expiry) {
            revert ERC20PermitSignatureExpired(expiry);
        }
        bytes32 domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name())), block.chainid, address(this))
        );
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked('\x19\x01', domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        if (signatory == address(0)) {
            revert ERC20InvalidPermitSignature(signatory);
        }
        if (nonce != nonces[signatory]++) {
            revert ERC20InvalidPermitNonce(nonce);
        }
        _approve(signatory, spender, value, true);
    }
}
