// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.0;

contract Baal {
    address[] public memberList;
    uint256 proposalCount;
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
        uint256 value;
        uint256 yesVotes;
        uint256 noVotes;
        bytes data;
        bool processed;
    }
    
    function submitProposal(address target, uint256 value, bytes calldata data) external returns (uint256) {
        proposalCount++;
        uint256 count = proposalCount;
        proposals[count] = Proposal(msg.sender, target, value, 0, 0, data, false);
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
    
    function processProposal(uint256 proposal) external {
        Proposal storage prop = proposals[proposal];
        require(!prop.processed);
        prop.processed = true;
        if (prop.yesVotes > prop.noVotes) {prop.target.call{value: prop.value}(prop.data);}
        prop.processed = true;
    }
}
