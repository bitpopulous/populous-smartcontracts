/*
https://github.com/ConsenSys/Tokens

Implements ERC 23 Token standard: https://github.com/ethereum/EIPs/issues/223
.*/
pragma solidity ^0.4.17;

import "./iERC20Token.sol";

/// @title ContractReceiver contract
contract ContractReceiver {

    /** @dev A function to handle token transfers that is called from token.
      * @dev contract when token holder is sending tokens.
      * @dev The function works like fallback function for Ether transactions and returns nothing.
      * @param from Token sender.
      * @param amount The amount of incoming tokens.
      * @param data The attached data similar to data in Ether transactions.
      * @return The function returns nothing.
      */
    function tokenFallback(address from, uint amount, bytes data) public;
}

/// @title ERC23Token contract
/// @notice Implements the ERC223 token standard
/// @notice See https://github.com/ethereum/EIPs/issues/223
contract ERC23Token is iERC20Token {

    // EVENTS

    event ContractTransfer(address _to, uint _value, bytes _data);

    // NON-CONSTANT METHODS


    /** @dev Transfers tokens to a specified address from the message sender.
      * @dev This function must transfer tokens and invoke the function tokenFallback (address, uint256, bytes) 
      * @dev in _to, if _to is a contract. If the tokenFallback function is not implemented 
      * @dev in _to (receiver contract), then the transaction must fail and the transfer of tokens should not occur.
      * @param _to The address to send the tokens to.
      * @param _value The amount of tokens to transfer.
      * @param _data The payload/data that can accompany a transaction.
      * @return success A boolean value True/False to indicate a successful transfer
      */
    function transfer(address _to, uint _value, bytes _data) public returns (bool success) {
        //filtering if the target is a contract with bytecode inside it
        if(isContract(_to)) {
            return transferToContract(_to, _value, _data);
        } else {
            return transferToAddress(_to, _value);
        }
    }

    /** @dev Transfers tokens to a specified address from the message sender.
      * @dev This function must transfer tokens and invoke the function tokenFallback (address, uint256, bytes) 
      * @dev in _to, if _to is a contract. If the tokenFallback function is not implemented 
      * @dev in _to (receiver contract), then the transaction must fail and the transfer of tokens should not occur.
      * @param _to The address to send the tokens to.
      * @param _value The amount of tokens to transfer.
      * @return success A boolean value True/False to indicate a successful transfer
      */
    function transfer(address _to, uint _value) public returns (bool success) {
        //A standard function transfer similar to ERC20 transfer with no _data
        if(isContract(_to)) {
            bytes memory emptyData;
            return transferToContract(_to, _value, emptyData);
        } else {
            return transferToAddress(_to, _value);
        }
    }

    /** @dev The transferToAddress function is called when transaction target is an address.
      * @param _to The address to send the tokens to.
      * @param _value The amount of tokens to transfer.
      * @return success A boolean value True/False to indicate a successful transfer
      */
    function transferToAddress(address _to, uint _value) public returns (bool success) {
        if (balances[msg.sender] >= _value && _value > 0 && balances[_to] + _value > balances[_to]) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);

            return true;
        } else {
            return false;
        }
    }

    /** @dev The transferToContract function is called when transaction target is a contract.
      * @param _to The address to send the tokens to.
      * @param _value The amount of tokens to transfer.
      * @param _data The payload/data that can accompany a transaction.
      * @return success A boolean value True/False to indicate a successful transfer
      */
    function transferToContract(address _to, uint _value, bytes _data) public returns (bool success) {
        if (balances[msg.sender] >= _value && _value > 0 && balances[_to] + _value > balances[_to]) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            ContractReceiver reciever = ContractReceiver(_to);
            reciever.tokenFallback(msg.sender, _value, _data);
            Transfer(msg.sender, _to, _value);
            ContractTransfer(_to, _value, _data);

            return true;
        } else {
            return false;
        }
    }

    /** @dev Assembles the given address bytecode. If bytecode exists then the _addr is a contract.
      * @param _addr The specified address to check.
      * @return is_contract A boolean value True/False to indicate whether _addr is a conract or not.
      */
    function isContract(address _addr) public view returns (bool is_contract) {
        uint length;
        assembly {
            // retrieve the size of the code on target address, this needs assembly
            length := extcodesize(_addr)
        }
        if (length>0) {
            return true;
        }else {
            return false;
        }
    }

    /** @dev Transfers tokens to an address on behalf of the owner of the tokens.
      * @param _from The address to debit.
      * @param _to The address to credit.
      * @param _value The amount to send.
      * @return success A boolean value True/False to indicate whether the transaction was successful or not.
      */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0 && balances[_to] + _value > balances[_to]) {
            balances[_to] += _value;
            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
            Transfer(_from, _to, _value);
            return true;
        } else {return false;}
    }

    /** @dev Allows token owner to approve another address owner to spend their tokens on their behalf.
      * @param _spender The allowed address.
      * @param _value The allowed amount.
      * @return success A boolean value True/False to indicate whether the transaction was successful or not.
      */
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    // CONSTANT METHODS

    /** @dev Checks the balance of an address without changing the state of the blockchain.
      * @param _owner The address to check.
      * @return balance An unsigned integer representing the token balance of the address.
      */
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    /** @dev Checks for the balance of the tokens of that which the owner had approved another address owner to spend.
      * @param _owner The address of the token owner.
      * @param _spender The address of the allowed spender.
      * @return remaining An unsigned integer representing the remaining approved tokens.
      */
    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
      return allowed[_owner][_spender];
    }


    // FIELDS

    // This variable is used to store the balance of
    // addresses. The balance is retrieved using the address as a key
    mapping (address => uint256) balances;
    // This variable 'allowed'
    // stores an unsigned integer representing an amount owned and
    // approved by an address/wallet owner which other address owners have
    // been allowed to spend.
    mapping (address => mapping (address => uint256)) allowed;
}