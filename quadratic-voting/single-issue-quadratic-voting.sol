pragma solidity ^0.5.1;

contract QuadraticVoting {

    constructor(string memory _ipfsHash, string memory _googleDoc) public {
      owners[msg.sender] = true;
      numOwners = 1;
      motion.ipfsHash= _ipfsHash;
      motion.googleDoc = _googleDoc;
      motion.detailsFrozen= true;
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
    enum KYCStates { None, Applied, CanVote, Blacklist }
    
    mapping(address => Registration) private registry;
    struct Registration {
        KYCStates KYCState;
        address PersonalRegistry;
    }
    
    // Modifier
    modifier onlyMember(){
        require(registry[msg.sender].KYCState== KYCStates.CanVote, "Sender must be owner.");
        _;
    }
    uint public numRegistered;
    
    event Approved(address indexed approvingOwner, address indexed voter);
    function addMember(address registrant) public onlyOwner {
        numRegistered++;
        require(registry[registrant].KYCState != KYCStates.Blacklist, "approve can only be called on registrants who are not Blacklisted ");
        registry[registrant].KYCState = KYCStates.CanVote;
        emit Approved(msg.sender, registrant);
        
    }
    
    event Revoked(address indexed revertingOwner, address indexed entry);
    function removeMember(address registrant) public onlyOwner {
        registry[registrant].KYCState = KYCStates.Blacklist;
        emit Revoked(msg.sender, registrant);
    }
    
    function canVote(address voter) public view returns (bool){
        if (registry[voter].KYCState == KYCStates.CanVote){
            return true;
        }else{
            return false;
        }
    }
  
////// VOTE MANAGEMENT ////////  
    struct BallotRecord {
        address voter;
        uint256 timestamp;
        uint32 amount;
        uint16 votes;
        bool inSupport;
        bool withdrawRecord;
        bool started;
    }
      
    enum VoteCycleStatus {
        NoRecord,
        Started,
        Completed
    }
    struct MotionDetails{
        int24 votes;
        uint24 positiveVotes;
        uint24 negativeVotes;
        uint24 totalVoters;
        uint32 tokenPool;
        bool detailsFrozen;
        VoteCycleStatus status;
        string ipfsHash;
        string googleDoc;
    }

    mapping (address => BallotRecord) public ballotRecords;
    MotionDetails public motion;
    
    function openBallotBooths() public onlyOwner(){
        motion.status= VoteCycleStatus.Started;
    }
  
    function closeBallotBooths() public onlyOwner(){
        motion.status= VoteCycleStatus.Completed;
    }
    event Voted(address _voter, uint16 _votes);
    function vote( bool _inSupport, uint16 _votes) public payable returns (bool){
        // Max supply is 150M "ether", so max vote is sqrt(150M)=12.2k. uint16 maxes at 65.3k. uint32 maxes at 4.2B.
        // Casting each vote up to 32 bytes ensures we don't get an overflow
        
        assert(msg.value < (150000000 * 1 ether));
        assert(_votes < 12247);
        
        uint128 _amount = uint128(msg.value/1 ether);
        require(uint128(_votes)*uint128(_votes) <= _amount, "The vote value must be at least the square of its weight.");
        require(canVote(msg.sender), "The voting address must already be approved to vote.");
        require(_amount >= 1, "Vote weights cannot be less than 1.");
        
        populateBallotRecord(_inSupport,  uint32(_amount),  _votes);
        
        emit Voted(msg.sender, _votes);
        return (true);
    }

    //NOTE: can't cast consecutive votes with different prefference ie. positiveVote followed by negative vote
    function populateBallotRecord( bool _inSupport, uint32 _amount, uint16 _votes) internal {
        require(motion.status == VoteCycleStatus.Started);
        require(motion.detailsFrozen == true);
        BallotRecord storage record = ballotRecords[msg.sender];
        
        require(record.withdrawRecord == false);
        
        if(record.started !=true){
            record.started = true;
            motion.totalVoters+=1;
            record.voter = msg.sender;
            record.inSupport = _inSupport;
            record.amount = _amount;
            record.votes = _votes;
            record.timestamp = now;
        }else{
            require(record.inSupport == _inSupport);
            record.amount += _amount;
            record.votes += _votes;
        }
        
        if (_inSupport) {
            motion.votes += int24(_votes);
            motion.positiveVotes += uint24(_votes);
        } else {
            motion.votes -= int24(_votes);
            motion.negativeVotes += uint24(_votes);
        }
        
        motion.tokenPool+= _amount;
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
    
    function withdraw() public returns(uint256 amount, address beneficiary) {
        //TODO: WITHDRAW DELAY
        (amount, beneficiary) = populateWithdrawRecord(msg.sender);
        return (amount, beneficiary);
    }
  
    function populateWithdrawRecord(address voter) internal returns(uint256,address){
    
        BallotRecord storage ballotRecord = ballotRecords[voter];
        
        require(motion.status == VoteCycleStatus.Completed, "Ballot's cycle must be completed before beginning a withdrawal.");
        require(ballotRecord.voter == msg.sender, "Voters can only begin withdrawals on their own ballots.");
        require(ballotRecord.withdrawRecord == false, "Ballot cannot already have a withdrawal record.");
        
        ballotRecord.withdrawRecord = true;
        
        WithdrawRecord storage record = withdrawRecords[voter];
        
        assert(record.status == WithdrawStatus.NoRecord);
        
        record.timestamp = now;
        record.beneficiary = msg.sender;
        record.status = WithdrawStatus.Started;
        record.amount = motion.tokenPool / motion.totalVoters;
        
        uint256 toSend = uint128(record.amount) * 1 ether;
        msg.sender.transfer(toSend);
        
        return (toSend, record.beneficiary);
    
    
    }
}