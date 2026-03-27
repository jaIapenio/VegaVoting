pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/VVToken.sol";
import "../src/VVStaking.sol";
import "../src/VVGovernance.sol";
import "../src/VVResultNFT.sol";

contract VVTest is Test {

    VVToken token;
    VVStaking staking;
    VVGovernance governance;
    VVResultNFT resultNFT;

    address admin = makeAddr("admin");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        vm.startPrank(admin);

        token = new VVToken(admin);
        staking = new VVStaking(admin, address(token));
        resultNFT = new VVResultNFT(admin);
        governance = new VVGovernance(admin, address(staking), address(resultNFT));

        resultNFT.setGovernance(address(governance));

        token.mint(alice, 1000 ether);
        token.mint(bob, 1000 ether);

        vm.stopPrank();
    }


    function test_TokenMint() public {
        assertEq(token.balanceOf(alice), 1000 ether);
        assertEq(token.balanceOf(bob),   1000 ether);
    }

    function test_TokenMintOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 100 ether);
    }


    function test_Stake() public {
        vm.startPrank(alice);
        token.approve(address(staking), 100 ether);
        staking.stake(100 ether, 2 weeks);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 900 ether);

        assertEq(token.balanceOf(address(staking)), 100 ether);
    }

    function test_StakeDurationTooShort() public {
        vm.startPrank(alice);
        token.approve(address(staking), 100 ether);
        vm.expectRevert("Duration too short");
        staking.stake(100 ether, 0.5 weeks);
        vm.stopPrank();
    }

    function test_StakeDurationTooLong() public {
        vm.startPrank(alice);
        token.approve(address(staking), 100 ether);
        vm.expectRevert("Duration too long");
        staking.stake(100 ether, 5 weeks);
        vm.stopPrank();
    }

    function test_Unstake() public {
        vm.startPrank(alice);
        token.approve(address(staking), 100 ether);
        staking.stake(100 ether, 1 weeks);
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert("Stake not expired yet");
        staking.unstake(0);

        vm.warp(block.timestamp + 1 weeks + 1);

        vm.prank(alice);
        staking.unstake(0);

        assertEq(token.balanceOf(alice), 1000 ether);
    }

    function test_VotingPower() public {
        vm.startPrank(alice);
        token.approve(address(staking), 100 ether);
        staking.stake(100 ether, 2 weeks);
        vm.stopPrank();

        uint256 power = staking.getVotingPower(alice);

        uint256 dRemain = 2 weeks;
        uint256 expected = dRemain * dRemain * 100 ether;

        assertEq(power, expected);
    }

    function test_VotingPowerZeroAfterExpiry() public {
        vm.startPrank(alice);
        token.approve(address(staking), 100 ether);
        staking.stake(100 ether, 1 weeks);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 weeks + 1);
        assertEq(staking.getVotingPower(alice), 0);
    }


    function _setupVote() internal returns (bytes32 voteId) {
        vm.startPrank(alice);
        token.approve(address(staking), 500 ether);
        staking.stake(500 ether, 2 weeks);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(staking), 500 ether);
        staking.stake(500 ether, 2 weeks);
        vm.stopPrank();

        uint256 threshold = type(uint256).max;

        vm.prank(admin);
        voteId = governance.createVote(
            "Should we upgrade the protocol?",
            block.timestamp + 3 days,
            threshold
        );
    }

    function test_CreateVote() public {
        bytes32 voteId = _setupVote();

        VVGovernance.Voting memory v = governance.getVoting(voteId);
        assertEq(v.description, "Should we upgrade the protocol?");
        assertEq(v.finalized, false);
    }

    function test_CreateVoteOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        governance.createVote("Test", block.timestamp + 1 days, 100);
    }

    function test_CastVote() public {
        bytes32 voteId = _setupVote();

        vm.prank(alice);
        governance.castVote(voteId, true);

        VVGovernance.Voting memory v = governance.getVoting(voteId);
        assertTrue(v.yesVotes > 0);
    }

    function test_CannotVoteTwice() public {
        bytes32 voteId = _setupVote();

        vm.startPrank(alice);
        governance.castVote(voteId, true);

        vm.expectRevert("Already voted");
        governance.castVote(voteId, true);
        vm.stopPrank();
    }

    function test_FinalizeByDeadline() public {
        bytes32 voteId = _setupVote();

        vm.prank(alice);
        governance.castVote(voteId, true);

        vm.warp(block.timestamp + 4 days);

        governance.finalizeVote(voteId);

        VVGovernance.Voting memory v = governance.getVoting(voteId);
        assertTrue(v.finalized);

        assertEq(resultNFT.balanceOf(admin), 1);
    }

    function test_FinalizeBeforeDeadlineReverts() public {
        bytes32 voteId = _setupVote();

        vm.expectRevert("Deadline not reached yet");
        governance.finalizeVote(voteId);
    }


    function test_EarlyFinalizeByThreshold() public {

        vm.startPrank(alice);
        token.approve(address(staking), 500 ether);
        staking.stake(500 ether, 2 weeks);
        vm.stopPrank();

        uint256 alicePower = staking.getVotingPower(alice);

        vm.prank(admin);
        bytes32 voteId = governance.createVote(
            "Early finalize test",
            block.timestamp + 3 days,
            alicePower - 1
    );

        vm.prank(alice);
        governance.castVote(voteId, true);

        VVGovernance.Voting memory v = governance.getVoting(voteId);
        assertTrue(v.finalized);
        assertTrue(v.passed);


        assertEq(resultNFT.balanceOf(admin), 1);
    }


    function test_PauseStopsVoting() public {
        bytes32 voteId = _setupVote();

        vm.prank(admin);
        governance.pause();

        vm.prank(alice);
        vm.expectRevert();
        governance.castVote(voteId, true);
    }
}