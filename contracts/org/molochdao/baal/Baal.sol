// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.0;

contract Baal {
    address[] public memberList;
    uint256 proposalCount;

    mapping(address => Member) public members;
    mapping(uint256 => Proposal) public proposals;
    
    event SubmitProposal(address indexed proposer, address indexed target, uint256 proposal, uint256 value, bytes data);
    event SubmitVote(address indexed member, uint256 proposal, bool approve);
    
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
        uint256 value;
        uint256 noVotes;
        uint256 yesVotes;
        bytes data;
        bool membership;
        bool passed;
        bool processed;
    }
    
    function submitProposal(address target, uint256 value, bytes calldata data, bool membership) external returns (uint256) {
        proposalCount++;
        uint256 proposal = proposalCount;
        
        proposals[proposal] = Proposal(msg.sender, target, value, 0, 0, data, false, false, false);
        
        emit SubmitProposal(msg.sender, target, proposal, value, data);
        return proposal;
    }
    
    function submitVote(uint256 proposal, bool approve) external {
        Member storage member = members[msg.sender];
        Proposal storage prop = proposals[proposal];
        require(member.lastVote != proposal);
        
        if (approve) {prop.yesVotes += member.votes;} 
        else {prop.noVotes += member.votes;}
        
        member.lastVote = proposal;
        
        emit SubmitVote(msg.sender, proposal, approve);
    }
    
    function processProposal(uint256 proposal) external returns (bool, bytes memory) {
        Proposal storage prop = proposals[proposal];
        require(!prop.processed);
        
        if (prop.yesVotes > prop.noVotes) {
            prop.passed = true;
            if (prop.membership) {
                members[prop.proposer].votes += prop.value;
                memberList.push(prop.proposer);
            } else {
                (bool success, bytes memory returnData) = prop.target.call{value: prop.value}(prop.data);
                return (success, returnData);   
            }
        }

        prop.processed = true;
    }
}
