pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./VVStaking.sol";
import "./VVResultNFT.sol";

contract VVGovernance is Ownable, Pausable {

    VVStaking public staking;
    VVResultNFT public resultNFT;

    struct Voting {
        bytes32 ID;
        uint256 deadline;
        uint256 votingPowerThreshold;
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        bool finalized;
        bool passed;
    }

    mapping(bytes32 => Voting) public votings;

    mapping(bytes32 => mapping(address => bool)) public hasVoted;

    bytes32[] public votingIds;

    event VoteCreated(bytes32 indexed voteId, string description, uint256 deadline);
    event VoteCast(bytes32 indexed voteId, address indexed voter, bool support, uint256 votingPower);
    event VoteFinalized(bytes32 indexed voteId, bool passed, uint256 yesVotes, uint256 noVotes);

    constructor(address initialOwner, address _staking, address _resultNFT)
        Ownable(initialOwner)
    {
        staking = VVStaking(_staking);
        resultNFT = VVResultNFT(_resultNFT);
    }


    function createVote(
        string calldata description,
        uint256 deadline,
        uint256 votingPowerThreshold
    ) external onlyOwner whenNotPaused returns (bytes32) {
        require(deadline > block.timestamp, "Deadline must be in the future");
        require(votingPowerThreshold > 0, "Threshold must be > 0");

        bytes32 voteId = keccak256(abi.encodePacked(
            description,
            deadline,
            block.timestamp
        ));

        require(votings[voteId].deadline == 0, "Vote ID already exists");

        votings[voteId] = Voting({
            ID: voteId,
            deadline: deadline,
            votingPowerThreshold: votingPowerThreshold,
            description: description,
            yesVotes: 0,
            noVotes: 0,
            finalized: false,
            passed: false
        });

        votingIds.push(voteId);

        emit VoteCreated(voteId, description, deadline);

        return voteId;
    }


    function castVote(bytes32 voteId, bool support) external whenNotPaused {
        Voting storage v = votings[voteId];

        require(v.deadline != 0, "Vote does not exist");
        require(!v.finalized, "Vote already finalized");
        require(block.timestamp < v.deadline, "Voting deadline passed");
        require(!hasVoted[voteId][msg.sender], "Already voted");

        uint256 power = staking.getVotingPower(msg.sender);
        require(power > 0, "No voting power");

        hasVoted[voteId][msg.sender] = true;

        if (support) {
            v.yesVotes += power;
        } else {
            v.noVotes += power;
        }

        emit VoteCast(voteId, msg.sender, support, power);

        if (v.yesVotes >= v.votingPowerThreshold) {
            _finalize(voteId);
        }
    }


    function finalizeVote(bytes32 voteId) external whenNotPaused {
        Voting storage v = votings[voteId];

        require(v.deadline != 0, "Vote does not exist");
        require(!v.finalized, "Already finalized");
        require(block.timestamp >= v.deadline, "Deadline not reached yet");

        _finalize(voteId);
    }

    function _finalize(bytes32 voteId) internal {
        Voting storage v = votings[voteId];

        v.finalized = true;
        v.passed = v.yesVotes >= v.votingPowerThreshold;

        resultNFT.mint(
            owner(),
            voteId,
            v.description,
            v.yesVotes,
            v.noVotes,
            v.passed
        );

        emit VoteFinalized(voteId, v.passed, v.yesVotes, v.noVotes);
    }


    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    function getVoting(bytes32 voteId) external view returns (Voting memory) {
        return votings[voteId];
    }

    function getAllVotingIds() external view returns (bytes32[] memory) {
        return votingIds;
    }
}