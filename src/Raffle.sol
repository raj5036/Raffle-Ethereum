// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";


/** 
	* @title Raffle
	* @author Raj
	* @notice A simple Raffle Contract
	* @dev Implements Chainlink VRF 2.0 
*/
contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
	/* Errors */
	error Raffle__SendMoreToEnterRaffle();
	error Raffle__TransferFailed();
	error Raffle__NotOpen();
	error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

	/* Type Declarations */
	enum RaffleState {
		OPEN,
		CALCULATING
	}
	
	/* State variable */
	uint16 private constant REQUEST_CONFIRMATIONS = 3;
	uint32 private constant NUM_WORDS = 1;
	uint256 private immutable i_entranceFee;
	// @dev: How many seconds before picking the winner
	uint256 private immutable i_interval;
	bytes32 private immutable i_keyHash;
	uint256 private immutable i_subscriptionId;
	uint32 private immutable i_callbackGasLimit;
	uint256 private s_lastTimeStamp;
	address payable[] private s_players;
	RaffleState private s_raffleState;

	// Events
	event RaffleEntered(address indexed player);
	event WinnerPicked(address indexed winner);

	constructor (
		uint256 entranceFee, 
		uint256 interval, 
		address vrfCordinator,
		bytes32 gasLane,
		uint256 subscriptionId,
		uint32 callbackGasLimit
	) VRFConsumerBaseV2Plus(vrfCordinator) {
		i_entranceFee = entranceFee;
		i_interval = interval;
		i_keyHash = gasLane;
		i_subscriptionId = subscriptionId;
		i_callbackGasLimit = callbackGasLimit;

		s_lastTimeStamp = block.timestamp;
		s_raffleState = RaffleState.OPEN;
	}

	function enterRaffle() external payable {
		if (msg.value < i_entranceFee) {
			revert Raffle__SendMoreToEnterRaffle();
		}

		if (s_raffleState != RaffleState.OPEN) {
			revert Raffle__NotOpen();
		}

		s_players.push(payable(msg.sender));

		emit RaffleEntered(msg.sender);
	}

	function checkUpkeep(bytes calldata /* checkData */) external override returns (
		bool upkeepNeeded, 
		bytes memory /* performData */
	) {
		bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
		bool isRaffleOpen = s_raffleState == RaffleState.OPEN;
		bool hasBalance = address(this).balance > 0;
		bool hasPlayers = s_players.length > 0;
		
		upkeepNeeded = timeHasPassed && isRaffleOpen && hasBalance && hasPlayers;

		return (upkeepNeeded, bytes(""));
	}

	function performUpkeep(bytes calldata /* performData */) external override {
		(bool upKeepNeeded, ) = checkUpkeep(bytes(""));

		if (!upKeepNeeded) {
			revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
		}
		pickWinner();
	}

	// 1. Get a Random Number
	// 2. Get the Winner
	// 3. Be automatically called every week
	function pickWinner() private {
		s_raffleState = RaffleState.CALCULATING;

		// Get our random number (Chainlink VRF: 2.5)
		//  1. Request Chainlink for Randomness
		// 	2. Get Random number from Chainlink  
		VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
			keyHash: i_keyHash,
			subId: i_subscriptionId,
			requestConfirmations: REQUEST_CONFIRMATIONS,
			callbackGasLimit: i_callbackGasLimit,
			numWords: NUM_WORDS,
			extraArgs: VRFV2PlusClient._argsToBytes(
				// Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
				VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
			)
		});

		uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
		s_lastTimeStamp = block.timestamp;
	}

	function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal virtual override {
		// Checks
		uint256 indexOfWinner = randomWords[0] % s_players.length;
		address payable recentWinner = s_players[indexOfWinner];

		
		// Effects - Reset the raffle
		s_raffleState = RaffleState.OPEN;
		s_players = new address payable[](0);
		s_lastTimeStamp = block.timestamp;

		// Interactions - Send ETH to the winner
		(bool success, ) = recentWinner.call{ value: address(this).balance }("");
		if (!success) {
			revert Raffle__TransferFailed();
		}

		emit WinnerPicked(recentWinner);
	}

	// Getter Functions
	function getEntranceFee() external view returns (uint256) {
		return i_entranceFee;
	}
}