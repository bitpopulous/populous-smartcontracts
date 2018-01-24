pragma solidity ^0.4.17;

/// @title iDepositContractsManager contract
contract iDepositContractsManager {

    // NON-CONSTANT METHODS

    /** @dev Creates a new 'depositAddress' gotten from deploying a deposit contract linked to a client ID
      * @param clientId The bytes32 client ID
      * @return address The address of the deployed deposit contract instance.
      */
    function create(bytes32 clientId) public returns (address);
    /** @dev Deposits an amount of tokens linked to a client ID.
      * @param clientId The client ID.
      * @param populousTokenContract The token contract.
      * @param receiveCurrency The currency symbol.
      * @param depositAmount The deposit amount.
      * @param receiveAmount The receive amount.
      * @return bool boolean value indicating whether or not a deposit transaction has been made with success.
      * @return uint The updated number of deposits.
      */
    function deposit(bytes32 clientId, address populousTokenContract, bytes32 receiveCurrency, uint depositAmount, uint receiveAmount) public returns (bool, uint);
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
    function releaseDeposit(bytes32 clientId, address populousTokenContract, bytes32 receiveCurrency, address receiver, uint depositIndex) public returns (bool, uint, uint);
}