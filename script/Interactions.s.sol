// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
	function createSubscriptionUsingConfig() public returns (uint256, address) {
		HelperConfig helperConfig = new HelperConfig();
		address vrfCordinator = helperConfig.getConfig().vrfCordinator;

		return createSubscription(vrfCordinator);
	}

	function createSubscription(address vrfCordinator) public returns (uint256, address) {
		console.log("Creating subscription on chainId: ", block.chainid);

		vm.startBroadcast();

		uint256 subId = VRFCoordinatorV2_5Mock(vrfCordinator).createSubscription();

		vm.stopBroadcast();

		console.log("Created subscription: ", subId);
		console.log("Please add in your config files");
		return (subId, vrfCordinator);
	}

	function run() public {
		createSubscriptionUsingConfig();
	}
}

contract FundSubscription is Script {
	uint256 public constant FUND_AMOUNT = 3 ether;

	function fundSubscriptionUsingConfig() public {
		HelperConfig helperConfig = new HelperConfig();
		address vrfCordinator = helperConfig.getConfig().vrfCordinator;
		uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
		address linkToken = helperConfig.getConfig().link;

		fundSubscription(vrfCordinator, subscriptionId, linkToken);
	}

	function fundSubscription(address vrfCordinator, uint256 subscriptionId, address linkToken) public {
		console.log("Funding subscription on chainId: ", block.chainid);
		console.log("Funding subscription: ", subscriptionId);
		console.log("link token: ", linkToken);

		if (block.chainid == 31337 /* Anvil Chain ID */) {
			vm.startBroadcast();
			
			VRFCoordinatorV2_5Mock(vrfCordinator).fundSubscription(subscriptionId, FUND_AMOUNT);

			vm.stopBroadcast();
		} else {
			vm.startBroadcast();

			LinkToken(linkToken).transferAndCall(vrfCordinator, FUND_AMOUNT, abi.encode(subscriptionId));

			vm.stopBroadcast();
		}
	}

	function run() public {
		fundSubscriptionUsingConfig();
	}
}

contract AddConsumer is Script {
	function run() public {}
}