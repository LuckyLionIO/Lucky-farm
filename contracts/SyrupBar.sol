pragma solidity 0.8.7;//"SPDX-License-Identifier: UNLICENSED"

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./LuckyToken.sol";

// SyrupBar with Governance.
contract SyrupBar is ERC20('SyrupBar Token', 'SYRUP'), Ownable {
    
    // The Lucky Token!
    LuckyToken public lucky;

    constructor(
        LuckyToken _lucky
    ) {
        lucky = _lucky;
    }

    // Safe lucky transfer function, just in case if rounding error causes pool to not have enough CAKEs.
    function safeLuckyTransfer(address _to, uint256 _amount) public onlyOwner {
        uint256 luckyBal = lucky.balanceOf(address(this));
        if (_amount > luckyBal) {
            lucky.transfer(_to, luckyBal);
        } else {
            lucky.transfer(_to, _amount);
        }
    }

}
