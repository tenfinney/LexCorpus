// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.0;

contract Baal {
    address[] public memberList;
    uint256 public proposalCount;
    uint256 public totalVotes;
    mapping(address => Member) public members;
    mapping(uint256 => Proposal) public proposals;
    event ProcessProposal(uint256 proposal);
    event Receive(address indexed sender, uint256 value);
    event SubmitProposal(address indexed proposer, address indexed target, uint256 proposal, uint256 value, bytes data, bool membership);
    event SubmitVote(address indexed member, uint256 proposal, bool approve);
    
    constructor(address[] memory summoners, uint256[] memory votes) {
        for (uint256 i = 0; i < summoners.length; i++) {
             totalVotes += votes[i];
             members[summoners[i]].votes = votes[i];
             members[summoners[i]].active = true;
             memberList.push(summoners[i]);
        }
    }
    
    struct Member {
        uint256 votes;
        bool active;
        mapping(uint256 => bool) voted;
    }
    
    struct Proposal {
        address target;
        uint256 value;
        uint256 noVotes;
        uint256 yesVotes;
        bytes data;
        bool membership;
        bool removal;
        bool processed;
    }
    
    receive() external payable {emit Receive(msg.sender, msg.value);}
    
    function getMembers() external view returns (address[] memory membership) {
        return memberList;
    }
    
    function getMemberVote(address member, uint256 proposal) external view returns (bool approved) {
        return members[member].voted[proposal];
    }
    
    function submitProposal(address target, uint256 value, bytes calldata data, bool membership, bool removal) external returns (uint256 count) {
        proposalCount++;
        uint256 proposal = proposalCount;
        proposals[proposal] = Proposal(target, value, 0, 0, data, membership, removal, false);
        emit SubmitProposal(msg.sender, target, proposal, value, data, membership);
        return proposal;
    }
    
    function submitVote(uint256 proposal, bool approve) external returns (uint256 count) {
        Member storage member = members[msg.sender]; 
        Proposal storage prop = proposals[proposal];
        require(proposal <= proposalCount, "!exist");
        require(!prop.processed, "processed");
        require(member.active, "!active");
        require(!member.voted[proposal], "voted");
        if (approve) {prop.yesVotes += member.votes;} 
        else {prop.noVotes += member.votes;}
        member.voted[proposal] = true;
        emit SubmitVote(msg.sender, proposal, approve);
        return proposal;
    }
    
    function processProposal(uint256 proposal) external returns (bool success, bytes memory retData) {
        Proposal storage prop = proposals[proposal];
        require(proposal <= proposalCount, "!exist");
        require(!prop.processed, "processed");
        prop.processed = true;
        emit ProcessProposal(proposal);
        if (prop.yesVotes > prop.noVotes) {
            if (prop.membership && !prop.removal) {
                totalVotes += prop.value;
                members[prop.target].votes += prop.value;
                members[prop.target].active = true;
                memberList.push(prop.target);
            } else if (prop.membership && prop.removal) {
                address removedMember = prop.target;
                uint256 removedVotes = members[removedMember].votes;
                (bool callSuccess, ) = removedMember.call{value: address(this).balance * removedVotes / totalVotes}("");
                require(callSuccess, "!ethCall");
                totalVotes -= removedVotes;
                members[removedMember].votes = 0;
                members[removedMember].active = false; 
            } else {
                (bool callSuccess, bytes memory returnData) = prop.target.call{value: prop.value}(prop.data);
                return (callSuccess, returnData);   
            }
        }
    }
    
    function rageQuit(uint256 votes) external {
        require(members[msg.sender].votes >= votes, "!claim");
        (bool success, ) = msg.sender.call{value: address(this).balance * votes / totalVotes}("");
        require(success, "!ethCall");
        totalVotes -= votes;
        members[msg.sender].votes -= votes;
        if (members[msg.sender].votes == 0) {
            members[msg.sender].active = false;
        }
    }
}
