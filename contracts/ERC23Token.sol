/*
https://github.com/ConsenSys/Tokens

Implements ERC 23 Token standard: https://github.com/ethereum/EIPs/issues/223
.*/
pragma solidity ^0.4.8;

import "./iERC20Token.sol";

contract ContractReceiver {
    function tokenFallback(address from, uint amount, bytes data);
}

contract ERC23Token is iERC20Token {

    event ContractTransfer(address _to, uint _value, bytes _data);

    function transfer(address _to, uint _value, bytes _data) returns (bool success) {
        //filtering if the target is a contract with bytecode inside it
        if(isContract(_to)) {
            return transferToContract(_to, _value, _data);
        } else {
            return transferToAddress(_to, _value);
        }
    }

    function transfer(address _to, uint _value) returns (bool success) {
        //A standard function transfer similar to ERC20 transfer with no _data
        if(isContract(_to)) {
            bytes memory emptyData;
            return transferToContract(_to, _value, emptyData);
        } else {
            return transferToAddress(_to, _value);
        }
    }

//function that is called when transaction target is an address
  function transferToAddress(address _to, uint _value) returns (bool success) {
        if (balances[msg.sender] >= _value && _value > 0 && balances[_to] + _value > balances[_to]) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);

            return true;
        } else {
            return false;
        }
  }

//function that is called when transaction target is a contract
  function transferToContract(address _to, uint _value, bytes _data) returns (bool success) {
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

  //assemble the given address bytecode. If bytecode exists then the _addr is a contract.
  function isContract(address _addr) constant returns (bool is_contract) {
      uint length;
      assembly {
            // retrieve the size of the code on target address, this needs assembly
            length := extcodesize(_addr)
        }
        if(length>0)
        {
            return true;
        }
        else
        {
            return false;
        }
    }

    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0 && balances[_to] + _value > balances[_to]) {
            balances[_to] += _value;
            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
            Transfer(_from, _to, _value);
            return true;
        } else { return false; }
    }

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
      return allowed[_owner][_spender];
    }

    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
}
