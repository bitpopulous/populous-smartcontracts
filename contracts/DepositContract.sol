pragma solidity ^0.4.17;

import "./iERC20Token.sol";
import "./withAccessManager.sol";



/// @title DepositContract contract
contract DepositContract is withAccessManager {

    bytes32 clientId;// client ID.
    address manager; // address of contract manager.

    // MODIFIERS

    /* modifier onlyManager() {
        require(msg.sender == manager);
        _;
    } */

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


}