pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract LuckyToken is ERC20, Pausable, Ownable {
    
    string private _name = "Lucky";
    string private _symbol = "LUCKY";
    uint8 private _decimals = 8;
    
    uint256 private constant FAIRLAUNCH = 1 * 1000000 * 10**8; //1 * 1000000 * 10**_decimals;
    uint256 private constant WARCHEST = 5 * 1000000 * 10**8;
    uint256 private constant ECOSYSTEM = 20 * 1000000 * 10**8;
    uint256 private constant CAP = 100 * 1000000 * 10**8; //max supply
    
    address Owner;
    address WarChest;
    address Ecosystem;

    constructor (address _Owner, address _Warchest, address _Ecosystem) ERC20(_name, _symbol) { 
        //set wallet address
        Owner = _Owner;
        WarChest = _Warchest;
        Ecosystem = _Ecosystem;

        //mint to Owner's Wallet for Fairlunch
        _mint(_Owner, FAIRLAUNCH);
        //mint to WarChest's Wallet
        _mint(_Warchest, WARCHEST);
        //mint to Ecosystem's Wallet
        _mint(_Ecosystem, ECOSYSTEM);
        //transfer to real owner
        transferOwnership(_Owner);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view virtual returns (uint256) {
        return CAP;
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