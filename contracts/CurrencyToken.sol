pragma solidity ^0.4.8;

import "./StandardToken.sol";

contract CurrencyToken is StandardToken {
    address owner;
    string public name;
    uint8 public decimals;                //How many decimals to show. ie. There could 1000 base units with 3 decimals. Meaning 0.980 SBX = 980 base units. It's like comparing 1 wei to 1 ether.
    string public symbol;                 //An identifier: eg SBX

    function CurrencyToken(
        string _tokenName,
        uint8 _decimalUnits,
        string _tokenSymbol
        ) {
        owner = msg.sender;
        name = _tokenName;                                   // Set the name for display purposes
        decimals = _decimalUnits;                            // Amount of decimals for display purposes
        symbol = _tokenSymbol;                               // Set the symbol for display purposes
    }
    
    modifier onlyOwner() {
        if (msg.sender != owner) { throw; }
        _;
    }
    
    function mintTokens(int amount) onlyOwner {
        balances[owner] += uint(amount);
    }

    function destroyTokens(int amount) onlyOwner returns (bool success) {
        if (balances[owner] < uint(amount)) {
            return false;
        } else {
            balances[owner] -= uint(amount);
            return true;
        }
    }
}