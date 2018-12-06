pragma solidity ^0.4.17;

import "./iERC20Token.sol";
import "./withAccessManager.sol";
import "./ERC1155.sol";
import "./ERC721Basic.sol";

/// @title DepositContract contract
contract DepositContract is withAccessManager {

    bytes32 public clientId; // client ID.
    uint256 public version = 3;

    // EVENTS
    event EventEtherTransfer(address to, uint256 value, uint256 pptFee, address adminExternalWallet);

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

    /** @dev This function will transfer iERC1155 tokens
     */
    function transferERC1155(address _erc1155Token, address _to, uint256 _id, uint256 _value) 
        public onlyServerOrOnlyPopulous returns (bool success) {
        ERC1155(_erc1155Token).safeTransfer(_to, _id, _value, "");
        return true;
    }

    /**
    * @notice Handle the receipt of an NFT
    * @dev The ERC721 smart contract calls this function on the recipient
    * after a `safetransfer` if the recipient is a smart contract. This function MAY throw to revert and reject the
    * transfer. Return of other than the magic value (0x150b7a02) MUST result in the
    * transaction being reverted.
    * Note: the contract address is always the message sender.
    * @param _operator The address which called `safeTransferFrom` function
    * @param _from The address which previously owned the token
    * @param _tokenId The NFT identifier which is being transferred
    * @param _data Additional data with no specified format
    * @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    */
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes _data) public returns(bytes4) {
        return 0x150b7a02; 
    }

    /// @notice Handle the receipt of an ERC1155 type
    /// @dev The smart contract calls this function on the recipient
    ///  after a `safeTransfer`. This function MAY throw to revert and reject the
    ///  transfer. Return of other than the magic value MUST result in the
    ///  transaction being reverted.
    ///  Note: the contract address is always the message sender.
    /// @param _operator The address which called `safeTransferFrom` function
    /// @param _from The address which previously owned the token
    /// @param _id The identifier of the item being transferred
    /// @param _value The amount of the item being transferred
    /// @param _data Additional data with no specified format
    /// @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
    ///  unless throwing
    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes _data) public returns(bytes4) {
        return 0xf23a6e61;
    }

    /**
    * @dev Safely transfers the ownership of a given token ID to another address
    * If the target address is a contract, it must implement `onERC721Received`,
    * which is called upon a safe transfer, and return the magic value
    * `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`; otherwise,
    * the transfer is reverted.
    *
    * Requires the msg sender to be the owner, approved, or operator
    * @param erc721Token address of the erc721 token to target
    * @param _to address to receive the ownership of the given token ID
    * @param _tokenId uint256 ID of the token to be transferred
    */
    function transferERC721(
        address erc721Token,
        address _to,
        uint256 _tokenId
    )
        public onlyServerOrOnlyPopulous returns (bool success)
    {
        // solium-disable-next-line arg-overflow
        ERC721Basic(erc721Token).safeTransferFrom(this, _to, _tokenId, "");
        return true;
    }

    /** @dev Transfers ether from this contract to a specified wallet/address
      * @param _to An address implementing to send ether to.
      * @param _value The amount of ether to send in wei. 
      * @return bool Successful or unsuccessful transfer
      */
    function transferEther(
        address _to, uint256 _value,
        uint256 inCollateral,
        uint256 pptFee, address adminExternalWallet, address pptAddress) 
        public 
        onlyServerOrOnlyPopulous
    {   
        require(this.balance >= _value);      
        require(_to.send(_value) == true);
        uint256 pptBalance = iERC20Token(pptAddress).balanceOf(this);
        require(inCollateral <= pptBalance);
        require((pptBalance - inCollateral) >= pptFee);
        require(iERC20Token(pptAddress).transfer(adminExternalWallet, pptFee) == true);
        EventEtherTransfer(_to, _value, pptFee, adminExternalWallet);
    }

    // payable function to allow this contract receive ether
    function () public payable {}

    // CONSTANT METHODS
    
    /** @dev Returns the ether or token balance of the current contract instance using the ERC20 balanceOf method.
      * @param populousTokenContract An address implementing the ERC20 token standard. 
      * @return uint An unsigned integer representing the returned token balance.
      */
    function balanceOf(address populousTokenContract) public view returns (uint256) {
        // ether
        if (populousTokenContract == address(0)) {
            return address(this).balance;
        } else {
            // erc20
            return iERC20Token(populousTokenContract).balanceOf(this);
        }
    }

    /**
    * @dev Gets the balance of the specified address
    * @param erc721Token address to erc721 token to target
    * @return uint256 representing the amount owned by the passed address
    */
    function balanceOfERC721(address erc721Token) public view returns (uint256) {
        return ERC721Basic(erc721Token).balanceOf(this);
        // returns ownedTokensCount[_owner];
    }

    /**
    * @dev Gets the balance of the specified address
    * @param _id the token id
    * @param erc1155Token address to erc1155 token to target
    * @return uint256 representing the amount owned by the passed address
    */
    function balanceOfERC1155(address erc1155Token, uint256 _id) external view returns (uint256) {
        return ERC1155(erc1155Token).balanceOf(_id, this);
        // returns items[_id].balances[_owner];
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