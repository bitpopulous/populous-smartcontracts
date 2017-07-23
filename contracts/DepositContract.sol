pragma solidity ^0.4.8;

import "./iERC20Token.sol";

contract DepositContract {

    address manager;
    iERC20Token tokenContract;

    modifier onlyManager() {
        if (msg.sender != manager) throw;
        _;
    }

    function DepositContract(address tokenContractAddress) {
        manager = msg.sender;
        tokenContract = iERC20Token(tokenContractAddress);
    }

    function balanceOf() constant returns (uint) {
        return tokenContract.balanceOf(this);
    }

    function transfer(address _to, uint256 _value) onlyManager returns (bool success) {
        return tokenContract.transfer(_to, _value);
    }

}