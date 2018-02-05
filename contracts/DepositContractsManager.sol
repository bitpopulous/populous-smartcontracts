pragma solidity ^0.4.17;

import "./SafeMath.sol";
import "./withAccessManager.sol";
import "./DepositContract.sol";
import "./Populous.sol";


/// @title DepositCountractsManager contract
contract DepositContractsManager is withAccessManager {

     // PPT deposits events
    event EventNewDepositContract(bytes32 clientId, address depositContractAddress);
    event EventNewDeposit(bytes32 clientId, address populousTokenContract, bytes32 receiveCurrency, uint deposited, uint received, uint depositIndex);
    event EventDepositReleased(bytes32 clientId, address populousTokenContract, bytes32 releaseCurrency, uint deposited, uint received, uint depositIndex);

    // FIELDS

    // This variable represents deposits 
    // and their related information i.e., amount deposited and received
    // and a boolean isReleased indicating whether the deposit has been released.
    struct Deposit {
        uint deposited;
        uint received;
        bytes32 currency;
        bool isReleased;
    }

    // This variable will be used to store a list of deposits
    // together with the total amount deposited and received for a deposit contract.
    struct DepositList {
        Deposit[] list;
        uint totalDeposited;
    }

    // clientId => populousTokenContract => DepositList
    mapping (bytes32 => mapping(address => DepositList)) deposits;

    // This variable will be used to keep track of client IDs and
    // their deposit addresses
    // clientId => depositAddress
    mapping (bytes32 => address) depositAddress;


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
        onlyServer
    {
        depositAddress[clientId] = new DepositContract(clientId, AM);
        assert(depositAddress[clientId] != 0x0);

        EventNewDepositContract(clientId, depositAddress[clientId]);
    }

    /** @dev Deposits an amount of tokens linked to a client ID.
      * @param clientId The client ID.
      * @param populousTokenContract The token contract.
      * @param receiveCurrency The currency symbol.
      * @param depositAmount The deposit amount.
      * @param receiveAmount The receive amount.
      * @return bool boolean value indicating whether or not a deposit transaction has been made with success.
      * @return uint The updated number of deposits.
      */
    function deposit(address populousContract, bytes32 clientId, address populousTokenContract, bytes32 receiveCurrency, uint depositAmount, uint receiveAmount)
        public
        onlyServer
    {
        DepositContract o = DepositContract(depositAddress[clientId]);

        if (SafeMath.safeSub(o.balanceOf(populousTokenContract), deposits[clientId][populousTokenContract].totalDeposited) == depositAmount) {
            // save new deposit info
            deposits[clientId][populousTokenContract].list.push(Deposit(depositAmount, receiveAmount, receiveCurrency, false));

            // update totals
            deposits[clientId][populousTokenContract].totalDeposited = SafeMath.safeAdd(
                deposits[clientId][populousTokenContract].totalDeposited,
                depositAmount
            );
            
            //success
            Populous populous = Populous(populousContract);

            uint depositIndex = deposits[clientId][populousTokenContract].list.length - 1;

            populous.mintTokens(receiveCurrency, receiveAmount);
            populous.transfer(receiveCurrency, populous.getLedgerSystemAccount(), clientId, receiveAmount);

            EventNewDeposit(clientId, populousTokenContract, receiveCurrency, depositAmount, receiveAmount, depositIndex);

        }
    }

    /** @dev Releases a deposit to an address/wallet.
      * @param clientId The client ID.
      * @param populousTokenContract The token contract.
      * @param receiveCurrency The currency symbol.
      * @param receiver The address/wallet of the receiver.
      * @param depositIndex The index/location of a specific deposit in the declared deposit list above.
      * @return bool boolean value indicating whether or not a deposit has been updated with success.
      * @return uint The token amount deposited.
      * @return uint The token amount received.
      */
    function releaseDeposit(address populousContract, bytes32 clientId, address populousTokenContract, bytes32 receiveCurrency, address receiver, uint depositIndex)
        public
        onlyServer
    {
        DepositContract o = DepositContract(depositAddress[clientId]);
        Populous populous = Populous(populousContract);

        require(populous.getLedgerEntry(receiveCurrency, clientId) >= deposits[clientId][populousTokenContract].list[depositIndex].received);


        if (deposits[clientId][populousTokenContract].list[depositIndex].deposited != 0 && 
            deposits[clientId][populousTokenContract].list[depositIndex].isReleased == false &&
            deposits[clientId][populousTokenContract].list[depositIndex].currency == receiveCurrency
        ) {
            deposits[clientId][populousTokenContract].list[depositIndex].isReleased = true;

            // update totals
            deposits[clientId][populousTokenContract].totalDeposited = SafeMath.safeSub(
                deposits[clientId][populousTokenContract].totalDeposited,
                deposits[clientId][populousTokenContract].list[depositIndex].deposited
            );
                      
            //success
            
            require(o.transfer(populousTokenContract, receiver, deposits[clientId][populousTokenContract].list[depositIndex].deposited) == true);

            uint deposited = deposits[clientId][populousTokenContract].list[depositIndex].deposited;
            uint received = deposits[clientId][populousTokenContract].list[depositIndex].received;

            require(populous.transfer(receiveCurrency, clientId, populous.getLedgerSystemAccount(), received) == true);
            require(populous.destroyTokens(receiveCurrency, received) == true);

            EventDepositReleased(clientId, populousTokenContract, receiveCurrency, deposited, received, depositIndex);

        }
    }


    // CONSTANT METHODS

    function getTotalDeposited(bytes32 clientId, address populousTokenContract) 
        public 
        view returns (uint) 
    {
        return deposits[clientId][populousTokenContract].totalDeposited;
    }

    /** @dev Gets the deposit address linked to a given client ID.
      * @param clientId The client ID.
      * @return address The deposit address.
      */
    function getDepositAddress(bytes32 clientId) public view returns (address) {
        return depositAddress[clientId];
    }

    /** @dev Gets the deposit address linked to a given client ID.
      * @param clientId The client ID.
      * @param populousTokenContract The token contract
      * @return uint The length of a deposit list linked to the client ID, token contract and currency.
      * @return uint The token amount deposited.
      */
    function getActiveDepositList(bytes32 clientId, address populousTokenContract) 
        public 
        view returns (uint, uint)
    {
        return (
            deposits[clientId][populousTokenContract].list.length,
            deposits[clientId][populousTokenContract].totalDeposited
        );
    }

    /** @dev Gets the details of a deposit.
      * @param clientId The client ID.
      * @param populousTokenContract The token contract.
      * @param receiveCurrency The currency symbol.
      * @param depositIndex The ID of a particular deposit in a deposit list.
      * @return uint Deposited amount.
      * @return uint Received amount.
      * @return bool Boolean value to indicate if deposit is released or not.
      */
    function getActiveDeposit(bytes32 clientId, address populousTokenContract, bytes32 receiveCurrency, uint depositIndex) 
        public 
        view returns (uint, uint, bool) 
    {
        if (deposits[clientId][populousTokenContract].list[depositIndex].currency == receiveCurrency) {
            return (
                deposits[clientId][populousTokenContract].list[depositIndex].deposited,
                deposits[clientId][populousTokenContract].list[depositIndex].received,
                deposits[clientId][populousTokenContract].list[depositIndex].isReleased
            );
        }
    }


}