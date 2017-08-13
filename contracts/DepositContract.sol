pragma solidity ^0.4.13;

import "./iERC20Token.sol";

contract DepositContract {

    bytes32 clientId;
    address manager;

    modifier onlyManager() {
        require(msg.sender == manager);
        _;
    }

    function DepositContract(bytes32 _clientId) {
        clientId = _clientId;
        manager = msg.sender;
    }

    function balanceOf(address tokenContract) constant returns (uint) {
        return iERC20Token(tokenContract).balanceOf(this);
    }

    function transfer(address tokenContract, address _to, uint256 _value) onlyManager returns (bool success) {
        return iERC20Token(tokenContract).transfer(_to, _value);
    }

}