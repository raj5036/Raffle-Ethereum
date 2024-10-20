// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {RaffleScript} from "script/Raffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract RaffleTest is Test {
	Raffle public raffle;
	HelperConfig public helperConfig;

	address public PLAYER = makeAddr("Player");
	uint256 public constant STARING_PLAYER_BALANCE = 10 ether;

	uint256 entranceFee;
	uint256 interval;
	address vrfCordinator;
	bytes32 gasLane;
	uint256 subscriptionId;
	uint32 callbackGasLimit;

	// Events
	event RaffleEntered(address indexed player);
	event WinnerPicked(address indexed winner);

	function setUp() public {
		RaffleScript deployer = new RaffleScript();

		(raffle, helperConfig) = deployer.deployContract();
		
		HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

		entranceFee = networkConfig.entranceFee;
		interval = networkConfig.interval;
		vrfCordinator = networkConfig.vrfCordinator;
		gasLane = networkConfig.gasLane;
		subscriptionId = networkConfig.subscriptionId;
		callbackGasLimit = networkConfig.callbackGasLimit;
		
		vm.deal(PLAYER, STARING_PLAYER_BALANCE);
	}

	function testRaffleInitializesInOpenState() public view {
		assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
	}

	function testRaffleRevertsOnInsufficientEntranceFee() public {
		// Arrange
		vm.prank(PLAYER);
		// Act
		vm.expectRevert(abi.encodeWithSignature("Raffle__SendMoreToEnterRaffle()"));
		// Assert
		raffle.enterRaffle();
	}

	function testRaffleRecoredPlayerWhenPlayerEntersRaffle() public {
		// Arrange
		vm.prank(PLAYER);
		// Act
		raffle.enterRaffle{ value: entranceFee }();
		// Assert
		assert(raffle.getNumberOfPlayers() == 1);
	}

	function testEventEmittedOnRaffleEntry() public {
		// Arrange
		vm.prank(PLAYER);
		// Act and Assert
		vm.expectEmit(true, false, false, false, address(raffle));
		emit RaffleEntered(PLAYER);

		raffle.enterRaffle{ value: entranceFee }();
	}
}