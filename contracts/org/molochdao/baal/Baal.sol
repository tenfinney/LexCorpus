// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.0;

interface MemberAction {
    function memberBurn(address member, uint256 amount, uint256 total) external; // vote-weighted member burn - e.g., "ragequit" to claim capital
    function memberDistribution(address member, uint256 votes, uint256 total) external; // vote-weighted member distribution - e.g., claim dividends
    function memberMint(address member, uint256 amount) external; // value-weighted member vote mint - e.g., submit direct tribute for votes
}

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
    address[] public contractList; // array of contract approved for member calls 
    uint256 public proposalCount; // counter for proposals submitted 
    uint256 public totalSupply; // counter for member votes minted - erc20 compatible
    uint256 public votingPeriod; // period for members to cast votes on proposals in epoch time
    uint8 public decimals;
    string public name;
    string public symbol;
    
    mapping(address => uint256) public balanceOf; // mapping member accounts to votes
    mapping(address => mapping(uint256 => bool)) public voted; // mapping proposal number to whether member voted 
    mapping(uint256 => Proposal) public proposals; // mapping proposal number to struct details
    
    event SubmitProposal(address indexed proposer, address indexed target, uint256 proposal, uint256 value, bytes data, bool membership, bool removal, string details); // emits when member submits proposal 
    event SubmitVote(address indexed member, uint256 proposal, bool approve); // emits when member submits vote on proposal
    event ProcessProposal(uint256 proposal); // emits when proposal is processed and finalized
    event Receive(address indexed sender, uint256 value); // emits when ether (ETH) is received
    event Transfer(address indexed from, address indexed to, uint256 amount); // emits when member votes are minted or burned
    
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
        string details; // context for proposal - could be IPFS hash, plaintext, or JSON
    }
    
    /// @dev deploy Baal and create initial array of member accounts with specific vote weights
    /// @param summoners Accounts to add as members
    /// @param votes Voting weight per member
    /// @param _votingPeriod Voting period in seconds for members to cast votes on proposals
    /// @param _decimals Decimals for erc20 vote accounting - 18 is default for ETH
    /// @param _name Name for erc20 vote accounting
    /// @param _symbol Symbol for erc20 vote accounting
    constructor(address[] memory summoners, uint256[] memory votes, uint256 _votingPeriod, uint8 _decimals, string memory _name, string memory _symbol) {
        for (uint256 i = 0; i < summoners.length; i++) {
             totalSupply += votes[i]; // total votes incremented by summoning
             votingPeriod = _votingPeriod; 
             decimals = _decimals; 
             name = _name;
             symbol = _symbol;
             balanceOf[summoners[i]] = votes[i]; // vote weights granted to member
             memberList.push(summoners[i]); // update list of member accounts
             emit Transfer(address(this), summoners[i], votes[i]); // event reflects mint of erc20 votes
        }
    }
    
    /// @dev Submit proposal for member approval within voting period
    /// @param target Account that receives low-level call `data` and ETH `value` - if `membership`, the account that will receive `value` votes - if `removal`, the account that will lose votes
    /// @param value ETH sent from Baal to execute approved proposal low-level call - if `membership`, reflects `votes` to grant member
    /// @param data Raw data sent to `target` account for low-level call 
    /// @param membership Flags whether proposal involves adding member votes
    /// @param removal Flags whether proposal involves removing an account from membership
    /// @param details Context for proposal - could be IPFS hash, plaintext, or JSON
    function submitProposal(address target, uint256 value, bytes calldata data, bool membership, bool removal, string calldata details) external nonReentrant returns (uint256 count) {
        proposalCount++;
        uint256 proposal = proposalCount;
        proposals[proposal] = Proposal(target, value, 0, 0, block.timestamp + votingPeriod, data, membership, removal, false, details);
        emit SubmitProposal(msg.sender, target, proposal, value, data, membership, removal, details);
        return proposal;
    }
    
    /// @dev Submit vote - caller must have uncast votes - proposal number must exist, be unprocessed, and voting period cannot be finished
    /// @param proposal Number of proposal in `proposals` mapping to cast vote on 
    /// @param approve If `true`, member will cast `yesVotes` onto proposal - if `false, `noVotes` will be cast
    function submitVote(uint256 proposal, bool approve) external nonReentrant returns (uint256 count) {
        Proposal storage prop = proposals[proposal];
        
        require(proposal <= proposalCount, "!exist");
        require(prop.votingEnds >= block.timestamp, "finished");
        require(!prop.processed, "processed");
        require(balanceOf[msg.sender] != 0, "!active");
        require(voted[msg.sender][proposal], "voted");
        
        if (approve) {prop.yesVotes += balanceOf[msg.sender];} // cast yes votes
        else {prop.noVotes += balanceOf[msg.sender];} // cast no votes
        
        voted[msg.sender][proposal] = true; // reflect member voted
        
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
                if(balanceOf[prop.target] == 0) {memberList.push(prop.target);} // update list of member accounts if new
                totalSupply += prop.value; // add to total member votes
                balanceOf[prop.target] += prop.value; // add to member votes
                emit Transfer(address(this), prop.target, prop.value); // event reflects mint of erc20 votes
            } else if (prop.removal) { // check into removal proposal
                totalSupply -= balanceOf[prop.target]; // subtract from total member votes
                emit Transfer(address(this), address(0), balanceOf[prop.target]); // event reflects burn of erc20 votes
                balanceOf[prop.target] = 0; // reset member votes
            } else { // otherwise, check into low-level call 
                (bool callSuccess, bytes memory returnData) = prop.target.call{value: prop.value}(prop.data); // execute low-level call
                return (callSuccess, returnData); // return call success and data
            }
        }
    }
    
    function memberAction(address target, uint256 amount, bool burn, bool distribution, bool mint) external nonReentrant {
        if (burn) {
            MemberAction(target).memberBurn(msg.sender, amount, totalSupply);
            totalSupply -= amount; // subtract from total member votes
            balanceOf[msg.sender] -= amount; // subtract member votes
            emit Transfer(address(this), address(0), amount); // event reflects burn of erc20 votes
        } else if (distribution) {
            MemberAction(target).memberDistribution(msg.sender, balanceOf[msg.sender], totalSupply);
        } else if (mint) {
            MemberAction(target).memberMint(msg.sender, amount);
            totalSupply += amount; // add to total member votes
            balanceOf[msg.sender] += amount; // add to member votes
            emit Transfer(address(this), msg.sender, amount); // event reflects mint of erc20 votes
        }
    }
    
    /// @dev Return array list of member accounts in Baal
    function getMembers() external view returns (address[] memory membership) {
        return memberList;
    }
    
    /// @dev fallback to collect received ether into Baal
    receive() external payable {emit Receive(msg.sender, msg.value);}
}
