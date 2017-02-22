pragma solidity ^0.4.8;

import "./SafeMath.sol";
import "./Owned.sol";

/**
    The platform address is owner;
    Populous contract address is guardian;
    Functions, which don't require token transfers are onlyOwner;
    Functions, which do token transfers are onlyGuardian
*/
contract Crowdsale is Owned {

    event EventGroupCreated(uint256 groupId, string name, uint256 goal);
    event EventGroupGoalReached(uint256 groupId, string _name, uint256 goal);
    event EventNewBid(uint256 groupId, string bidderId, string name, uint256 value);

    enum States { Pending, Open, Closed, WaitingForInvoicePayment, Completed }

    States status;
    address currency;

    // late interest cap at 7% (7 days 1%)
    uint public latePaymentInterest = 0;

    string public invoiceId;
    string public borrowerId;
    string borrowerName;
    string buyerName;

    uint public invoiceAmount;
    uint public fundingGoal;

    uint public deadline;

    struct bidder {
        string bidderId;
        string name;
        uint bidAmount;
    }

    struct group {
        uint groupId;
        string groupName;
        uint goal;
        mapping(string => bidder) bidders;
        uint amountRaised;
        bool isRefunded;
    }

    //Groups
    group[] public groups;
    uint public winnerGroupId;
    bool public sentToBeneficiary;
    bool public sentToLosingGroups;
    bool public sentToWinnerGroup;

    //Constructor
    function Crowdsale
            address _owner,
            address _guardian,
            address _currency,
            string _borrowerId,
            string _borrowerName,
            string _buyerName,
            string _invoiceId,
            uint _invoiceAmount,
            uint _fundingGoal)
        Owned(_owner, _guardian)
    {
        currency = _currency;
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

    function getGroup(groupId) returns (uint groupId, string groupName, uint goal, mapping(string => bidder) bidders, uint amountRaised, bool isRefunded) {

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
            groups.push(group({groupId: groups.length, groupName: _name, amountRaised: 0, goal: _goal, isWinner: false, isRefunded: false}));
            EventGroupCreated(groups.length - 1, _name, _goal);

            return true;
        } else {
            return false;
        }
    }

    function bid(uint groupId , string bidderId, string name, uint value)
        onlyOpenAuction
        returns (uint finalValue)
    {
        group G = groups[groupId];

        if(isDeadlineReached() == true || value == 0 || G.goal == 0) { throw; }
        
        if (G.amountRaised + value > G.goal) {
            value = SafeMath.safeSub(G.goal, G.amountRaised);
        }

        G.bidders[bidderId].name = name;
        G.bidders[bidderId].bidAmount = SafeMath.safeAdd(G.bidders[bidderId].bidAmount, value);

        G.amountRaised = SafeMath.safeAdd(G.amountRaised, value);

        EventNewBid(groupId, bidderId, name, value);

        if (G.amountRaised == G.goal) {
            winnerGroupId = groupId;
            status = States.Closed;

            EventGroupGoalReached(groupId, G.groupName, G.goal);
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
            return groups[winnerGroupId].amountRaised;
        }
    }

    function setSentToBeneficiary() onlyGuardian {
        sentToBeneficiary = true;
    }

    function setGroupRefunded(groupId) onlyGuardian returns (bool) {
        if (groupId != winnerGroupId) {
            groups[groupId].isRefunded = true;

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