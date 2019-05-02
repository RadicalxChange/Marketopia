pragma solidity ^0.5.1;

contract CostCaucus {

    //tallies
    uint public maxMembers;
    uint public totalMembers;
    uint public totalDeedTransactions;
    uint public totalDeedTransactionAmount;
    
    //constants
    uint public extendHashTableRule;
    uint public cycleLength;
    uint public claimPeriodLength;
    string public ipfsHash;
    address public grantMatchContract;

    //reset
    CycleStatus public status;
    uint public cycleStartTime;
    uint public cycleEndTime;
    uint public tokenPool;
    uint public participants;
    uint public balance;

    constructor(string memory _ipfsHash) public {
      owners[msg.sender] = true;
      numOwners = 1;
      ipfsHash= _ipfsHash;
    }
    ////// OWNER MANAGEMENT ////////
    // State
    mapping(address => bool) private owners;
    uint public numOwners;
    
    
    // Modifier
    modifier onlyOwner(){
        require(owners[msg.sender], "Sender must be owner.");
        _;
    }
    
    // Getter
    function isOwner(address maybeOwner) public view returns (bool) {
        return owners[maybeOwner];
    }
    
    // Setters
    event OwnerAdded(address indexed approvingOwner, address indexed newOwner);
    function addOwner(address newOwner) public onlyOwner {
        if (owners[newOwner] == false && newOwner != address(0)){
          owners[newOwner] = true;
          numOwners += 1;
          emit OwnerAdded(msg.sender, newOwner);
        }
    }
    
    event OwnerRemoved(address indexed removingOwner, address indexed removedOwner);
    function removeOwner(address removedOwner) public onlyOwner {
        require(msg.sender != removedOwner, "Owners cannot remove themselves.");
        if (owners[removedOwner] == true){
          owners[removedOwner] = false;
          numOwners -= 1;
          emit OwnerRemoved(msg.sender, removedOwner);
        }
    }
////// KYC MANAGEMENT ////////
    enum KYCStates { None, Applied, Approved, Blacklist }
    
    mapping(address => Registration) private registry;
    struct Registration {
        KYCStates KYCState;
        address PersonalRegistry;
    }
    
    // Modifier
    modifier onlyMember(){
        require(registry[msg.sender].KYCState== KYCStates.Approved, "Sender must be owner.");
        _;
    }
    uint public numRegistered;
    
    event Approved(address indexed approvingOwner, address indexed voter);
    function addMember(address registrant) public onlyOwner {
        numRegistered++;
        require(registry[registrant].KYCState != KYCStates.Blacklist, "approve can only be called on registrants who are not Blacklisted ");
        registry[registrant].KYCState = KYCStates.Approved;
        emit Approved(msg.sender, registrant);
        
    }
    
    event Revoked(address indexed revertingOwner, address indexed entry);
    function removeMember(address member) public onlyOwner {
        registry[member].KYCState = KYCStates.Blacklist;
        emit Revoked(msg.sender, member);
    }
    
    function canParticipate(address member) public view returns (bool){
        if (registry[member].KYCState == KYCStates.Approved) return true;
        return false;
        
    }
      
////// CAUCUS MANAGEMENT //////// 
    enum CycleStatus {Configure,PurchasePeriod,ClaimPeriod}
    
    struct Deed {
        //constant
        bool issued;
        address owner;
        uint deedTerm;
        uint startDate;
        uint strikePrice;
        string attachment;

        //sell /expire
        bool sold;
        bool expired;
        bool withdrawn;
        bool canWithdraw;
        uint withdrawAmount;
        uint expiredDate;
        uint withdrawDate;
       
    }


    mapping(address => Deed) private deeds;



    function openFiscalYear() payable public{
        //TODO: clean up
        require(true, "that a specified delay period has elapsed since the close of the Filscal year.");
        require(true, "reset token pool amount and add space for more members if required.");
        require(true, "Move any tokens not claimed from token pool to LR contract for QPG matching pool");
        require(now >= cycleEndTime + claimPeriodLength);
        cycleStartTime = now;
        participants = 0;
        tokenPool = 0;
        balance = 0;
        status = CycleStatus.PurchasePeriod;

        grantMatchContract.call.value(msg.value).gas(20317)("");
        
     
        
    }
  
    function closeFiscalYear() public{
        require(true, "that a specified delay period has elapsed since the close of the Filscal year.");
        require(now >= cycleStartTime + cycleLength);
        
        if(totalMembers == maxMembers){
            maxMembers += extendHashTableRule;
        }
        status= CycleStatus.ClaimPeriod;
        cycleEndTime = now;
        
        
    }
    //TODO: Renew deed 
    //PAY StrikePrice+COST to get a deed with strike price BID-COST
    function purchaseSeat( address buyer, address deedIndex) public payable {
        require(canPurchaseSeat( buyer,  deedIndex,  msg.value));
        balance += msg.value;
        sellDeed( buyer,  deedIndex,  msg.value);
    }
    function canPurchaseSeat(address buyer, address deedIndex, uint bid) public view returns(bool) {   
        Deed memory deed = deeds[deedIndex];
        Deed memory buyerDeed = deeds[buyer];
        if (!deed.issued) return false;
        // require buyer cannot buy his own seat
        if (buyer == deedIndex) return false;
        //require bid is greater than strike price + COST
        if ((bid - deed.strikePrice) >= deed.strikePrice/uint(10)) return false;
        //require buyer doesn't have an issued deed that is not expired
        if (buyerDeed.issued && !buyerDeed.expired) return false;
        //require buyer doesn't have an issued deed that has been sold 
        if (buyerDeed.issued && buyerDeed.sold) return false;
        //require the current cost cycle has started
        if (status != CycleStatus.PurchasePeriod) return false;
        //require deed was issued and has not been sold or expired
        if (deed.issued && !deed.expired && !deed.sold) return true ;
    }
    //TODO: make private
    function sellDeed(address buyer, address deedIndex, uint bid) public returns (bool){
        Deed storage oldDeed = deeds[deedIndex];
        uint amount = uint((bid - bid/uint(10))/1 ether);
        
        oldDeed.expired=true;
        oldDeed.expiredDate = now;
        // strike price is 90% of bid 
        oldDeed.withdrawAmount= amount;
        oldDeed.canWithdraw=true;
        oldDeed.sold=true;

        Deed storage newDeed = deeds[buyer];
        newDeed.issued = true;
        newDeed.expired = false;
        newDeed.withdrawAmount = 0;
        newDeed.sold = false;
        newDeed.owner = buyer;
        // strike price is 90% of bid 
        newDeed.strikePrice = bid - bid/uint(10);
        newDeed.startDate = now;
        newDeed.deedTerm = 60*60*24*365;


        tokenPool += bid-amount;
        totalDeedTransactionAmount += bid;
        totalDeedTransactions +=1;

        return true;
    }

    function withdrawSale (address deedIndex) public {
        Deed storage soldDeed = deeds[deedIndex];
        require(status == CycleStatus.ClaimPeriod);
        require(deedIndex == msg.sender);
        require(soldDeed.sold == true);
        require(soldDeed.canWithdraw== true);
        require(soldDeed.withdrawn == false);

        soldDeed.withdrawn = true;
        soldDeed.canWithdraw = false;
        soldDeed.withdrawDate = now;

        uint _amount = soldDeed.withdrawAmount;
        msg.sender.transfer(_amount);
        balance -= _amount;
    }

    //PAY COST to get a deed with strike price COST*10 > Average Deed Strike Price
    function createNewSeat( address buyer) public payable {
        require(canCreateNewSeat( buyer,  msg.value));
        createDeed( buyer, msg.value) ;
    }
    function canCreateNewSeat(address buyer, uint bid) public view returns(bool){ 
        Deed memory deed = deeds[buyer];
        //require the max number of caucus members is greater than the current number of members
        if (maxMembers <= totalMembers) return false;
        //require the current reclaim cycle has started
        if (status != CycleStatus.ClaimPeriod) return false;
        //require a bid 
        if (bid*10 < totalDeedTransactionAmount/totalDeedTransactions) return false;
        //require the deed has not already been issued
        if (!deed.issued) return true ;      
    }
    //TODO: make private
    function createDeed(address buyer, uint bid) public returns(bool){
        
        Deed storage deed = deeds[buyer];
        deed.issued = true;
        deed.expired = false;
        deed.owner = buyer;
        deed.withdrawAmount = 0;
        deed.sold = false;
        deed.owner = buyer;
        deed.strikePrice = bid*10;
        deed.startDate = now;
        deed.deedTerm = 60*60*24*365;

        totalMembers += 1;
        tokenPool += bid;

        return true;
    }

    

    
    
////// WITHDRAW MANAGEMENT ////////  
    enum WithdrawStatus {
        NoRecord,
        Started,
        Completed
    }

    struct WithdrawRecord {
        uint32 amount;
        WithdrawStatus status;
        uint governanceCycleId;
        address beneficiary;
        uint256 timestamp;
    }
  
    mapping(address => WithdrawRecord) public withdrawRecords;
    function claimBasicIncome() public returns(uint256, address){
      require(canClaimBasicIncome(msg.sender),"failed to claim");
      
      populateWithdrawRecord(msg.sender);
      msg.sender.transfer(tokenPool/totalMembers);
    }
    
    function canClaimBasicIncome(address member) public returns(bool){
        require(true, "is claim period");
        require(true, "is caucus member and has not already claimed");
        
        return true;
    }
    
    function populateWithdrawRecord(address member) internal returns(uint256,address){
        return (0 ,  member);
    }

}