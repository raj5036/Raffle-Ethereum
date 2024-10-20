// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract RaffleScript is Script {
	function run() public {}

	function deployContract() public returns (Raffle, HelperConfig) {
		HelperConfig helperConfig = new HelperConfig();
		HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

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

		return (raffle, helperConfig);
	}
}