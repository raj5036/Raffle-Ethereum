// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {RaffleScript} from "script/Raffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";

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

	function testDontAllowPlayersWhenRaffleIsCalculating() public {
		vm.prank(PLAYER);

		raffle.enterRaffle{ value: entranceFee }();

		vm.warp(block.timestamp + interval + 1); // set current timestamp to interval + 1
		vm.roll(block.number + 1);

		// Act
		raffle.performUpkeep("");

		// Assert
		vm.expectRevert(abi.encodeWithSignature("Raffle__NotOpen()"));
		vm.prank(PLAYER);
		raffle.enterRaffle{ value: entranceFee }();
	}

	/**
		///////////////////////////////////////////////////////////////////
							CHECK UPKEEP
		///////////////////////////////////////////////////////////////////
	*/
	function testUpkeepFailsIfNoBalance() public {
		// Arrange
		vm.warp(block.timestamp + interval + 1); // set current timestamp to interval + 1
		vm.roll(block.number + 1);

		(bool upKeepNeeded, ) = raffle.checkUpkeep("");

		// Assert
		assert(upKeepNeeded == false);
	}	

	function testCheckUpkeepFailsIfRaffleNotOpen() public {
		// Arrange
		vm.prank(PLAYER);

		raffle.enterRaffle{ value: entranceFee }();

		vm.warp(block.timestamp + interval + 1); // set current timestamp to interval + 1
		vm.roll(block.number + 1);
		raffle.performUpkeep("");

		// Act
		(bool upkeepNeeded, ) = raffle.checkUpkeep("");

		// Assert
		assert(upkeepNeeded == false);
	}

	/**
		///////////////////////////////////////////////////////////////////
							PERFORM UPKEEP
		///////////////////////////////////////////////////////////////////
	*/

	function testPerformUpkeepOnlyIfCheckUpkeepIsTrue() public {
		// Arrange
		vm.prank(PLAYER);

		raffle.enterRaffle{ value: entranceFee }();

		vm.warp(block.timestamp + interval + 1); // set current timestamp to interval + 1
		vm.roll(block.number + 1);
		
		// Act / Assert
		raffle.performUpkeep("");
	}

	function testPerformUpkeepRevertsIfCheckupkeepIsFalse() public {
		// Arrange
		uint256 currentBalance = 0;
		uint256 numOfPlayers = 0;
		Raffle.RaffleState rState = raffle.getRaffleState();

		vm.prank(PLAYER);
		raffle.enterRaffle{ value: entranceFee }();
		currentBalance = currentBalance + entranceFee;
		numOfPlayers = numOfPlayers + 1;

		// Act / Assert
		vm.expectRevert(
			abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numOfPlayers, rState)
		);
		raffle.performUpkeep("");
	}

	modifier RaffleEnteredModifier {
		vm.prank(PLAYER);

		raffle.enterRaffle{ value: entranceFee }();

		vm.warp(block.timestamp + interval + 1); // set current timestamp to interval + 1
		vm.roll(block.number + 1);
		_;
	}

	function testPickWinnerEmitsRequestId() public RaffleEnteredModifier {
		// Arrange
	
		// Act
		vm.recordLogs();
		raffle.performUpkeep("");
		Vm.Log[] memory entries = vm.getRecordedLogs();

		bytes32 requestId = entries[1].topics[1];

		// Assert
		Raffle.RaffleState raffleState = raffle.getRaffleState();
		assert(uint256(requestId) > 0);
		assert(raffleState == Raffle.RaffleState.CALCULATING);
	}

	/**
		///////////////////////////////////////////////////////////////////
							FULFILL RANDOMWORDS
		///////////////////////////////////////////////////////////////////
	*/
}