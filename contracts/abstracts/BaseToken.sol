// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

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
        keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 expiry)');

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

    function burnFrom(address from, uint256 amount) public virtual override {
        super.burnFrom(from, amount);
        _spendAllowance(from, msg.sender, amount);
        _update(from, address(0), amount);
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
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
        uint256 nonce = nonces[owner]++;
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked('\x19\x01', domainSeparator, structHash));
        address signer = ecrecover(digest, v, r, s);
        if (signer != owner) {
            revert ERC20InvalidSigner(signer, owner);
        }
        _approve(signer, spender, value, true);
    }
}
