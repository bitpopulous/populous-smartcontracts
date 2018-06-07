pragma solidity ^0.4.17;

import "./ERC20Token.sol";
import "./SafeMath.sol";
import "./withAccessManager.sol";


/// @title CurrencyToken contract
contract CurrencyToken is ERC20Token, withAccessManager {

    //EVENTS
    event EventMintTokens(bytes32 currency, uint amount);

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
        EventMintTokens(symbol, amount);
    }

    //Note.. Need to emit event, Pokens destroyed... from system
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

    
    /** @dev Destroys a specified amount of tokens, from a user.
      * @dev The method uses a modifier from withAccessManager contract to only permit populous to use it.
      * @dev The method uses SafeMath to carry out safe token deductions/subtraction.
      * @param amount The amount of tokens to create.
      */
    function destroyTokensFrom(uint amount, address from) public onlyPopulous returns (bool success) {
        if (balances[from] < amount) {
            return false;
        } else {
            balances[from] = SafeMath.safeSub(balances[from], amount);
            totalSupply = SafeMath.safeSub(totalSupply, amount);
            return true;
        }
    }
}