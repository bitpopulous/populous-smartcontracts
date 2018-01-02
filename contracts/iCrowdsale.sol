pragma solidity ^0.4.17;

/// @title iCrowdsale contract an interface contract
contract iCrowdsale {

    // FIELDS

    bytes32 public currencySymbol;
    uint public invoiceAmount;
    bytes32 public borrowerId;
    uint8 public status;
    uint public platformTaxPercent;
    
    uint public winnerGroupIndex;
    bool public hasWinnerGroup;
    bool public sentToBeneficiary;
    bool public sentToLosingGroups;
    bool public sentToWinnerGroup;
    uint public paidAmount;

    // METHODS
    // methods that a contract of type iCrowdsale must implement to fit into the overall application framework

    //NON-CONSTANT METHODS

    
    /** @dev Creates a new bidding group for bidders to bid to fund an invoice and assigns the group an index in the collection of groups.
      * @param _name The group name.
      * @param _goal The goal of the group.
      * @return err 0 or 1 implying absence or presence of error.
      * @return groupIndex The returned group index/location in a collection of other groups.
      */
    function createGroup(string _name, uint _goal) private returns (uint8 err, uint groupIndex);
    
    
    function closeCrowdsale() public returns(bool success);

    /** @dev Allows a bidder to place a bid as part of a group within a set of groups.
      * @param groupIndex The index/location of a group in a set of groups.
      * @param bidderId The bidder id/location in a set of bidders.
      * @param name The bidder name.
      * @param value The bid value.
      * @return err 0 or 1 implying absence or presence of error.
      * @return finalValue All bidder's bids value.
      * @return groupGoal An unsigned integer representing the group's goal.
      * @return goalReached A boolean value indicating whether the group goal has reached or not.
      */
    function bid(uint groupIndex , bytes32 bidderId, string name, uint value) public returns (uint8 err, uint finalValue, uint groupGoal, bool goalReached);
    
    /** @dev Allows a first time bidder to create a new group if they do not belong to a group
      * @dev and place an intial bid.
      * @dev This function creates a group and calls the bid() function.
      * @param groupName The name of the new investor group to be created.
      * @param goal The group funding goal.
      * @param bidderId The bidder id/location in a set of bidders.
      * @param name The bidder name.
      * @param value The bid value.
      * @return err 0 or 1 implying absence or presence of error.
      * @return finalValue All bidder's bids value.
      * @return groupGoal An unsigned integer representing the group's goal.
      * @return goalReached A boolean value indicating whether the group goal has reached or not.
      */
    function initialBid(string groupName, uint goal, bytes32 bidderId, string name, uint value) public returns (uint8 err, uint finalValue, uint groupGoal, bool goalReached);
    
    /** @dev Sets the 'hasReceivedTokensBack' for a bidder denoting they have received token refund and is restricted to populous.
      * @param groupIndex The group id in a set of groups.
      * @param bidderIndex The bidder id in a set of bidders within a group.
      */
    function setBidderHasReceivedTokensBack(uint groupIndex, uint bidderIndex) public;
    /** @dev Sets the 'sentToBeneficiary' boolean variable to true.
      * @dev Only populous can use this method.
      */
    function setSentToBeneficiary() public;
    /** @dev Sets the paidAmount and restricted to populous.
      * @param _paidAmount The amount paid.
      */ 
    function setPaidAmount(uint _paidAmount) public;

    // CONSTANT METHODS

    /** @dev Gets bool hasWinnerGroup for crowdsale
      * @return bool hasWinnerGroup.
      */
    function getHasWinnerGroup() public view returns (bool);
    
    /** @dev Gets the paid amount 
      * @return uint The paid amount.
      */
    function getPaidAmount() public view returns (uint) {
        return paidAmount;
    }

    /** @dev Gets the paid amount 
      * @return uint The paid amount.
      */
    function getWinnerGroupIndex() public view returns (uint) {
        return winnerGroupIndex;
    }
    /** @dev Gets the current status.
      * @return uint8 The returned status.
      */
    function getStatus() public view returns (uint8);
    /** @dev Gets the number of groups in the groups array.
      * @return uint The number of bidding groups in the crowdsale.
      */
    function getGroupsCount() public view returns (uint);
    /** @dev Gets the details of a group located by its index/location in the group array..
      * @param groupIndex The location of a group within the groups array variable.
      * @return uint8 The returned status.
      */ 
    function getGroup(uint groupIndex) public view returns (string name, uint goal, uint biddersCount, uint amountRaised, bool hasReceivedTokensBack);
    /** @dev Gets a bidders details from a group.
      * @param groupIndex The location of a group in the groups array.
      * @param bidderIndex The location of a bidder in the bidders arrays of a group
      * @return bidderId The bidder ID.
      * @return name The bidder name.
      * @return bidAmount The bid amount.
      * @return hasReceivedTokensBack A boolean value to indicate whether the loosing group has received a refund of their tokens.
      */
    function getGroupBidder(uint groupIndex, uint bidderIndex) public view returns (bytes32 bidderId, bytes32 name, uint bidAmount, bool hasReceivedTokensBack);        
    /** @dev Gets beneficiary's token amount after bidding is closed.
      * @return amount The total bid amount.
      * @return err 0 or 1 implying absence or presence of error.
      */
    function getAmountForBeneficiary() public view returns (uint8 err, uint amount);

}
