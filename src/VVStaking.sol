pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./VVToken.sol";

contract VVStaking is Ownable, ReentrancyGuard {

    VVToken public vvToken;

    struct Stake {
        uint256 amount;     
        uint256 expiry;     
    }

    mapping(address => Stake[]) public stakes;

    uint256 public constant MIN_DURATION = 1 weeks;
    uint256 public constant MAX_DURATION = 4 weeks;

    event Staked(address indexed user, uint256 amount, uint256 expiry);
    event Unstaked(address indexed user, uint256 stakeIndex, uint256 amount);

    constructor(address initialOwner, address _vvToken)
        Ownable(initialOwner)
    {
        vvToken = VVToken(_vvToken);
    }

    function stake(uint256 amount, uint256 duration) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        require(duration >= MIN_DURATION, "Duration too short");
        require(duration <= MAX_DURATION, "Duration too long");

        vvToken.transferFrom(msg.sender, address(this), amount);

        uint256 expiry = block.timestamp + duration;

        stakes[msg.sender].push(Stake({
            amount: amount,
            expiry: expiry
        }));

        emit Staked(msg.sender, amount, expiry);
    }

    function unstake(uint256 stakeIndex) external nonReentrant {
        Stake[] storage userStakes = stakes[msg.sender];
        require(stakeIndex < userStakes.length, "Invalid stake index");

        Stake storage s = userStakes[stakeIndex];
        require(s.amount > 0, "Already unstaked");
        require(block.timestamp >= s.expiry, "Stake not expired yet");

        uint256 amount = s.amount;
        s.amount = 0; 

        vvToken.transfer(msg.sender, amount);

        emit Unstaked(msg.sender, stakeIndex, amount);
    }


    function getVotingPower(address user) public view returns (uint256) {
        Stake[] storage userStakes = stakes[user];
        uint256 totalPower = 0;

        for (uint256 i = 0; i < userStakes.length; i++) {
            Stake storage s = userStakes[i];

            if (s.amount == 0) continue;
            if (block.timestamp >= s.expiry) continue;

            uint256 dRemain = s.expiry - block.timestamp;

            totalPower += (dRemain * dRemain) * s.amount;
        }

        return totalPower;
    }

    function getStakes(address user) external view returns (Stake[] memory) {
        return stakes[user];
    }
}