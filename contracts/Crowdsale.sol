pragma solidity ^0.4.8;

import "./SafeMath.sol";
import "./Utils.sol";
import "./withAccessManager.sol";

/**
    The platform address is owner;
    Populous contract address is guardian;
    Functions, which don't require token transfers are onlyOwner;
    Functions, which do token transfers are onlyGuardian
    bibby has to be signed before the beneficiary can receive the funds
*/
contract Crowdsale is withAccessManager {

    event EventGroupCreated(uint groupIndex, string name, uint goal);
    event EventGroupGoalReached(uint groupIndex, string _name, uint goal);
    event EventNewBid(uint groupIndex, bytes32 bidderId, string name, uint value);
    event EventAuctionOpen();
    event EventAuctionClosed(); // there are different cases for closes - a parameter can be added to describe the closing reason
    event EventAuctionWaiting();
    event EventAuctionCompleted();

    enum States { Pending, Open, Closed, WaitingForInvoicePayment, Completed }

    States public status;
    address public currency;
    bytes32 public currencySymbol;

    bytes32 public invoiceId;
    string public _invoiceNumber;
    bytes32 public borrowerId;
    string public borrowerName;
    string public buyerName;

    uint public invoiceAmount;
    uint public fundingGoal;

    uint public deadline;

    string public IPFSDocumentHash;

    struct Bidder {
        uint bidderIndex;
        bytes32 bidderId;
        string name;
        uint bidAmount;
        bool hasReceivedTokensBack; // This flag is set when losing group receives its tokens back or when winner group gets its winnings
    }

    struct Group {
        uint groupIndex;
        string name;
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
            string _borrowerName,
            string _buyerName,
            bytes32 _invoiceId,
            string _invoiceNumber,
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
        status = States.Open;
    }

    modifier afterDeadline() { if (now >= deadline) _; }
    modifier onlyOpenAuction() { if (status != States.Open) { throw; } _; }

    function checkDeadline() returns(bool) {
        if (now > deadline) {
            if (status == States.Open) {
                status = States.Closed;
                EventAuctionClosed();
            }
            return true;
        }
        return false;
    }

    function getStatus() public constant returns (uint8) {
        return uint8(status);
    }

    function getGroupsCount() public constant returns (uint) {
        return groups.length;
    }

    function getGroup(uint groupIndex)
        public constant
        returns (string name, uint goal, uint biddersCount, uint amountRaised, bool hasReceivedTokensBack)
    {
        Group g = groups[groupIndex];

        return (g.name, g.goal, g.bidders.length, g.amountRaised, g.hasReceivedTokensBack);
    }

    function setGroupHasReceivedTokensBack(uint groupIndex) {
        groups[groupIndex].hasReceivedTokensBack = true;
    }

    function getGroupBidder(uint groupIndex, uint bidderIndex)
        public constant
        returns (bytes32 bidderId, string name, uint bidAmount, bool hasReceivedTokensBack)
    {
        Bidder b = groups[groupIndex].bidders[bidderIndex];

        return (b.bidderId, b.name, b.bidAmount, b.hasReceivedTokensBack);        
    }

    function setBidderHasReceivedTokensBack(uint groupIndex, uint bidderIndex) {
        groups[groupIndex].bidders[bidderIndex].hasReceivedTokensBack = true;
    }

    function setIPFSDocumentHash(string _hash) {
        IPFSDocumentHash = _hash;
    }

    function createGroup(string _name, uint _goal)
        onlyOpenAuction
        returns (uint8 err, uint groupIndex)
    {
        if(checkDeadline() == false && _goal >= fundingGoal && _goal <= invoiceAmount) {
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

    function findBidder(bytes32 bidderId) constant returns (uint8 err, uint groupIndex, uint bidderIndex) {
        for(groupIndex = 0; groupIndex < groups.length; groupIndex++) {
            for(bidderIndex = 0; bidderIndex < groups[groupIndex].bidders.length; bidderIndex++) {
                if (Utils.equal(groups[groupIndex].bidders[bidderIndex].bidderId, bidderId) == true) {
                    return (0, groupIndex, bidderIndex);
                }
            }
        }
        return (1, 0, 0);
    }

    function findBidder(uint groupIndex, bytes32 bidderId) constant returns (uint8 err, uint bidderIndex) {
        for(bidderIndex = 0; bidderIndex < groups[groupIndex].bidders.length; bidderIndex++) {
            if (Utils.equal(groups[groupIndex].bidders[bidderIndex].bidderId, bidderId) == true) {
                return (0, bidderIndex);
            }
        }
        return (1, 0);
    }

    function bid(uint groupIndex, bytes32 bidderId, string name, uint value)
        onlyOpenAuction
        onlyPopulous
        returns (uint8 err, uint finalValue, uint groupGoal, bool goalReached)
    {
        if(checkDeadline() == true || value == 0 || groups[groupIndex].goal == 0) {
            return (1, 0, 0, false);
        }
        
        if (groups[groupIndex].amountRaised + value > groups[groupIndex].goal) {
            value = SafeMath.safeSub(groups[groupIndex].goal, groups[groupIndex].amountRaised);
        }

        uint8 finderErr;
        uint bidderIndex;

        (finderErr, bidderIndex) = findBidder(groupIndex, bidderId);

        if (finderErr == 0) {
            groups[groupIndex].bidders[bidderIndex].bidAmount = SafeMath.safeAdd(groups[groupIndex].bidders[bidderIndex].bidAmount, value);
        } else {
            groups[groupIndex].bidders.push(Bidder(groups[groupIndex].bidders.length, bidderId, name, value, false));
        }

        groups[groupIndex].amountRaised = SafeMath.safeAdd(groups[groupIndex].amountRaised, value);

        EventNewBid(groupIndex, bidderId, name, value);

        goalReached = groups[groupIndex].amountRaised == groups[groupIndex].goal;

        if (goalReached == true) {
            winnerGroupIndex = groupIndex;
            status = States.Closed;
            
            EventGroupGoalReached(groupIndex, groups[groupIndex].name, groups[groupIndex].goal);
            EventAuctionClosed();
        }

        return (0, value, groups[groupIndex].goal, goalReached);
    }

    function waitingForPayment() onlyServer returns(bool) {
        if (status == States.Closed && sentToBeneficiary == true && sentToLosingGroups == true) {
            // Tokens have been sent to beneficiary
            // Tokens have been sent to loser groups

            status = States.WaitingForInvoicePayment;
            EventAuctionWaiting();
        }
    }

    function getAmountForBeneficiary() public constant returns (uint8 err, uint amount) {
        if (status == States.Closed && sentToBeneficiary == false) {
            return (0, groups[winnerGroupIndex].amountRaised);
        } else {
            return (1, 0);
        }
    }

    function setSentToBeneficiary() onlyPopulous {
        sentToBeneficiary = true;
    }

    function setSentToLosingGroups() onlyPopulous {
        sentToLosingGroups = true;
    }

    function setSentToWinnerGroup() onlyPopulous {
        sentToWinnerGroup = true;
        status = States.Completed;
        setGroupHasReceivedTokensBack(winnerGroupIndex);
    }

}