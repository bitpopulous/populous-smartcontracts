pragma solidity ^0.4.13;

import "./ERC23Token.sol";
import "./SafeMath.sol";

contract PopulousToken is ERC23Token {
    bytes32 public name;
    uint8 public decimals;
    bytes32 public symbol;

    function PopulousToken ()
    {
        name = 'Populous Platform';
        decimals = 8;
        symbol = 'PPT';
    }

    function faucet(uint amount) {
        balances[msg.sender] = SafeMath.safeAdd(balances[msg.sender], amount);
        totalSupply = SafeMath.safeAdd(totalSupply, amount);
    }
}