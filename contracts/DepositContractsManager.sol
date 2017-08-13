pragma solidity ^0.4.13;

import "./SafeMath.sol";
import "./withAccessManager.sol";
import "./DepositContract.sol";

contract DepositContractsManager is withAccessManager {

    struct Deposit {
        uint deposited;
        uint received;
        bool isReleased;
    }

    struct DepositList {
        Deposit[] list;
        uint deposited;
        uint received;
    }

    // clientId => depositAddress
    mapping (bytes32 => address) depositAddress;
    // clientId => tokenContract => currencySymbol => DepositList
    mapping (bytes32 => mapping(address => mapping(bytes32 => DepositList))) deposits;

    function DepositContractsManager(address _accessManager)
        withAccessManager(_accessManager) { }

    function create(bytes32 clientId)
        onlyPopulous
        returns (address)
    {
        depositAddress[clientId] = new DepositContract(clientId);
        assert(depositAddress[clientId] != 0x0);

        return depositAddress[clientId];
    }

    function getDepositAddress(bytes32 clientId) constant returns (address) {
        return depositAddress[clientId];
    }

    function getActiveDepositList(bytes32 clientId, address tokenContract, bytes32 receiveCurrency) constant returns (uint, uint, uint) {
        return (
            deposits[clientId][tokenContract][receiveCurrency].list.length,
            deposits[clientId][tokenContract][receiveCurrency].deposited,
            deposits[clientId][tokenContract][receiveCurrency].received
        );
    }

    function getActiveDeposit(bytes32 clientId, address tokenContract, bytes32 receiveCurrency, uint depositIndex) constant returns (uint, uint, bool) {
        return (
            deposits[clientId][tokenContract][receiveCurrency].list[depositIndex].deposited,
            deposits[clientId][tokenContract][receiveCurrency].list[depositIndex].received,
            deposits[clientId][tokenContract][receiveCurrency].list[depositIndex].isReleased
        );
    }

    function deposit(bytes32 clientId, address tokenContract, bytes32 receiveCurrency, uint depositAmount, uint receiveAmount)
        onlyPopulous
        returns (bool, uint)
    {
        DepositContract o = DepositContract(depositAddress[clientId]);

        if (SafeMath.safeSub(o.balanceOf(tokenContract), deposits[clientId][tokenContract][receiveCurrency].deposited) == depositAmount) {
            // save new deposit info
            deposits[clientId][tokenContract][receiveCurrency].list.push(Deposit(depositAmount, receiveAmount, false));
            
            // update totals
            deposits[clientId][tokenContract][receiveCurrency].deposited = SafeMath.safeAdd(
                deposits[clientId][tokenContract][receiveCurrency].deposited,
                depositAmount
            );
            deposits[clientId][tokenContract][receiveCurrency].received = SafeMath.safeAdd(
                deposits[clientId][tokenContract][receiveCurrency].received,
                receiveAmount
            );
            return (true, deposits[clientId][tokenContract][receiveCurrency].list.length -1);
        }
        return (false, 0);
    }

    function releaseDeposit(bytes32 clientId, address tokenContract, bytes32 receiveCurrency, address receiver, uint depositIndex)
        onlyPopulous
        returns (bool, uint, uint)
    {
        DepositContract o = DepositContract(depositAddress[clientId]);
        
        if (deposits[clientId][tokenContract][receiveCurrency].list[depositIndex].deposited != 0 &&
            deposits[clientId][tokenContract][receiveCurrency].list[depositIndex].isReleased == false &&
            o.transfer(tokenContract, receiver, deposits[clientId][tokenContract][receiveCurrency].list[depositIndex].deposited)
        ) {
            deposits[clientId][tokenContract][receiveCurrency].list[depositIndex].isReleased = true;

            // update totals
            deposits[clientId][tokenContract][receiveCurrency].deposited = SafeMath.safeSub(
                deposits[clientId][tokenContract][receiveCurrency].deposited,
                deposits[clientId][tokenContract][receiveCurrency].list[depositIndex].deposited
            );
            deposits[clientId][tokenContract][receiveCurrency].received = SafeMath.safeSub(
                deposits[clientId][tokenContract][receiveCurrency].received,
                deposits[clientId][tokenContract][receiveCurrency].list[depositIndex].received
            );
            return (
                true,
                deposits[clientId][tokenContract][receiveCurrency].list[depositIndex].deposited,
                deposits[clientId][tokenContract][receiveCurrency].list[depositIndex].received
            );
        }
        return (false, 0, 0);
    }
}