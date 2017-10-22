pragma solidity ^0.4.17;

import "./ERC23Token.sol";
import "./SafeMath.sol";
import "./withAccessManager.sol";


/// @title CurrencyToken contract
contract CurrencyToken is ERC23Token, withAccessManager {

    // FIELDS

    bytes32 public name;// token name, e.g, pounds for fiat UK pounds.
    uint8 public decimals;// How many decimals to show. ie. There could 1000 base units with 3 decimals. Meaning 0.980 SBX = 980 base units. It's like comparing 1 wei to 1 ether.
    bytes32 public symbol;// An identifier: eg SBX.


    // NON-CONSTANT METHODS
    
    /** @dev Creates a new currency/token.
      * @param _accessManager The accessManage contract address.
      * @param _decimalUnits The decimal units/places the token can have.
      * @param _tokenSymbol The token's symbol, e.g., GBP.
      * @return p The calculated perimeter.
      */
    function CurrencyToken (
        address _accessManager,
        bytes32 _tokenName,
        uint8 _decimalUnits,
        bytes32 _tokenSymbol)
        public
        withAccessManager(_accessManager)
    {
        name = _tokenName; // Set the name for display purposes
        decimals = _decimalUnits; // Amount of decimals for display purposes
        symbol = _tokenSymbol; // Set the symbol for display purposes
    }

    /** @dev Mints/Generates a specified amount of tokens 
      * @dev The method uses a modifier from withAccessManager contract to only permit populous to use it.
      * @dev The method uses SafeMath to carry out safe additions.
      * @param amount The amount of tokens to create.
      */
    function mintTokens(uint amount) public onlyPopulous {
        balances[AM.populous()] = SafeMath.safeAdd(balances[AM.populous()], amount);
        totalSupply = SafeMath.safeAdd(totalSupply, amount);
    }

    /** @dev Destroys a specified amount of tokens 
      * @dev The method uses a modifier from withAccessManager contract to only permit populous to use it.
      * @dev The method uses SafeMath to carry out safe token deductions/subtraction.
      * @param amount The amount of tokens to create.
      */
    function destroyTokens(uint amount) public onlyPopulous returns (bool success) {
        if (balances[AM.populous()] < amount) {
            return false;
        } else {
            balances[AM.populous()] = SafeMath.safeSub(balances[AM.populous()], amount);
            totalSupply = SafeMath.safeSub(totalSupply, amount);
            return true;
        }
    }
}