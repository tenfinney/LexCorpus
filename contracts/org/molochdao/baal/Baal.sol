// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.0;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract Baal {
    address[] public memberList;
    uint256 proposalCount;
    mapping(address => uint256) public escrows;
    mapping(address => Member) public members;
    mapping(uint256 => Proposal) public proposals;
    
    event SubmitProposal(address indexed proposer, address indexed target, uint256 value, bytes data);
    event SubmitVote(address indexed member, bool approve);
    
    constructor(address[] memory summoners, uint256[] memory votes) {
        for (uint256 i = 0; i < summoners.length; i++) {
             members[summoners[i]].votes;
             memberList.push(summoners[i]);
        }
    }
    
    struct Member {
        uint256 votes;
        uint256 lastVote;
    }
    
    struct Proposal {
        address proposer;
        address target;
        uint256 request;
        uint256 value;
        uint256 noVotes;
        uint256 yesVotes;
        bytes data;
        bool membership;
        bool passed;
        bool processed;
    }
    
    function submitProposal(address target, uint256 request, uint256 value, bytes calldata data, bool membership) external returns (uint256) {
        proposalCount++;
        uint256 count = proposalCount;
        
        proposals[count] = Proposal(msg.sender, target, request, value, 0, 0, data, false, false, false);
        
        if (membership) {IERC20(target).transferFrom(msg.sender, address(this), value); escrows[target] += value;} // escrow membership tribute token value
        
        emit SubmitProposal(msg.sender, target, value, data);
        return count;
    }
    
    function submitVote(uint256 proposal, bool approve) external {
        Member storage member = members[msg.sender];
        Proposal storage prop = proposals[proposal];
        require(member.lastVote != proposal);
        
        if (approve) {prop.yesVotes += member.votes;}
        if (!approve) {prop.noVotes += member.votes;}
        
        member.lastVote = proposal;
        
        emit SubmitVote(msg.sender, approve);
    }
    
    function processProposal(uint256 proposal) external returns (bool, bytes memory) {
        Proposal storage prop = proposals[proposal];
        require(!prop.processed);
        
        if (prop.yesVotes > prop.noVotes) {
            prop.passed = true;
        
            if (prop.membership && !prop.passed) {IERC20(prop.target).transfer(prop.proposer, prop.value); escrows[prop.target] -= prop.value;} // return escrow membership tribute token value if failed
           
            (prop.value > IERC20(prop.target).balanceOf(address(this)) - escrowAmount);
        
        (bool success, bytes memory returnData) = prop.target.call{value: prop.value}(prop.data);
        return (success, returnData);
        
        prop.processed = true;
    }
}
