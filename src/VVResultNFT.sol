pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract VVResultNFT is ERC721, Ownable {

    uint256 private _nextTokenId;

    struct VotingResult {
        bytes32 voteId;
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        bool passed;
    }

    mapping(uint256 => VotingResult) public results;

    address public governance;

    event ResultNFTMinted(uint256 indexed tokenId, bytes32 indexed voteId, bool passed);

    constructor(address initialOwner)
        ERC721("VegaVotingResult", "VVR")
        Ownable(initialOwner)
    {}

    function setGovernance(address _governance) external onlyOwner {
        governance = _governance;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "Only governance can mint");
        _;
    }

    function mint(
        address to,
        bytes32 voteId,
        string calldata description,
        uint256 yesVotes,
        uint256 noVotes,
        bool passed
    ) external onlyGovernance returns (uint256) {
        uint256 tokenId = _nextTokenId++;

        results[tokenId] = VotingResult({
            voteId: voteId,
            description: description,
            yesVotes: yesVotes,
            noVotes: noVotes,
            passed: passed
        });

        _mint(to, tokenId);

        emit ResultNFTMinted(tokenId, voteId, passed);

        return tokenId;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        VotingResult memory r = results[tokenId];

        string memory json = Base64.encode(bytes(string(abi.encodePacked(
            '{"name": "Vote Result #', Strings.toString(tokenId), '",',
            '"description": "', r.description, '",',
            '"attributes": [',
                '{"trait_type": "Result", "value": "', r.passed ? "Passed" : "Failed", '"},',
                '{"trait_type": "Yes Votes", "value": "', Strings.toString(r.yesVotes), '"},',
                '{"trait_type": "No Votes", "value": "', Strings.toString(r.noVotes), '"}',
            ']}'
        ))));

        return string(abi.encodePacked("data:application/json;base64,", json));
    }
}