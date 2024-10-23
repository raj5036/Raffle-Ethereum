// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

contract RaffleScript is Script {
	function run() public {}

	function deployContract() public returns (Raffle, HelperConfig) {
		HelperConfig helperConfig = new HelperConfig();
		HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

		// Set subscriptionId
		if (networkConfig.subscriptionId == 0) {
			CreateSubscription createSubscription = new CreateSubscription();
			
			(uint256 subId, address vrfCordinator) = createSubscription.createSubscription(networkConfig.vrfCordinator);
			
			// ERROR!
			networkConfig.subscriptionId = subId;	
			networkConfig.vrfCordinator = vrfCordinator;

			// Fund the subscription
			FundSubscription fundSubscription = new FundSubscription();
			fundSubscription.fundSubscription(
				networkConfig.vrfCordinator,
				networkConfig.subscriptionId,
				networkConfig.link
			);
		}

		// Local Chain => Deploy Mocks
		// Other Chains => Get config from HelperConfig
		vm.startBroadcast();

		Raffle raffle = new Raffle(
			networkConfig.entranceFee,
			networkConfig.interval,
			networkConfig.vrfCordinator,
			networkConfig.gasLane,
			networkConfig.subscriptionId,
			networkConfig.callbackGasLimit
		);

		vm.stopBroadcast();

		AddConsumer addConsumer = new AddConsumer();
		addConsumer.addConsumer(address(raffle), networkConfig.vrfCordinator, networkConfig.subscriptionId);

		return (raffle, helperConfig);
	}
}