pragma solidity ^0.4.17;

import "./SafeMath.sol";
import "./withAccessManager.sol";
import "./DepositContract.sol";


/// @title DepositCountractsManager contract
contract DepositContractsManager is withAccessManager {
    // FIELDS

    // This variable represents deposits 
    // and their related information i.e., amount deposited and received
    // and a boolean isReleased indicating whether the deposit has been released.
    struct Deposit {
        uint deposited;
        uint received;
        bool isReleased;
    }

    // This variable will be used to store a list of deposits
    // together with the total amount deposited and received for a deposit contract.
    struct DepositList {
        Deposit[] list;
        uint deposited;
        uint received;
    }

    // This variable will be used to keep track of client IDs and
    // their deposit addresses
    // clientId => depositAddress
    mapping (bytes32 => address) depositAddress;

    // The variable 'deposits'
    // links a bytes32 client ID to a token contract address linked to a currency symbol 
    // linked to a DepositList object type declared above.
    // clientId => tokenContract => currencySymbol => DepositList
    mapping (bytes32 => mapping(address => mapping(bytes32 => DepositList))) deposits;


    // NON-CONSTANT METHODS

    // The constructor method called when this contract instance is deployed 
    // using a modifier the _accessManager address
    function DepositContractsManager(address _accessManager) public
        withAccessManager(_accessManager) { }

    /** @dev Creates a new 'depositAddress' gotten from deploying a deposit contract linked to a client ID
      * @param clientId The bytes32 client ID
      * @return address The address of the deployed deposit contract instance.
      */
    function create(bytes32 clientId) public
        onlyPopulous
        returns (address)
    {
        depositAddress[clientId] = new DepositContract(clientId);
        assert(depositAddress[clientId] != 0x0);

        return depositAddress[clientId];
    }

    /** @dev Deposits an amount of tokens linked to a client ID.
      * @param clientId The client ID.
      * @param tokenContract The token contract.
      * @param receiveCurrency The currency symbol.
      * @param depositAmount The deposit amount.
      * @param receiveAmount The receive amount.
      * @return bool boolean value indicating whether or not a deposit transaction has been made with success.
      * @return uint The updated number of deposits.
      */
    function deposit(bytes32 clientId, address tokenContract, bytes32 receiveCurrency, uint depositAmount, uint receiveAmount)
        public
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
            return (true, deposits[clientId][tokenContract][receiveCurrency].list.length - 1);
        }
        return (false, 0);
    }

    /** @dev Releases a deposit to an address/wallet.
      * @param clientId The client ID.
      * @param tokenContract The token contract.
      * @param receiveCurrency The currency symbol.
      * @param receiver The address/wallet of the receiver.
      * @param depositIndex The index/location of a specific deposit in the declared deposit list above.
      * @return bool boolean value indicating whether or not a deposit has been updated with success.
      * @return uint The token amount deposited.
      * @return uint The token amount received.
      */
    function releaseDeposit(bytes32 clientId, address tokenContract, bytes32 receiveCurrency, address receiver, uint depositIndex)
        public
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


    // CONSTANT METHODS


    /** @dev Gets the deposit address linked to a given client ID.
      * @param clientId The client ID.
      * @return address The deposit address.
      */
    function getDepositAddress(bytes32 clientId) public view returns (address) {
        return depositAddress[clientId];
    }

    /** @dev Gets the deposit address linked to a given client ID.
      * @param clientId The client ID.
      * @param tokenContract The token contract
      * @param receiveCurrency The currency symbol
      * @return uint The length of a deposit list linked to the client ID, token contract and currency.
      * @return uint The token amount deposited.
      * @return uint The token amount received.
      */
    function getActiveDepositList(bytes32 clientId, address tokenContract, bytes32 receiveCurrency) 
        public 
        view returns (uint, uint, uint) {
        return (
            deposits[clientId][tokenContract][receiveCurrency].list.length,
            deposits[clientId][tokenContract][receiveCurrency].deposited,
            deposits[clientId][tokenContract][receiveCurrency].received
        );
    }

    /** @dev Gets the details of a deposit.
      * @param clientId The client ID.
      * @param tokenContract The token contract.
      * @param receiveCurrency The currency symbol.
      * @param depositIndex The ID of a particular deposit in a deposit list.
      * @return uint Deposited amount.
      * @return uint Received amount.
      * @return bool Boolean value to indicate if deposit is released or not.
      */
    function getActiveDeposit(bytes32 clientId, address tokenContract, bytes32 receiveCurrency, uint depositIndex) 
        public 
        view returns (uint, uint, bool) {
        return (
            deposits[clientId][tokenContract][receiveCurrency].list[depositIndex].deposited,
            deposits[clientId][tokenContract][receiveCurrency].list[depositIndex].received,
            deposits[clientId][tokenContract][receiveCurrency].list[depositIndex].isReleased
        );
    }


}