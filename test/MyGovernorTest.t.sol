// SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {GovToken} from "src/GovToken.sol";
import {MyGovernor} from "src/MyGovernor.sol";
import {TimeLock} from "src/TimeLock.sol";
import {Box} from "src/Box.sol";

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract MyGovernorTest is Test {
    GovToken govToken;
    MyGovernor myGovernor;
    TimeLock timeLock;
    Box box;

    address public constant VOTER = address(1);
    uint256 public INITIAL_SUPPLY = 100 ether;
    uint256 public constant MIN_DELAY = 3600; //   1 hour - after a vote passes, you have 1 hour before you can enact
    uint256 public constant QUORUM_PERCENTAGE = 4; // Need 4% of voters to pass
    uint256 public constant VOTING_PERIOD = 50400; // This is how long voting lasts
    uint256 public constant VOTING_DELAY = 1; // How many blocks till a proposal vote becomes active

    bytes[] functionCalls;
    address[] addressesToCall;
    uint256[] values;

    address[] proposers;
    address[] executors;

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(VOTER, INITIAL_SUPPLY);

        vm.startPrank(VOTER);
        govToken.delegate(VOTER);
        timeLock = new TimeLock(MIN_DELAY, proposers, executors);
        myGovernor = new MyGovernor(IVotes(govToken), TimelockController(timeLock));

        bytes32 proposersRole = timeLock.PROPOSER_ROLE();
        bytes32 executorsRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.TIMELOCK_ADMIN_ROLE();

        timeLock.grantRole(proposersRole, address(myGovernor));
        timeLock.grantRole(executorsRole, address(0));
        timeLock.grantRole(adminRole, VOTER);

        vm.stopPrank();
        box = new Box();
        box.transferOwnership(address(timeLock));
    }

    function testCanUpdateBoxWithoutGovernor() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGovernanceUpdateBox() public {
        uint256 valueToStore = 777;
        string memory description = "Store 1 in Box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);
        addressesToCall.push(address(box));
        values.push(0);
        functionCalls.push(encodedFunctionCall);
        // 1. Propose to the DAO

        uint256 proposalId = myGovernor.propose(addressesToCall, values, functionCalls, description);

        console.log("Proposal State:", uint256(myGovernor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        console.log("Proposal State:", uint256(myGovernor.state(proposalId)));

        // 2. Vote
        string memory reason = "I like a do da cha cha";
        // 0 = Against, 1 = For, 2 = Abstain for this example
        uint8 voteWay = 1;

        vm.prank(VOTER);
        myGovernor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        console.log("Proposal State:", uint256(myGovernor.state(proposalId)));

        // 3. Queue
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        myGovernor.queue(addressesToCall, values, functionCalls, descriptionHash);
        vm.roll(block.number + MIN_DELAY + 1);
        vm.warp(block.timestamp + MIN_DELAY + 1);

        // 4. Execute
        myGovernor.execute(addressesToCall, values, functionCalls, descriptionHash);

        assert(box.getNumber() == valueToStore);
    }
}
