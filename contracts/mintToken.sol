pragma solidity ^0.4.17;

import "./ERC20Token.sol";
import "./SafeMath.sol";


/// @title PopulousToken contract
contract PopulousToken is ERC20Token {

    // FIELDS

    // Non-constant token specific fields
    bytes32 public name;
    uint8 public decimals;
    bytes32 public symbol;

    // NON-CONSTANT METHODS
    
    function PopulousToken () public {
        name = "Populous Platform";
        decimals = 8;
        symbol = "PPT";
    }

    function faucet(uint amount) public {
        balances[msg.sender] = SafeMath.safeAdd(balances[msg.sender], amount);
        totalSupply = SafeMath.safeAdd(totalSupply, amount);
    }
}