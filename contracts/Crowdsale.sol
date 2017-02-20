pragma solidity ^0.4.8;

import "./CurrencyToken.sol";

contract Crowdsale is Owned, SafeMath {

    event EventGroupCreated(uint256 groupId, string name, uint256 goal);
    event EventGroupGoalReached(uint256 groupId, string _name, uint256 goal);
    event EventNewBid(uint256 groupId, string bidderId, string name, uint256 value);

    enum States { Pending, Open, Closed, WaitingForInvoicePayment, Completed }

    States status;
    CurrencyToken CurrencyTokenInstance;

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
        bool isWinner;
        bool isRefunded;
    }

    //Groups
    group[] public groups;

    //Constructor
    function Crowdsale(
            address _currencyToken,
            string _borrowerId,
            string _borrowerName,
            string _buyerName,
            string _invoiceId,
            uint _invoiceAmount,
            uint _fundingGoal
        )
    {
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

    function openAuction() onlyOwner returns (bool success) {
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

    function sendBid(uint groupId , string bidderId, string name, uint value)
        onlyOpenAuction
        returns (uint finalValue)
    {
        group G = groups[groupId];

        if(isDeadlineReached() == true || value == 0 || G.goal == 0) { throw; }
        
        if (G.amountRaised + value > G.goal) {
            value = safeSub(G.goal, G.amountRaised);
        }

        G.bidders[bidderId].name = name;
        G.bidders[bidderId].bidAmount = safeAdd(G.bidders[bidderId].bidAmount, value);

        G.amountRaised = safeAdd(G.amountRaised, value);

        EventNewBid(groupId, bidderId, name, value);

        if (G.amountRaised == G.goal) {
            G.isWinner = true;
            status = States.Closed;

            EventGroupGoalReached(groupId, G.groupName, G.goal);
        }

        return value;
    }

    function auctionEnd() returns(bool) {
        if (status == States.Closed) {
            // Send tokens to beneficiary
            // Send tokens back to loser groups

            status = States.WaitingForInvoicePayment;
        }
    }

    function invoicePaymentReceived() onlyOwner {
        if (status == States.WaitingForInvoicePayment) {
            // Send tokens to winner group

            status = States.Completed;
        }
    }

}