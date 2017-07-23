pragma solidity ^0.4.8;

import "./SafeMath.sol";
import "./Utils.sol";
import "./withAccessManager.sol";

contract Crowdsale is withAccessManager {

    event EventGroupCreated(uint groupIndex, string name, uint goal);
    event EventGroupGoalReached(uint groupIndex, string _name, uint goal);
    event EventNewBid(uint groupIndex, bytes32 bidderId, string name, uint value);
    event EventAuctionOpen();
    enum AuctionCloseReasons { GroupGoalReached, DeadlineReached, BorrowerClosed }
    event EventAuctionClosed(uint8 reasonCode);
    event EventAuctionWaiting();
    event EventPaymentReceived(uint paidAmount);
    event EventAuctionCompleted();

    enum States { Pending, Open, Closed, WaitingForInvoicePayment, PaymentReceived, Completed }

    States public status;

    bytes32 public currencySymbol;
    bytes32 public invoiceId;
    string public _invoiceNumber;
    bytes32 public borrowerId;
    uint public invoiceAmount;
    uint public fundingGoal;
    uint public deadline;
    uint public platformTaxPercent;

    string public signedDocumentIPFSHash;

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
        uint biddersReceivedTokensBack;
        bool hasReceivedTokensBack; // This is set to true when the flag hasReceivedTokensBack is set to true for all bidders in the group
    }

    //Groups
    Group[] public groups;
    uint public groupsReceivedTokensBack;
    uint public winnerGroupIndex;
    bool public hasWinnerGroup;

    uint public paidAmount;

    bool public sentToBeneficiary;
    bool public sentToLosingGroups;
    bool public sentToWinnerGroup;

    //Constructor
    function Crowdsale(
            address _accessManager,
            bytes32 _currencySymbol,
            bytes32 _borrowerId,
            bytes32 _invoiceId,
            string _invoiceNumber,
            uint _invoiceAmount,
            uint _fundingGoal,
            uint _platformTaxPercent,
            string _signedDocumentIPFSHash)
            withAccessManager(_accessManager)
    {
        currencySymbol = _currencySymbol;
        borrowerId = _borrowerId;
        invoiceId = _invoiceId;
        invoiceAmount = _invoiceAmount;
        fundingGoal = _fundingGoal;
        platformTaxPercent = _platformTaxPercent;
        signedDocumentIPFSHash = _signedDocumentIPFSHash;

        deadline = now + 24 hours;
        status = States.Open;
    }

    modifier onlyOpenAuction() { if (status == States.Open) { _; } }

    function checkDeadline() returns(bool) {
        if (now > deadline) {
            if (status == States.Open) {
                status = States.Closed;
                EventAuctionClosed(uint8(AuctionCloseReasons.DeadlineReached));
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

    function getGroupBidder(uint groupIndex, uint bidderIndex)
        public constant
        returns (bytes32 bidderId, string name, uint bidAmount, bool hasReceivedTokensBack)
    {
        Bidder b = groups[groupIndex].bidders[bidderIndex];

        return (b.bidderId, b.name, b.bidAmount, b.hasReceivedTokensBack);
    }

    function setBidderHasReceivedTokensBack(uint groupIndex, uint bidderIndex) onlyPopulous {
        groups[groupIndex].bidders[bidderIndex].hasReceivedTokensBack = true;
        groups[groupIndex].biddersReceivedTokensBack++;

        if (groups[groupIndex].biddersReceivedTokensBack == groups[groupIndex].bidders.length) {
            groups[groupIndex].hasReceivedTokensBack = true;
            groupsReceivedTokensBack++;
            
            if (groups.length == 1) {
                setSentToLosingGroups();
                setSentToWinnerGroup();
            } else if (groups.length - 1 == groupsReceivedTokensBack) {
                setSentToLosingGroups();
            } else if (groups.length == groupsReceivedTokensBack) {
                setSentToWinnerGroup();
            }
        }
    }

    function setPaidAmount(uint _paidAmount) onlyPopulous {
        if (status == States.WaitingForInvoicePayment) {
            paidAmount = _paidAmount;
            status = States.PaymentReceived;

            EventPaymentReceived(paidAmount);
        }
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
            hasWinnerGroup = true;
            status = States.Closed;

            EventGroupGoalReached(groupIndex, groups[groupIndex].name, groups[groupIndex].goal);
            EventAuctionClosed(uint8(AuctionCloseReasons.GroupGoalReached));
        }

        return (0, value, groups[groupIndex].goal, goalReached);
    }

    function borrowerChooseWinner(uint groupIndex)
        onlyOpenAuction
        onlyServer
    {
        if (groups[groupIndex].amountRaised > 0) {
            winnerGroupIndex = groupIndex;
            hasWinnerGroup = true;
            status = States.Closed;

            EventAuctionClosed(uint8(AuctionCloseReasons.BorrowerClosed));
        }
    }

    function waitingForPayment() onlyServer returns(bool) {
        return _waitingForPayment();
    }

    function _waitingForPayment() private returns(bool) {
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

        // We have only 1 group (the winning group) and we set 
        // the losing groups as refunded automatically.
        if (groups.length == 1) {
            setSentToLosingGroups();
        }
    }

    function setSentToLosingGroups() private  {
        sentToLosingGroups = true;
        
        _waitingForPayment();
    }

    function setSentToWinnerGroup() private {
        sentToWinnerGroup = true;
        status = States.Completed;
        groups[winnerGroupIndex].hasReceivedTokensBack = true;
        
        EventAuctionCompleted();
    }

}