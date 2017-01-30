pragma solidity ^0.4.8;

import "./CurrencyToken.sol";

contract Crowdsale {

    event GroupCreated(address _creator, uint256 _groupId, string _name, uint256 _goal);
    event NewBid(address _bidder, uint256 _groupId, string _name, uint256 _value);

    string public name = "This is contract name";

    CurrencyToken public CurrencyTokenInstance;
    uint public invoiceAmount;
    string public invoiceNumber;
    uint public invoiceDueDate;

    /*Description of contract given by borrowers*/
    string public description;

    /*Company Name of Invoice*/
    string public companyName;

    /*Debter Name*/
    string public debterName;

    /*Contact Current Status : OPEN , CLOSED */
    string public status;

    /*Interest Range of borrowers they are willing to negotiate */
    uint public interest;

    uint public latePaymentInterest;

    address public beneficiary;

    uint public fundingGoal; // Calculate Percentage of InvoiceAmount

    uint public deadline; // In Minute Timestamp

    group public winningGroup;

    bool public isDeadlineReached;

    uint public minimumLoss; // Minimum amount borrower can loss in %
    uint public maximumLoss; // Maximum amount borrower can loss in %



    //Single Person
    struct person{
        string name;
        uint bidAmount;
        address addr;
    }

    //Single Group
    struct group {
        uint groupId;
        string groupName;
        uint numOfPersons;
        uint amountRaised;
        uint goal;
        mapping(uint => person) persons;
    }

    bool public isPersonAvailableInGroup;
    group public inGroupPersonChecked;
    address public personChecked;
    mapping(uint => person) public selectedGroupPersons;
    person[] emptyPersons;


    //Groups
    mapping (uint => group) public groups;

    uint numOfGroups = 0;

    //Constructor
    function Crowdsale(
            address _currencyToken,
            string _invoiceNumber,
	        uint _invoiceAmount,
	        uint _minimumLoss,
            uint _maximumLoss,
            string _companyName,
            uint _invoiceDueDate,
            string _description,
            string _debterName,
            string _status,
            uint _interest,
            uint _latePaymentInterest,
            address _ifSuccessfulSendTo
            /*,
            uint _fundingGoalInEthers,
            uint _durationInMinutes */
        ){
            CurrencyTokenInstance = CurrencyToken(_currencyToken);
            invoiceNumber  = _invoiceNumber;
	        invoiceAmount  = _invoiceAmount;
	        minimumLoss  =  _minimumLoss;
            maximumLoss = _maximumLoss;
            invoiceDueDate = _invoiceDueDate;
            companyName   = _companyName;
            description   = _description;
            debterName    = _debterName;
            status        = _status;
            interest      = _interest;
            latePaymentInterest = _latePaymentInterest;
            beneficiary = _ifSuccessfulSendTo;
             /*
            /*
            deadline = now + _durationInMinutes * 1 minutes;
            */

         //   invoiceAmount  = 100 ether;
        //    invoiceDueDate = 1479847241; *
        //    companyName   = 'ABC ltd';
         //   description   = 'ABC ltd description';
         //   debterName    = 'ABC Debter';
         //   status        = 'OPEN';
         //   interest      = 6;
           // latePaymentInterest = 1;
        //    minimumLoss  =  90 ether;
          //  maximumLoss = 94 ether;

          //  beneficiary = 0x85e86550AC221e51c45DAe92dc455DbF99B59CFf;
            deadline = now + 180 * 1 minutes;

    }

    modifier afterDeadline() { if (now >= deadline) _; }

    function addNewGroup(  string _name, uint _goal){

      if ( stringsEqual( status, "CLOSED" ) ){throw;}

       // Don't allow group to set pay away % Less than minimumLoss & More than maximumLoss
        if(  _goal < minimumLoss || _goal > maximumLoss ){ throw; }


        groups[numOfGroups] =  group( { groupId : numOfGroups,  groupName : _name, amountRaised : 0, numOfPersons : 0, goal : _goal } ) ;
        GroupCreated(msg.sender, numOfGroups, _name, _goal);
        numOfGroups++;
    }



    function _checkPersonInGroup( uint groupId, address personAddress  ) returns(bool){

        uint i=0;
        group G = groups[groupId];

        for(i;i<G.numOfPersons;i++){
            if(G.persons[i].addr == personAddress){ return true; }
        }

        return false;
    }


    function checkPersonInGroup(uint groupId){
      isPersonAvailableInGroup = _checkPersonInGroup( groupId, msg.sender );
      if(isPersonAvailableInGroup){
        inGroupPersonChecked = groups[groupId];
      }else{
        inGroupPersonChecked =   group( { groupId : 0,  groupName : 'NONE', amountRaised : 0, numOfPersons : 0, goal : 0} );
      }
      personChecked = msg.sender;

    }


    function _getIndexPersonInGroup( uint groupId, address personAddress  ) returns(uint){

        if(!_checkPersonInGroup(groupId, personAddress)){
            throw;
        }

        uint i=0;
        group G = groups[groupId];

        while( i < G.numOfPersons ){
          if( G.persons[i].addr == personAddress ){
            return i;
          }
          i++;
        }

    }

    function selectGroupPersons(uint groupId){

        group G = groups[groupId];
        uint i = 0;
        for( i ; i < G.numOfPersons; i++ ){
            selectedGroupPersons[i] = G.persons[i];
        }
    }


function checkAllowance() constant returns (uint256) {
    return CurrencyTokenInstance.allowance(msg.sender, address(this));
}

    // Don't need that modifier
    function sendBid(   uint groupId , string name, uint256 value ) {
        if(isDeadlineReached ){ throw; }

        if (now >= deadline){
            isDeadlineReached = true;
            throw;
        }

      if ( stringsEqual( status, "CLOSED" ) ){throw;}
      if (CurrencyTokenInstance.transferFrom(msg.sender, address(this), value) == false) { throw; }

      group G = groups[groupId];

      if(_checkPersonInGroup(groupId, msg.sender)){//Check person exist in group
          //Avaialble in group
        person P = G.persons[ _getIndexPersonInGroup(groupId, msg.sender)  ];
        P.bidAmount = P.bidAmount + value;

      }else{//Create new person in group
          G.persons[G.numOfPersons+1] = person({name:name, bidAmount : value, addr : msg.sender});
          G.numOfPersons++;
      }

      // Increase group raised amount
      G.amountRaised =  G.amountRaised + value;
      NewBid(msg.sender, groupId, name, value);

      // Check winner on every payment received
      // Check if group goal is reached
      if( G.amountRaised >= G.goal  ){
          winningGroup = G;
          status = 'CLOSED';

      }

    }


    function withdrawBid( uint _groupId  ) returns(bool){

      if( !stringsEqual( status , "CLOSED"  )  ){
        throw;
      }

      uint personIndex = _getIndexPersonInGroup(_groupId, msg.sender);
      group G =  groups[_groupId];


      if(winningGroup.groupId == _groupId){  throw; }

      person P = G.persons[personIndex];

      if(CurrencyTokenInstance.transfer(P.addr, P.bidAmount) == false){
          throw;
      }

      G.numOfPersons--;//Decrease the count
      G.amountRaised = G.amountRaised - P.bidAmount;//Decrease the amount raised
      delete G.persons[personIndex]; // Remove the person from group

      return true;


    }


  function stringsEqual(string storage _a, string memory _b) internal returns (bool) {
    bytes storage a = bytes(_a);
    bytes memory b = bytes(_b);
    if (a.length != b.length)
      return false;
    // @todo unroll this loop
    for (uint i = 0; i < a.length; i ++)
      if (a[i] != b[i])
        return false;
    return true;
  }


}