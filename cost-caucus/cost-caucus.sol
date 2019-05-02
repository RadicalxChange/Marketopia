pragma solidity ^0.5.1;

contract CostCaucus {

    uint maxMembers;

   enum CostCycleStatus {
        NoRecord,
        Started,
        ClaimPeriod
    }

    struct COSTGroupDetails{

        uint extendHashTableRule;
        uint averageSeatPrice;
        uint24 totalMembers;
        uint32 tokenPool;
        uint totalDeedTransactionAmount;
        uint totalDeedTransactions;

        uint costCycleLength;
        CostCycleStatus status;
        string ipfsHash;
    }

    COSTGroupDetails caucus;

    enum KYCStates { None, Applied, Approved, Revoked }
    struct Deed {
        address owner;
        uint strikePrice;
        uint COST;//10%
        bool paid;
        uint withdrawAmount;
        bool withdrawRecord;
        bool canWithdraw;
        uint startDate;
        uint deedTerm;//1 year
        KYCStates KYCState;
        bool expired;
        string ipfsHash;
    }

    mapping(address => Deed) private deeds;

    uint public numRegistered;
    
  
////// CAUCUS MANAGEMENT ////////  

    
    function openFiscalYear() public{
        //TODO: implement features
        require(true, "that a specified delay period has elapsed since the close of the Filscal year.");
        require(true, "reset token pool amount and add space for more members if required.");
        require(true, "Move any tokens not claimed from token pool to LR contract for QPG matching pool");
        
        
        
        caucus.status= CostCycleStatus.Started;
    }
  
    function closeFiscalYear() public{
        //TODO: implement features
        require(true, "that a specified delay period has elapsed since the open of the Filscal year.");
        caucus.status= CostCycleStatus.ClaimPeriod;
    }

    event Bought(address _buyer, uint bid);
    function buy( address deedIndex, uint bid, uint COST) public payable returns (bool){
        //TODO: buy deed
    }

    function purchaseSeat( address buyer, address deedIndex, uint32 bid) internal {
        //TODO: purchase deed
    }
    
}