pragma solidity ^0.4.8;

import "./SafeMath.sol";
import "./StringUtils.sol";
import "./withAccessManager.sol";

/**
    The platform address is owner;
    Populous contract address is guardian;
    Functions, which don't require token transfers are onlyOwner;
    Functions, which do token transfers are onlyGuardian
*/
contract Crowdsale is withAccessManager {

    event EventGroupCreated(uint groupIndex, bytes32 name, uint goal);
    event EventGroupGoalReached(uint groupIndex, bytes32 _name, uint goal);
    event EventNewBid(uint groupIndex, bytes32 bidderId, bytes32 name, uint value);
    event EventAuctionStarted();

    enum States { Pending, Open, Closed, WaitingForInvoicePayment, Completed }

    States public status;
    address public currency;
    bytes32 public currencySymbol;

    // late interest cap at 7% (7 days 1%)
    uint public latePaymentInterest = 0;

    bytes32 public invoiceId;
    bytes32 public borrowerId;
    bytes32 public borrowerName;
    bytes32 public buyerName;

    uint public invoiceAmount;
    uint public fundingGoal;

    uint public deadline;

    struct Bidder {
        uint bidderIndex;
        bytes32 bidderId;
        bytes32 name;
        uint bidAmount;
        bool hasReceivedTokensBack; // This flag is set when losing group receives its tokens back or when winner group gets its winnings
    }

    struct Group {
        uint groupIndex;
        bytes32 name;
        uint goal;
        Bidder[] bidders;
        uint amountRaised;
        bool hasReceivedTokensBack; // This is set to true when the flag hasReceivedTokensBack is set to true for all bidders in the group
    }

    //Groups
    Group[] public groups;
    uint public winnerGroupIndex;
    bool public sentToBeneficiary;
    bool public sentToLosingGroups;
    bool public sentToWinnerGroup;

    //Constructor
    function Crowdsale(
            address _accessManager,
            address _currency,
            bytes32 _currencySymbol,
            bytes32 _borrowerId,
            bytes32 _borrowerName,
            bytes32 _buyerName,
            bytes32 _invoiceId,
            uint _invoiceAmount,
            uint _fundingGoal)
            withAccessManager(_accessManager)
    {
        currency = _currency;
        currencySymbol = _currencySymbol;
        borrowerId = _borrowerId;
        borrowerName = _borrowerName;
        buyerName = _buyerName;
        invoiceId = _invoiceId;
        invoiceAmount = _invoiceAmount;
        fundingGoal = _fundingGoal;

        deadline = now + 24 hours;
        status = States.Pending;
    }

    modifier afterDeadline() { if (now >= deadline) _; }
    modifier onlyOpenAuction() { if (status != States.Open) { throw; } _; }

    function isDeadlineReached() returns(bool) {
        if (now > deadline) {
            if (status == States.Open) {
                status = States.Closed;
            }
            return true;
        }
        return false;
    }

    function getGroupsCount() public constant returns (uint) {
        return groups.length;
    }

    function getGroup(uint groupIndex)
        public constant
        returns (bytes32 name, uint goal, uint biddersCount, uint amountRaised, bool hasReceivedTokensBack)
    {
        Group g = groups[groupIndex];

        return (g.name, g.goal, g.bidders.length, g.amountRaised, g.hasReceivedTokensBack);
    }

    function setGroupHasReceivedTokensBack(uint groupIndex) {
        groups[groupIndex].hasReceivedTokensBack = true;
    }

    function getGroupBidder(uint groupIndex, uint bidderIndex)
        public constant
        returns (bytes32 bidderId, bytes32 name, uint bidAmount, bool hasReceivedTokensBack)
    {
        Bidder b = groups[groupIndex].bidders[bidderIndex];

        return (b.bidderId, b.name, b.bidAmount, b.hasReceivedTokensBack);        
    }

    function setBidderHasReceivedTokensBack(uint groupIndex, uint bidderIndex) {
        groups[groupIndex].bidders[bidderIndex].hasReceivedTokensBack = true;
    }    

    function openAuction() public returns (bool) {
        if (status == States.Pending) {
            status = States.Open;
              
            EventAuctionStarted();

            return true;
        } else {
            return false;
        }
    }

    function createGroup(bytes32 _name, uint _goal)
        onlyOpenAuction
        returns (uint8 err, uint groupIndex)
    {
        if(isDeadlineReached() == false && _goal >= fundingGoal && _goal <= invoiceAmount) {
            groupIndex = groups.length++;
            groups[groupIndex].groupIndex = groupIndex;
            groups[groupIndex].name = _name;
            groups[groupIndex].goal = _goal;

            EventGroupCreated(groupIndex, _name, _goal);

            return (0, groupIndex);
        } else {
            return (1, 0);
        }
    }

    function findBidder(uint groupIndex, bytes32 bidderId) constant returns (uint8 err, uint bidderIndex) {
        for(uint i = 0; i < groups[groupIndex].bidders.length; i++) {
            if (StringUtils.equal(groups[groupIndex].bidders[i].bidderId, bidderId) == true) {
                return (0, i);
            }
        }
        return (1, 0);
    }

    function bid(uint groupIndex, bytes32 bidderId, bytes32 name, uint value)
        onlyOpenAuction
        
        returns (uint finalValue, uint groupGoal, bool goalReached)
    {
        Group G = groups[groupIndex];

        if(isDeadlineReached() == true || value == 0 || G.goal == 0) { throw; }
        
        if (G.amountRaised + value > G.goal) {
            value = SafeMath.safeSub(G.goal, G.amountRaised);
        }

        uint8 err;
        uint bidderIndex;

        (err, bidderIndex) = findBidder(groupIndex, bidderId);

        if (err == 0) {
            G.bidders[bidderIndex].bidAmount = SafeMath.safeAdd(G.bidders[bidderIndex].bidAmount, value);
        } else {
            G.bidders.push(Bidder(G.bidders.length, bidderId, name, value, false));
        }

        G.amountRaised = SafeMath.safeAdd(G.amountRaised, value);

        EventNewBid(groupIndex, bidderId, name, value);

        goalReached = G.amountRaised == G.goal;

        if (goalReached == true) {
            winnerGroupIndex = groupIndex;
            status = States.Closed;

            EventGroupGoalReached(groupIndex, G.name, G.goal);
        }

        return (value, G.goal, goalReached);
    }

    function endAuction() onlyPopulous returns(bool) {
        if (status == States.Closed) {
            // Send tokens to beneficiary
            // Send tokens back to loser groups

            status = States.WaitingForInvoicePayment;
        }
    }

    function getAmountForBeneficiary() public constant returns (uint8 err, uint amount) {
        if (status == States.WaitingForInvoicePayment && sentToBeneficiary == false) {
            return (0, groups[winnerGroupIndex].amountRaised);
        } else {
            return (1, 0);
        }
    }

    function setSentToBeneficiary() onlyPopulous {
        sentToBeneficiary = true;
    }

    function setGroupRefunded(uint groupIndex) onlyGuardian returns (bool) {
        if (groupIndex != winnerGroupIndex) {
            groups[groupIndex].hasReceivedTokensBack = true;

            return true;
        } else {
            return false;
        }
    }

    function setSentToLosingGroups() onlyGuardian {
        sentToLosingGroups = true;
    }

    function invoicePaymentReceived() onlyGuardian {
        if (status == States.WaitingForInvoicePayment) {
            // Send tokens to winner group

            status = States.Completed;
        }
    }

    function setSentToWinnerGroup() onlyGuardian {
        sentToWinnerGroup = true;
    }

}