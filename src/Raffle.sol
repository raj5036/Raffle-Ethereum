// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";


/** 
	* @title Raffle
	* @author Raj
	* @notice A simple Raffle Contract
	* @dev Implements Chainlink VRF 2.0 
*/
contract Raffle is VRFConsumerBaseV2Plus {
	// Errors
	error Raffle_SendMoreToEnterRaffle();
	error Raffle_TransferFailed();

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

	// Events
	event RaffleEntered(address indexed player);

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
		s_lastTimeStamp = block.timestamp;
		i_keyHash = gasLane;
		i_subscriptionId = subscriptionId;
		i_callbackGasLimit = callbackGasLimit;
	}

	function enterRaffle() external payable {
		if (msg.value < i_entranceFee) {
			revert Raffle_SendMoreToEnterRaffle();
		}

		s_players.push(payable(msg.sender));

		emit RaffleEntered(msg.sender);
	}

	// 1. Get a Random Number
	// 2. Get the Winner
	// 3. Be automatically called every week
	function pickWinner() external {
		if (block.timestamp - s_lastTimeStamp < i_interval) {
			revert();
		}

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
		uint256 indexOfWinner = randomWords[0] % s_players.length;
		address payable recentWinner = s_players[indexOfWinner];

		// Send ETH to the winner
		(bool success, ) = recentWinner.call{ value: address(this).balance }("");
		if (!success) {
			revert Raffle_TransferFailed();
		}
	}

	// Getter Functions
	function getEntranceFee() external view returns (uint256) {
		return i_entranceFee;
	}
}