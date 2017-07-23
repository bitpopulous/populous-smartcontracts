pragma solidity ^0.4.8;

import "./SafeMath.sol";
import "./withAccessManager.sol";
import "./DepositContract.sol";

contract DepositContractsManager is withAccessManager {

    address tokenContractAddress;

    struct Deposit {
        address depositContract;
        uint inUse;
        uint releaseDate;
    }
    mapping (bytes32 => Deposit) deposits;

    function CrowdsaleManager(address _accessManager, address _tokenContractAddress)
        withAccessManager(_accessManager)
    {
        tokenContractAddress = _tokenContractAddress;
    } 

    function create(bytes32 clientId) returns (address) {
        deposits[clientId].depositContract = new DepositContract(tokenContractAddress);

        if (!deposits[clientId].depositContract) throw;

        return deposits[clientId].depositContract;
    }

    function deposit(address clientId, uint amount) returns (bool) {
        DepositContract o = DepositContract(deposits[clientId].depositContract);

        if (o && o.balanceOf() >= amount) {
            if (o.transfer(this, amount)) {
                deposits[clientId].inUse = SafeMath.safeSub(deposits[clientId].inUse, amount);
                
                if (!deposits[clientId].releaseDate) {
                    deposits[clientId].releaseDate = now + 1 month;
                }
                return true;
            }
        }
        return false;
    }

    function releaseDeposit(address clientId, address receiver) returns (bool) {
        if (deposits[clientId].inUse > 0 && deposits[clientId].releaseDate > now) {
            if (iERC20Token(deposits[clientId].depositContract).transfer(receiver, deposits[clientId].inUse)) {
                deposits[clientId].inUse = 0;
                deposits[clientId].releaseDate = 0;

                return true;
            }
        }
        return false;
    }
}