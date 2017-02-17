pragma solidity ^0.4.8;

import "./CurrencyToken.sol";

contract Crowdsale {

    event EventGroupCreated(uint256 groupId, string name, uint256 goal);
    event EventGroupGoalReached(uint256 groupId, string _name, uint256 goal);
    event EventNewBid(uint256 groupId, string bidderId, string name, uint256 value);

    enum States { Pending, Open, Closed, WaitingForInvoicePayment, Completed }

    States status;
    CurrencyToken CurrencyTokenInstance;

    // late interest cap at 7% (7 days 1%)
    uint public latePaymentInterest = 0;

    uint public invoiceId;
    uint public borrowerId;
    string borrowerName;
    string buyerName;

    uint public invoiceAmount;
    uint public fundingGoal;

    uint public deadline;

    uint public winnerGroupId;

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
    }

    //Groups
    group[] public groups;

    //Constructor
    function Crowdsale(
            address _currencyToken,
            string _borrowerName,
            string _buyerName,
            uint _invoiceAmount,
            uint _fundingGoal
        ){
        borrowerName = _borrowerName;
        buyerName = _buyerName;
        invoiceAmount = _invoiceAmount;
        fundingGoal = _fundingGoal;

        deadline = now + 24 hours;
        status = States.Pending;
    }

    modifier afterDeadline() { if (now >= deadline) _; }
    modifier onlyOpenAuction() { if (status != States.Open) { throw; } _; }

    function checkDeadline() returns(bool isClosed) {
        if (now > deadline && status == States.Open) {
            status = States.Closed;
            return true;
        }
        return false;
    }

    function openAuction() returns (bool success) {
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
        if(checkDeadline() == false && _goal >= fundingGoal && _goal <= invoiceAmount) {
            groups.push(group( { groupId : groups.length,  groupName : _name, amountRaised : 0, goal : _goal } ));
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

        if(checkDeadline() == true || value == 0 || G.goal == 0) { throw; }
        
        if (G.amountRaised + value > G.goal) {
            value = G.goal - G.amountRaised;
        }

        G.bidders[bidderId].name = name;
        G.bidders[bidderId].bidAmount += value;

        G.amountRaised += value;

        EventNewBid(groupId, bidderId, name, value);

        if (G.amountRaised == G.goal) {
            winnerGroupId = groupId;
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

    function invoicePayment() {
        if (status == States.WaitingForInvoicePayment) {
            // Send tokens to winner group

            status = States.Completed;
        }
    }

}