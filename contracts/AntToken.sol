pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract AntToken is ERC20, Pausable, Ownable {
    
    string private _name = "Ant";
    string private _symbol = "Ant";
    uint8 private _decimals = 8;
    
    uint256 private constant _FairLunch = 1 * 1000000 * 10**8; //1 * 1000000 * 10**_decimals;
    uint256 private constant _WarChest = 5 * 1000000 * 10**8;
    uint256 private constant _Ecosystem = 20 * 1000000 * 10**8;
    uint256 private constant _cap = 100 * 1000000 * 10**8; //max supply
    
    address constant Owner = 0x49aE5637252FD7d716484E6D9488596322653d80;
    address constant WarChest = 0xf5330e3730a30C2f84637A948423A08486391B6a;
    address constant Ecosystem = 0xad20a284e4bCF0D1f3c24D7b3ad814F07b4A1094;

    constructor () ERC20(_name, _symbol) { 
        //mint to Owner's Wallet for Fairlunch
        _mint(Owner, _FairLunch);
        //mint to WarChest's Wallet
        _mint(WarChest, _WarChest);
        //mint to Ecosystem's Wallet
        _mint(Ecosystem, _Ecosystem);
        transferOwnership(Owner);
    }
    
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view virtual returns (uint256) {
        return _cap;
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
    
    /**
     * @dev See {ERC20-_mint}.
     */
    function _mint(address _to, uint256 _amount) internal virtual onlyOwner override {
        require(ERC20.totalSupply() + _amount <= cap(), "ERC20Capped: cap exceeded");
        super._mint(_to, _amount);
    }
    
      /**
     * @dev Pauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() public virtual onlyOwner {
        _pause();
    }
    
    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        require(!paused(), "ERC20Pausable: token transfer while paused");
    }
}
