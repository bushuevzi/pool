//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "hardhat/console.sol";

contract Poll {
    struct PollMeta{
        address[] membersLUT;
        address winner;
        uint prize;
        uint comission;
        uint startTime;
        bool isFinished;
        bool isComissionWidsdrawed;
    }

    struct PollFullInfo{
        mapping (address => bool) members;
        mapping (address => uint) votes;
        PollMeta meta;
    }

    address public owner;
    uint public voteCost = 0.01 ether;
    uint public comissionTax = 10;
    mapping (string => PollFullInfo) public polls;
    string[] private pollsLUT;

    constructor() {
        owner = msg.sender;
    }

    function kill() external {
        require(msg.sender == owner, "Only the owner can kill this contract");
        selfdestruct(payable(owner));
    }

    function createPoll(string memory pollName, uint startTime) public {
        require(msg.sender == owner, "You should be contract owner");
        require(polls[pollName].meta.startTime == 0, "Poll exists");
        
        pollsLUT.push(pollName);
        polls[pollName].meta.startTime = startTime;
    }

    function withdrawComission(string memory pollName) public {
        require(msg.sender == owner, "You should be contract owner");
        require(polls[pollName].meta.startTime > 0, "Poll not found");
        require(polls[pollName].meta.isFinished == true, "Poll not finished");
        require(polls[pollName].meta.comission > 0, "Comission is empty");
        require(polls[pollName].meta.isComissionWidsdrawed == false, "Comission was already widthdraw");

        (bool isComissionWidsdrawed, ) = owner.call{value: polls[pollName].meta.comission}("");
        polls[pollName].meta.isComissionWidsdrawed = isComissionWidsdrawed;
    }

    function vote(string memory pollName, address favoriteCandidate) public payable {
        require(polls[pollName].meta.startTime > 0, "Poll not found");
        require(polls[pollName].members[msg.sender] == false, "You alrady voted");
        require(block.timestamp < polls[pollName].meta.startTime + 3 days, "Poll is expired");
        require(msg.value == voteCost, "You need to send 0.01 Ether");
        
        registerMemberInPoll(pollName, msg.sender);
        
        require(polls[pollName].members[favoriteCandidate] == true, "Favorite candidate is not a poll member");

        polls[pollName].votes[favoriteCandidate] += 1; // vote
    }

    function finish(string memory pollName) public {
        require(polls[pollName].meta.startTime > 0, "Poll not found");
        require(polls[pollName].meta.isFinished == false, "Poll allrady finished");
        require(block.timestamp >= polls[pollName].meta.startTime + 3 days, "Voting lasts less than 3 days");
        require(polls[pollName].members[msg.sender] == true, "You not poll member");

        uint _prize = getPrize(pollName);
        polls[pollName].meta.prize = _prize;

        address payable _winner = payable(calcWinner(pollName));

        (bool isPrizePayed, ) = _winner.call{value: _prize}("");

        if(isPrizePayed){
            polls[pollName].meta.comission = calcComission(pollName);
            polls[pollName].meta.prize = _prize;
            polls[pollName].meta.winner = _winner;
            polls[pollName].meta.isFinished = true;
        }
    }

    function getPolls() public view returns(string[] memory) {
        return pollsLUT;
    }

    function getPoll(string memory pollName) public view returns(PollMeta memory) {
        return polls[pollName].meta;
    }

    function getPollMembers(string memory pollName) public view returns(address[] memory) {
        return polls[pollName].meta.membersLUT;
    }

    function getWinner(string memory pollName) public view returns(address) {
        return polls[pollName].meta.winner;
    }

    function getMemberVotes(string memory pollName, address member) public view returns(uint) {
        return polls[pollName].votes[member];
    }

    function registerMemberInPoll(string memory pollName, address member) private {
        polls[pollName].members[member] = true;
        polls[pollName].meta.membersLUT.push(member);
    }

    function getPrize (string memory pollName) private view returns (uint) {
        uint _priseWithComission = polls[pollName].meta.membersLUT.length * voteCost;
        uint _comission = calcComission(pollName);
        return _priseWithComission - _comission;
    }

    function calcComission (string memory pollName) private view returns (uint) {
        uint _priseWithComission = polls[pollName].meta.membersLUT.length * voteCost;
        return _priseWithComission / 100 * comissionTax;
    }

    function calcWinner (string memory pollName) private view returns (address) {
        address _winner;
        uint _maxVotes = 0;

        for(uint i = 0; i < polls[pollName].meta.membersLUT.length; i++){
            address _member = polls[pollName].meta.membersLUT[i];
            uint _memberVotes = polls[pollName].votes[_member];

            if(_memberVotes >= _maxVotes) {
                _winner = _member;
                _maxVotes = _memberVotes;
            }
        }

        return _winner;
    }
}
