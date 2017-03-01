pragma solidity ^0.4.8;

import "./StandardToken.sol";
import "./SafeMath.sol";
import "./withAccessManager.sol";

contract CurrencyToken is StandardToken, withAccessManager {
    bytes32 public name;
    uint8 public decimals;                //How many decimals to show. ie. There could 1000 base units with 3 decimals. Meaning 0.980 SBX = 980 base units. It's like comparing 1 wei to 1 ether.
    bytes32 public symbol;                 //An identifier: eg SBX

    function CurrencyToken (
        address _accessManager,
        bytes32 _tokenName,
        uint8 _decimalUnits,
        bytes32 _tokenSymbol)
        withAccessManager(_accessManager)
    {
        name = _tokenName;                                   // Set the name for display purposes
        decimals = _decimalUnits;                            // Amount of decimals for display purposes
        symbol = _tokenSymbol;                               // Set the symbol for display purposes
    }

    function mintTokens(uint amount) onlyPopulous returns (bool success) {
        balances[AM.populous()] = SafeMath.safeAdd(balances[AM.populous()], amount);
        totalSupply = SafeMath.safeAdd(totalSupply, amount);
    }

    function destroyTokens(uint amount) onlyPopulous returns (bool success) {
        if (balances[AM.populous()] < amount) {
            return false;
        } else {
            balances[AM.populous()] = SafeMath.safeSub(balances[AM.populous()], amount);
            totalSupply = SafeMath.safeSub(totalSupply, amount);
            
            return true;
        }
    }
}