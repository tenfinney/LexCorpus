// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.0;

contract ReentrancyGuard { // call wrapper for reentrancy check - see https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/ReentrancyGuard.sol
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "reentrant");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract Baal is ReentrancyGuard {
    address[] public memberList; // array of member accounts summoned or added by proposal
    uint256 public proposalCount; // counter for proposals submitted 
    uint256 public totalVotes; // counter for member votes minted 
    uint256 public votingPeriod; // period for members to cast votes on proposals in epoch time
    
    mapping(address => Member) public members; // mapping member accounts to struct details
    mapping(uint256 => Proposal) public proposals; // mapping proposal number to struct details
    
    event SubmitProposal(address indexed proposer, address indexed target, uint256 proposal, uint256 value, bytes data, bool membership, bool removal); // emits when member submits proposal 
    event SubmitVote(address indexed member, uint256 proposal, bool approve); // emits when member submits vote on proposal
    event ProcessProposal(uint256 proposal); // emits when proposal is processed and finalized
    event Receive(address indexed sender, uint256 value); // emits when ether (ETH) received
    
    struct Member {
        uint256 votes; // voting weight to cast on a `proposal` by calling `submitVote()`
        mapping(uint256 => bool) voted; // mapping proposal number to whether member voted 
    }
    
    struct Proposal {
        address target; // account that receives low-level call `data` and ETH `value` - if `membership`, the account that will receive `value` votes - if `removal`, the account that will lose votes
        uint256 value; // ETH sent from Baal to execute approved proposal low-level call - if `membership`, reflects `votes` to grant member
        uint256 noVotes; // counter for member no votes to calculate approval on processing
        uint256 yesVotes; // counter for member yes votes to calculate approval on processing
        uint256 votingEnds; // termination date for proposal in seconds since epoch - derived from votingPeriod
        bytes data; // raw data sent to `target` account for low-level call
        bool membership; // flags whether proposal involves adding member votes
        bool removal; // flags whether proposal involves removing an account from membership
        bool processed; // flags whether proposal has processed and executed
    }
    
    /// @dev deploy Baal and create initial array of member accounts with specific vote weights
    /// @param summoners Accounts to add as members
    /// @param votes Voting weight per member
    /// @param _votingPeriod Voting period in seconds for members to cast votes on proposals
    constructor(address[] memory summoners, uint256[] memory votes, uint256 _votingPeriod) {
        for (uint256 i = 0; i < summoners.length; i++) {
             totalVotes += votes[i]; // total votes incremented by summoning
             votingPeriod = _votingPeriod; // voting period set in epoch time
             members[summoners[i]].votes = votes[i]; // vote weights granted to member
             memberList.push(summoners[i]); // member added to readable array of accounts
        }
    }
    
    /// @dev Submit proposal for member approval within voting period
    /// @param target Account that receives low-level call `data` and ETH `value` - if `membership`, the account that will receive `value` votes - if `removal`, the account that will lose votes
    /// @param value ETH sent from Baal to execute approved proposal low-level call - if `membership`, reflects `votes` to grant member
    /// @param data Raw data sent to `target` account for low-level call 
    /// @param membership Flags whether proposal involves adding member votes
    /// @param removal Flags whether proposal involves removing an account from membership
    function submitProposal(address target, uint256 value, bytes calldata data, bool membership, bool removal) external nonReentrant returns (uint256 count) {
        proposalCount++;
        uint256 proposal = proposalCount;
        proposals[proposal] = Proposal(target, value, 0, 0, block.timestamp + votingPeriod, data, membership, removal, false);
        emit SubmitProposal(msg.sender, target, proposal, value, data, membership, removal);
        return proposal;
    }
    
    /// @dev Submit vote - caller must have uncast votes - proposal number must exist, be unprocessed, and voting period cannot be finished
    /// @param proposal Number of proposal in `proposals` mapping to cast vote on 
    /// @param approve If `true`, member will cast `yesVotes` onto proposal - if `false, `noVotes` will be cast
    function submitVote(uint256 proposal, bool approve) external nonReentrant returns (uint256 count) {
        Member storage member = members[msg.sender]; 
        Proposal storage prop = proposals[proposal];
        
        require(proposal <= proposalCount, "!exist");
        require(prop.votingEnds >= block.timestamp, "finished");
        require(!prop.processed, "processed");
        require(member.votes > 0, "!active");
        require(!member.voted[proposal], "voted");
        
        if (approve) {prop.yesVotes += member.votes;} // cast yes votes
        else {prop.noVotes += member.votes;} // cast no votes
        
        member.voted[proposal] = true; // reflect member voted
        
        emit SubmitVote(msg.sender, proposal, approve);
        return proposal;
    }
    
    /// @dev Process proposal and execute low-level call or membership management - proposal number must exist, be unprocessed, and voting period must be finished
    /// @param proposal Number of proposal in `proposals` mapping to process for execution
    function processProposal(uint256 proposal) external nonReentrant returns (bool success, bytes memory retData) {
        Proposal storage prop = proposals[proposal];
        
        require(proposal <= proposalCount, "!exist");
        require(prop.votingEnds <= block.timestamp, "!finished");
        require(!prop.processed, "processed");
        
        prop.processed = true; // reflect proposal processed
        
        emit ProcessProposal(proposal);
        
        if (prop.yesVotes > prop.noVotes) { // check if proposal approved by members
            if (prop.membership && !prop.removal) { // check into membership proposal
                if(members[prop.target].votes < 1) {memberList.push(prop.target);} // update list of member accounts if new
                totalVotes += prop.value; // add to total member votes
                members[prop.target].votes += prop.value; // add to member votes
            } else if (prop.removal) { // check into removal proposal
                totalVotes -= members[prop.target].votes; // subtract from total member votes
                members[prop.target].votes = 0; // reset member votes
            } else { // otherwise, check into low-level call 
                (bool callSuccess, bytes memory returnData) = prop.target.call{value: prop.value}(prop.data); // execute low-level call
                return (callSuccess, returnData); // return call success and data
            }
        }
    }
    
    // @dev Return array list of member accounts in Baal
    function getMembers() external view returns (address[] memory membership) {
        return memberList;
    }
    
    // @dev Return and confirm whether member voted on a specific proposal
    function getMemberVote(address member, uint256 proposal) external view returns (bool approved) {
        return members[member].voted[proposal];
    }
    
    // @dev fallback to collect received ether into Baal
    receive() external payable {emit Receive(msg.sender, msg.value);}
}
