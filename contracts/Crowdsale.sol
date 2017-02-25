pragma solidity ^0.4.8;

import "./SafeMath.sol";
import "./StringUtils.sol";
import "./withAccessControl.sol";

/**
    The platform address is owner;
    Populous contract address is guardian;
    Functions, which don't require token transfers are onlyOwner;
    Functions, which do token transfers are onlyGuardian
*/
contract Crowdsale is withAccessControl {

    event EventGroupCreated(uint256 groupIndex, string name, uint256 goal);
    event EventGroupGoalReached(uint256 groupIndex, string _name, uint256 goal);
    event EventNewBid(uint256 groupIndex, string bidderId, string name, uint256 value);

    enum SuccessFlag { Success, Fail }
    enum States { Pending, Open, Closed, WaitingForInvoicePayment, Completed }

    States status;
    address public currency;
    string public currencySymbol;

    // late interest cap at 7% (7 days 1%)
    uint public latePaymentInterest = 0;

    string public invoiceId;
    string public borrowerId;
    string public borrowerName;
    string public buyerName;

    uint public invoiceAmount;
    uint public fundingGoal;

    uint public deadline;

    struct Bidder {
        uint bidderIndex;
        string bidderId;
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
    uint public winnergroupIndex;
    bool public sentToBeneficiary;
    bool public sentToLosingGroups;
    bool public sentToWinnerGroup;

    //Constructor
    function Crowdsale
            address _server,
            address _guardian,
            address _populous,
            address _currency,
            string _currencySymbol,
            string _borrowerId,
            string _borrowerName,
            string _buyerName,
            string _invoiceId,
            uint _invoiceAmount,
            uint _fundingGoal)
        withAccessControl(_server, _guardian, _populous)
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
        returns (string name, uint goal, uint biddersCount, uint amountRaised, bool hasReceivedTokensBack)
    {
        Group g = groups[groupIndex];

        return (g.name, g.goal, g.bidders.length, g.amountRaised, g.hasReceivedTokensBack);
    }

    function setGroupHasReceivedTokensBack(uint groupIndex) {
        CS.groups[groupIndex].hasReceivedTokensBack = true;
    }

    function getGroupBidder(uint groupIndex, uint bidderIndex)
        public constant
        returns (string bidderId, string name, uint bidAmount, bool hasReceivedTokensBack)
    {
        Bidder b = groups[groupIndex].bidders[bidderIndex];

        return (b.bidderId, b.name, b.bidAmount, b.hasReceivedTokensBack);        
    }

    function setBidderHasReceivedTokensBack(uint groupIndex, uint bidderIndex) {
        CS.groups[groupIndex].bidders[bidderIndex].hasReceivedTokensBack = true;
    }    

    function openAuction() onlyGuardian returns (bool success) {
        if (status == States.Pending) {
            status = States.Open;
            return true;
        } else {
            return false;
        }
    }

    function createGroup(string _name, uint _goal)
        onlyOpenAuction
        returns (bool success)
    {
        if(isDeadlineReached() == false && _goal >= fundingGoal && _goal <= invoiceAmount) {
            groups.push(Group({groupIndex: groups.length, name: _name, amountRaised: 0, goal: _goal, isWinner: false, isRefunded: false}));
            EventGroupCreated(groups.length - 1, _name, _goal);

            return true;
        } else {
            return false;
        }
    }

    function findBidder(uint groupIndex, string bidderId) constant returns (SuccessFlag found, uint bidderIndex) {
        for(uint i = 0; i < groups[groupIndex].bidders.length; i++) {
            if (StringUtils.equal(groups[groupIndex].bidders[i].bidderId, bidderId) == true) {
                return (SuccessFlag.Success, i);
            }
        }
        return (SuccessFlag.Fail, 0);
    }

    function bid(uint groupIndex, string bidderId, string name, uint value)
        onlyOpenAuction
        onlyGuardian
        returns (uint finalValue)
    {
        group G = groups[groupIndex];

        if(isDeadlineReached() == true || value == 0 || G.goal == 0) { throw; }
        
        if (G.amountRaised + value > G.goal) {
            value = SafeMath.safeSub(G.goal, G.amountRaised);
        }

        uint bidderIndex;
        SuccessFlag found;

        (found, bidderIndex) = findBidder(groupIndex, bidderId);

        if (found == SuccessFlag.Success) {
            G.bidders[bidderIndex].bidAmount = SafeMath.safeAdd(G.bidders[bidderIndex].bidAmount, value);
        } else {
            G.bidders.push(Bidder(G.bidders.length, bidderId, name, value, false));
        }

        G.amountRaised = SafeMath.safeAdd(G.amountRaised, value);

        EventNewBid(groupIndex, bidderId, name, value);

        if (G.amountRaised == G.goal) {
            winnergroupIndex = groupIndex;
            status = States.Closed;

            EventGroupGoalReached(groupIndex, G.name, G.goal);
        }

        return value;
    }

    function endAuction() onlyOwner returns(bool) {
        if (status == States.Closed) {
            // Send tokens to beneficiary
            // Send tokens back to loser groups

            status = States.WaitingForInvoicePayment;
        }
    }

    function getAmountForBeneficiary() onlyGuardian returns (uint) {
        if (status == States.WaitingForInvoicePayment && sentToBeneficiary == false) {
            return groups[winnergroupIndex].amountRaised;
        }
    }

    function setSentToBeneficiary() onlyGuardian {
        sentToBeneficiary = true;
    }

    function setGroupRefunded(groupIndex) onlyGuardian returns (bool) {
        if (groupIndex != winnergroupIndex) {
            groups[groupIndex].hasReceivedTokensBack = true;

            return true;
        } else {
            return false;
        }
    }

    function setSentToLosingGroups() onlyGuardian {
        sentToLosingGroups = true;
    }

    function invoicePaymentReceived() onlyOwner {
        if (status == States.WaitingForInvoicePayment) {
            // Send tokens to winner group

            status = States.Completed;
        }
    }

    function setSentToWinnerGroup() onlyGuardian {
        sentToWinnerGroup = true;
    }

}