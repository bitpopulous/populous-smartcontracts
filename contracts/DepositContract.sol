pragma solidity ^0.4.17;

import "./iERC20Token.sol";
import "./withAccessManager.sol";



/// @title DepositContract contract
contract DepositContract is withAccessManager {

    bytes32 public clientId; // client ID.

    uint256 public version = 2;
    // MODIFIERS


    // EVENTS
    event EtherTransfer(address to, uint256 value);

    // NON-CONSTANT METHODS 

    /** @dev Constructor that sets the _clientID when the contract is deployed.
      * @dev The method also sets the manager to the msg.sender.
      * @param _clientId A string of fixed length representing the client ID.
      */
    function DepositContract(bytes32 _clientId, address accessManager) public withAccessManager(accessManager) {
        clientId = _clientId;
    }
     

    /** @dev Transfers an amount '_value' of tokens from msg.sender to '_to' address/wallet.
      * @param populousTokenContract The address of the ERC20 token contract which implements the transfer method.
      * @param _value the amount of tokens to transfer.
      * @param _to The address/wallet to send to.
      * @return success boolean true or false indicating whether the transfer was successful or not.
      */
    function transfer(address populousTokenContract, address _to, uint256 _value) public
        onlyServerOrOnlyPopulous returns (bool success) 
    {
        return iERC20Token(populousTokenContract).transfer(_to, _value);
    }

    // CONSTANT METHODS
    
    /** @dev Returns the token balance of the current contract instance using the ERC20 balanceOf method.
      * @param populousTokenContract An address implementing the ERC20 token standard. 
      * @return uint An unsigned integer representing the returned token balance.
      */
    function balanceOf(address populousTokenContract) public view returns (uint) {
        return iERC20Token(populousTokenContract).balanceOf(this);
    }


    /** @dev Transfers ether from this contract to a specified wallet/address
      * @param _to An address implementing to send ether to.
      * @param _value The amount of ether to send in wei. 
      * @return bool Successful or unsuccessful transfer
      */
    function transferEther(address _to, uint256 _value) public 
        onlyServerOrOnlyPopulous returns (bool success) 
    {
        require(this.balance >= _value);
        _to.transfer(_value);
        EtherTransfer(_to, _value);
        return true;
    }


    /** @dev Gets ether balance from this contract
      * @return uint256 ether balance
      */
    function getEtherBalance() public 
        returns (uint256 _balance) 
    {
        return this.balance;
    }

    /** @dev Gets the version of this deposit contract
      * @return uint256 version
      */
    function getVersion() public view returns (uint256) {
        return version;
    }



    // CONSTANT FUNCTIONS

    /** @dev This function gets the client ID or deposit contract owner
     * returns _clientId
     */
    function getClientId() public view returns (bytes32 _clientId) {
        return clientId;
    }


}