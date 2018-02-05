pragma solidity ^0.4.17;

import "./SafeMath.sol";
import "./Utils.sol";
import "./withAccessManager.sol";



/// @title Crowdsale contract
contract Crowdsale is withAccessManager {

    // EVENTS 

    event EventGroupCreated(address crowdsaleAddr, uint groupIndex, string name, uint goal);
    event EventGroupGoalReached(address crowdsaleAddr, uint groupIndex, string _name, uint goal);
    event EventNewBid(address crowdsaleAddr, uint groupIndex, bytes32 bidderId, string name, uint value);
    event EventCrowdsaleOpen(address crowdsaleAddr);
    event EventCrowdsaleClosed(address crowdsaleAddr, uint8 reasonCode);
    event EventCrowdsaleWaiting(address crowdsaleAddr);
    event EventPaymentReceived(address crowdsaleAddr, uint paidAmount);
    event EventCrowdsaleCompleted(address crowdsaleAddr);
    event EventGroupCreationFailed(address crowdsaleAddr);

    // FIELDS 

    enum CrowdsaleCloseReasons { GroupGoalReached, DeadlineReached, BorrowerClosed, PopulousClosed }
    enum States { Pending, Open, Closed, WaitingForInvoicePayment, PaymentReceived, Completed }

    States public status;

    bytes32 public currencySymbol;
    bytes32 public invoiceId;
    string public invoiceNumber;
    bytes32 public borrowerId;
    uint public invoiceAmount;
    uint public fundingGoal;
    uint public deadline;
    uint public platformTaxPercent;

    string public signedDocumentIPFSHash;

    struct Bidder {
        uint bidderIndex; // bidder index
        bytes32 bidderId; // bidder id
        string name; // bidder's name
        uint bidAmount; // total bid amount
        uint lastBidAt; // Timestamp of last bid
        bool hasReceivedTokensBack; // This flag is set when losing group receives its tokens back or when winner group gets its winnings
    }

    struct Group {
        uint groupIndex; // group index
        string name; // group name
        uint goal; // group goal
        Bidder[] bidders; // group bidders
        uint amountRaised; // amount raised by group
        uint biddersReceivedTokensBack;
        bool hasReceivedTokensBack; // This is set to true when the flag hasReceivedTokensBack is set to true for all bidders in the group
    }

    struct BidderInfo {
        uint groupIndex;
        uint bidderIndex;
        bool inAGroup;
    }

    //Groups
    Group[] public groups;

    //bidderId => BidderInfo
    mapping (bytes32 => BidderInfo) bidderGroupInfo;

    address public crowdsaleaddr = address(this);

    uint public groupsReceivedTokensBack;
    uint public winnerGroupIndex;
    bool public hasWinnerGroup;

    bool public deadlineReached;
    uint public paidAmount;

    bool public sentToBeneficiary;
    bool public sentToLosingGroups;
    bool public sentToWinnerGroup;

    // MODIFIERS

    modifier onlyOpenCrowdsale() { if (status == States.Open) { _; } }


    // NON-CONSTANT METHODS


    //Constructor
    /** @dev Creates a new Crowdsale contract instance for an invoice crowdsale.
      * @param _accessManager The address of an access manager contract instance.
      * @param _currencySymbol The currency symbol, e.g., GBP.
      * @param _borrowerId The unique borrower ID.
      * @param _invoiceId The unique invoice ID.
      * @param _invoiceNumber The unique invoice number.
      * @param _invoiceAmount The invoice amount.
      * @param _fundingGoal The funding goal of the borrower.
      * @param _platformTaxPercent The percentage charged by the platform
      * @param _signedDocumentIPFSHash The hash of related invoice documentation saved on IPFS.
      */
    function Crowdsale(
            address _accessManager,
            bytes32 _currencySymbol,
            bytes32 _borrowerId,
            bytes32 _invoiceId,
            string _invoiceNumber,
            uint _invoiceAmount,
            uint _fundingGoal,
            uint _platformTaxPercent,
            string _signedDocumentIPFSHash,
            uint _extraTime)
            public
            withAccessManager(_accessManager)
    {
        currencySymbol = _currencySymbol;
        borrowerId = _borrowerId;
        invoiceId = _invoiceId;
        invoiceNumber = _invoiceNumber;
        invoiceAmount = _invoiceAmount;
        fundingGoal = _fundingGoal;
        platformTaxPercent = _platformTaxPercent;
        signedDocumentIPFSHash = _signedDocumentIPFSHash;
        deadline = now + 24 hours + _extraTime * 1 minutes;
        status = States.Open;
    }


    // to do - add method to check if crowdsale ended without hasWinnerGroup = true
    // and group length => 1
    // then refund members with new refund function
    // findBidder

    // check if crowdsale deadline has reached and if there were any bids
    // if deadline reached change state to closed with reason being deadline
    // reached and no bids
    // return true or false if deadline reached and no bids
    function checkNoBids() public view returns(bool) {
        if (groups.length == 0) {
            return true;
        }
        return false;
    }

    /** @dev closes an open crowdsale
      * @dev onlyPopulous allowed, i.e., populous address has to be msg.sender
      * @dev function has to be implemented in populous.sol to be msg.sender
      * @return success This is a boolean true/false indicating if crowdsale is closed.
      */
    function closeCrowdsale() public onlyServer returns(bool success) {
        if (status == States.Open && now < deadline) {
            status = States.Closed;
            EventCrowdsaleClosed(crowdsaleaddr, uint8(CrowdsaleCloseReasons.PopulousClosed));
            return true;
        }
        return false;
    }

    /** @dev Checks whether the invoice crowdsale deadline has passed or not.
      * @return bool A boolean value indicating whether the deadline has passed or not.
      */
    function checkDeadline() public returns(bool) {
        if (now > deadline) {
            if (status == States.Open) {
                status = States.Closed;
                EventCrowdsaleClosed(crowdsaleaddr, uint8(CrowdsaleCloseReasons.DeadlineReached));
            }
            deadlineReached = true;
            return true;
        }
        return false;
    }

    /** @dev Sets the 'hasReceivedTokensBack' for a bidder denoting they have received token refund and is restricted to populous.
      * @param groupIndex The group id in a set of groups.
      * @param bidderIndex The bidder id in a set of bidders within a group.
      */
    function setBidderHasReceivedTokensBack(uint groupIndex, uint bidderIndex) 
        public
        onlyPopulous 
    {
        groups[groupIndex].bidders[bidderIndex].hasReceivedTokensBack = true;
        groups[groupIndex].biddersReceivedTokensBack++;

        if (groups[groupIndex].biddersReceivedTokensBack == groups[groupIndex].bidders.length) {
            groups[groupIndex].hasReceivedTokensBack = true;
            groupsReceivedTokensBack++;
            // comparing number of groups to number of groups that have received tokens back
            // check if groupIndex = winner group Index
            // check if hasWinnerGroup
            // check if crowdsaleisclosed - already checked before state change
            if (groups.length == 1) {
                if (hasWinnerGroup) {
                    setSentToLosingGroups();
                    setSentToWinnerGroup();
                } else {
                    setSentToLosingGroups();
                }
            } else if (groups.length - 1 == groupsReceivedTokensBack) {
                setSentToLosingGroups();
            } else if (groups.length == groupsReceivedTokensBack && hasWinnerGroup) { // bug fix
                setSentToWinnerGroup();
            }
        }
    }


    /** @dev Sets the paidAmount and restricted to populous.
      * @param _paidAmount The amount paid.
      */
    function setPaidAmount(uint _paidAmount) public onlyPopulous {
        if (status == States.WaitingForInvoicePayment) {
            paidAmount = _paidAmount;
            status = States.PaymentReceived;

            EventPaymentReceived(crowdsaleaddr, paidAmount);
        }
    } 

    /** @dev Creates a new bidding group for bidders to bid to fund an invoice and assigns the group an index in the collection of groups.
      * @param _name The group name.
      * @param _goal The goal of the group.
      * @return err 0 or 1 implying absence or presence of error.
      * @return groupIndex The returned group index/location in a collection of other groups.
      */
    function createGroup(string _name, uint _goal)
        private
        onlyOpenCrowdsale
        returns (uint8 err, uint groupIndex)
    {
        if(checkDeadline() == false && _goal >= fundingGoal && _goal <= invoiceAmount) {
            groupIndex = groups.length++;
            groups[groupIndex].groupIndex = groupIndex;
            groups[groupIndex].name = _name;
            groups[groupIndex].goal = _goal;

            EventGroupCreated(crowdsaleaddr, groupIndex, _name, _goal);

            return (0, groupIndex);
        } else {
            EventGroupCreationFailed(crowdsaleaddr);
            return (1, 0);
        }
    }


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
    function bid(uint groupIndex, bytes32 bidderId, string name, uint value)
        public
        onlyOpenCrowdsale
        onlyPopulous
        returns (uint8 err, uint finalValue, uint groupGoal, bool goalReached)
    {
        if(checkDeadline() == true || value == 0 || groups[groupIndex].goal == 0) {
            return (1, 0, 0, false);
        }
        // checking if amount raised by group and bid value exceed the group's goal
        if (groups[groupIndex].amountRaised + value > groups[groupIndex].goal) {
            value = SafeMath.safeSub(groups[groupIndex].goal, groups[groupIndex].amountRaised);
        }

        uint8 finderErr;
        uint bidderIndex;
        // searching for bidder
        (finderErr, bidderIndex) = findBidder(groupIndex, bidderId);
        
        if (finderErr == 0) {
            // if bidder found in a group, set timestamp of last bid and add to their bid amount
            groups[groupIndex].bidders[bidderIndex].bidAmount = SafeMath.safeAdd(groups[groupIndex].bidders[bidderIndex].bidAmount, value);
            groups[groupIndex].bidders[bidderIndex].lastBidAt = now;

        } else {

            // adding the bidder to a group if not found
            groups[groupIndex].bidders.push(Bidder(groups[groupIndex].bidders.length, bidderId, name, value, now, false));
            
            // linking bidderIndex and groupIndex to bidder id for easy lookup
            bidderGroupInfo[bidderId].groupIndex = groupIndex;
            bidderGroupInfo[bidderId].bidderIndex = groups[groupIndex].bidders.length - 1;
            bidderGroupInfo[bidderId].inAGroup = true;
        }
        // adding bid value to amount raised for the group using the group index to locate group in groups array
        groups[groupIndex].amountRaised = SafeMath.safeAdd(groups[groupIndex].amountRaised, value);

        EventNewBid(crowdsaleaddr, groupIndex, bidderId, name, value);
        // boolean value to check if goal has reached
        goalReached = groups[groupIndex].amountRaised == groups[groupIndex].goal;
        // using the above boolean value to set the winning group and set the status of the crowdsale to closed
        if (goalReached == true) {
            winnerGroupIndex = groupIndex;
            hasWinnerGroup = true;
            status = States.Closed;
            // event denoting groupGoalReached
            EventGroupGoalReached(crowdsaleaddr, groupIndex, groups[groupIndex].name, groups[groupIndex].goal);
            // event denoting crowdsaleClosed
            EventCrowdsaleClosed(crowdsaleaddr, uint8(CrowdsaleCloseReasons.GroupGoalReached));
        }

        return (0, value, groups[groupIndex].goal, goalReached);
    }

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
    function initialBid(string groupName, uint goal, bytes32 bidderId, string name, uint value)
        public
        onlyOpenCrowdsale
        onlyPopulous
        returns (uint8 err, uint finalValue, uint groupGoal, bool goalReached)
    {      
        uint8 finderErr;
        uint groupIndex;
        uint bidderIndex;
        // searching for bidder
        (finderErr, groupIndex, bidderIndex) = findBidder(bidderId);
        // check that bidder is in a group -> call bid()
        if (finderErr == 1) {
            // if bidder is not in a group, create group - > get group index ->  call bid() with group index 
            // bidder is not in any group. New group can be created at this point.
            (err, groupIndex) = createGroup(groupName, goal);
            
            if (err == 1) {
                return (1, 0, 0, false);
            }
        }
        return bid(groupIndex, bidderId, name, value);
        
    }

    /** @dev Allows a borrower to choose a bid winner group and checks amount raised from that group is > 0.
      * @param groupIndex The selected index/location of the group in the groups array.
      */
    function borrowerChooseWinner(uint groupIndex)
        public
        onlyOpenCrowdsale
        onlyServer
    {
        require(!checkNoBids());
        if (groups[groupIndex].amountRaised > 0) {
            winnerGroupIndex = groupIndex;
            hasWinnerGroup = true;
            status = States.Closed;

            EventCrowdsaleClosed(crowdsaleaddr, uint8(CrowdsaleCloseReasons.BorrowerClosed));
        }
    }

    

    // calls the _waitingForPayment method
    // called by setSentToLosingGroup
    function waitingForPayment() public onlyServer returns(bool) {
        return _waitingForPayment();
    }

    /** @dev Sets the status to a state of '_waitingForPayment'.
      * @dev If the current status is closed, sentToBeneficiary and sentToLosingGroups are true.
      * @return bool A boolean value true or false.
      */
    function _waitingForPayment() private returns(bool) {
        if (status == States.Closed && sentToBeneficiary == true && sentToLosingGroups == true) {
            // Tokens have been sent to beneficiary
            // Tokens have been sent to loser groups
            status = States.WaitingForInvoicePayment;
            EventCrowdsaleWaiting(crowdsaleaddr);
        }
    }

    /** @dev Sets the 'sentToBeneficiary' boolean variable to true.
      * @dev Only populous can use this method.
      */
    function setSentToBeneficiary() public onlyPopulous {
        require(!checkNoBids());
        

        sentToBeneficiary = true;

        // We have only 1 group (the winning group) and we set 
        // the losing groups as refunded automatically.
        if (groups.length == 1) {
            setSentToLosingGroups();
        }
        
    }

    /** @dev Sets the sent 'setSentToLosingGroups' boolean variable to true.
      */
    function setSentToLosingGroups() private {
        require(!checkNoBids());
        sentToLosingGroups = true;
        
        _waitingForPayment();
    }

    /** @dev Sets the sent 'sentToWinnerGroup' boolean variable to true.
      * @dev Sets the status of the crowdsale to completed
      * @dev Sets the boolean 'hasReceivedTokensBack' variable of the winning group to true
      */
    function setSentToWinnerGroup() private {
        require(!checkNoBids());

        sentToWinnerGroup = true;
        status = States.Completed;
        groups[winnerGroupIndex].hasReceivedTokensBack = true;
        
        EventCrowdsaleCompleted(crowdsaleaddr);
    }


    // CONSTANT METHODS

    /** @dev Gets bool indicating crowdsale deadline has reached
      * @return bool deadlineReached
      */
    function getDeadlineReached() public view returns (bool) {
        return deadlineReached;
    }
    
    /** @dev Gets bool hasWinnerGroup for crowdsale
      * @return bool hasWinnerGroup.
      */
    function getHasWinnerGroup() public view returns (bool) {
        return hasWinnerGroup;
    }
    
    /** @dev Gets the paid amount 
      * @return uint The paid amount.
      */
    function getPaidAmount() public view returns (uint) {
        return paidAmount;
    }

    /** @dev Gets the winning group index 
      * @return uint The index for winning group.
      */
    function getWinnerGroupIndex() public view returns (uint) {
        return winnerGroupIndex;
    }

    /** @dev Gets the current status.
      * @return uint8 The returned status.
      */
    function getStatus() public view returns (uint8) {
        return uint8(status);
    }

    /** @dev Gets the number of groups in the groups array.
      * @return uint The number of bidding groups in the crowdsale.
      */
    function getGroupsCount() public view returns (uint) {
        return groups.length;
    }

    
    /** @dev Checks if a bidder in any bidding group
      * has received their tokens back.
      * @param bidderId The bidder ID
      * @return received The boolean true/false indicating token received or not.
      */
    function bidderHasTokensBack (bytes32 bidderId) public view returns(bool received) {
        uint8 err;
        uint groupIndex;
        uint bidderIndex;
        (err, groupIndex, bidderIndex) = findBidder(bidderId);
        bytes32 bidder;
        uint bidAmount;
        bool hasReceivedTokensBack;
        (bidder, , bidAmount, hasReceivedTokensBack) = getGroupBidder(groupIndex, bidderIndex);
        if (Utils.equal(bidderId, bidder) && hasReceivedTokensBack) {
            return true;
        }
        return false;

    }


    /** @dev Gets the details of a group located by its index/location in the group array..
      * @param groupIndex The location of a group within the groups array variable.
      * @return name The group name.
      * @return goal The amount representing the group funding goal.
      * @return biddersCount The number of bidders in the bidding group.
      * @return amountRaised The amount of tokens raised by the group during crowdsale.
      * @return hasReceivedTokensBack A boolean value indicating if group has been funded after crowdsale.
      */ 
    function getGroup(uint groupIndex)
        public view
        returns (string name, uint goal, uint biddersCount, uint amountRaised, bool hasReceivedTokensBack)
    {
        Group memory g = groups[groupIndex];

        return (g.name, g.goal, g.bidders.length, g.amountRaised, g.hasReceivedTokensBack);
    }

    /** @dev Gets a bidders details from a group.
      * @param groupIndex The location of a group in the groups array.
      * @param bidderIndex The location of a bidder in the bidders arrays of a group
      * @return bidderId The bidder ID.
      * @return name The bidder name.
      * @return bidAmount The bid amount.
      * @return hasReceivedTokensBack A boolean value to indicate whether the loosing group has received a refund of their tokens.
      */
    function getGroupBidder(uint groupIndex, uint bidderIndex)
        public view
        returns (bytes32 bidderId, string name, uint bidAmount, bool hasReceivedTokensBack)
    {
        Bidder memory b = groups[groupIndex].bidders[bidderIndex];

        return (b.bidderId, b.name, b.bidAmount, b.hasReceivedTokensBack);
    }

    /** @dev Finds a bidder in a list of bidders with bidder ID.
      * @param bidderId The bytes32 bidder ID.
      * @return err 0 or 1 implying absence or presence of error.
      * @return bidderIndex The location of the bidder in bidders array.
      * @return groupIndex The location of the bidders group in the groups array.
      */
    function findBidder(bytes32 bidderId) public view returns (uint8 err, uint groupIndex, uint bidderIndex) {
        bidderIndex = bidderGroupInfo[bidderId].bidderIndex;
        groupIndex = bidderGroupInfo[bidderId].groupIndex;
        if (!bidderGroupInfo[bidderId].inAGroup) {
            return (1, 0, 0);
        } else if (Utils.equal(groups[groupIndex].bidders[bidderIndex].bidderId, bidderId) == true) {
            return (0, groupIndex, bidderIndex);
        }
        
        /* for(groupIndex = 0; groupIndex < groups.length; groupIndex++) {
            for(bidderIndex = 0; bidderIndex < groups[groupIndex].bidders.length; bidderIndex++) {
                if (Utils.equal(groups[groupIndex].bidders[bidderIndex].bidderId, bidderId) == true) {
                    return (0, groupIndexes[bidderIndex], bidderIndexes[bidderId]);
                }
            }
        }
        return (1, 0, 0); */
    }

    /** @dev Finds a bidder in a list of bidders with bidder ID and group index.
      * @param groupIndex The location of a group in the groups array.
      * @param bidderIndex The location of a bidder in the bidders arrays of a group
      * @return err 0 or 1 implying absence or presence of error.
      * @return bidderIndex The location of the bidder in bidders array.
      */
    function findBidder(uint groupIndex, bytes32 bidderId) public view returns (uint8 err, uint bidderIndex) {
        bidderIndex = bidderGroupInfo[bidderId].bidderIndex;
        groupIndex = bidderGroupInfo[bidderId].groupIndex;
        if (!bidderGroupInfo[bidderId].inAGroup) {
            return (1, 0);
        } else if (Utils.equal(groups[groupIndex].bidders[bidderIndex].bidderId, bidderId) == true) {
            return (0, bidderIndex);
        }
        /* for(bidderIndex = 0; bidderIndex < groups[groupIndex].bidders.length; bidderIndex++) {
            if (Utils.equal(groups[groupIndex].bidders[bidderIndex].bidderId, bidderId) == true) {
                return (0, bidderIndexes[bidderId]);
            }
        }
        return (1, 0);  */ 
    }

    /** @dev Gets beneficiary's token amount after bidding is closed.
      * @return amount The total bid amount.
      * @return err 0 or 1 implying absence or presence of error.
      */
    function getAmountForBeneficiary() public view returns (uint8 err, uint amount) {
        if (status == States.Closed && sentToBeneficiary == false) {
            // winner group will be zero by default but hasWinnerGroup = False
            // in that case, funding beneficiary should fail
            // previously, it still tries to get amountRaised for group with index = 0
            return (0, groups[winnerGroupIndex].amountRaised);
        } else {
            return (1, 0);
        }
    }

}