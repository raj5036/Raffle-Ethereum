// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract HelperConfig is Script {
	error HelperConfig__InvalidChainId();

	struct NetworkConfig {
		uint256 entranceFee;
		uint256 interval;
		address vrfCordinator;
		bytes32 gasLane;
		uint32 callbackGasLimit;
		uint256 subscriptionId;
	}

	uint96 public constant MOCK_BASE_FEE = 0.25 ether;
	uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
	int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;

	uint256 public constant ANVIL_LOCAL_CHAIN_ID = 31337;
	uint256 public constant SEPOLIA_CHAIN_ID = 11155111;

	NetworkConfig public networkConfig;
	mapping(uint256 chainId => NetworkConfig) public chainConfig;

	constructor() {
		chainConfig[SEPOLIA_CHAIN_ID] = getSepoliaConfig();
	}

	function getConfig() public returns (NetworkConfig memory) {
		return getConfigByChainId(block.chainid);
	}

	function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
		if (chainConfig[chainId].vrfCordinator != address(0)) {
			return chainConfig[chainId];
		} else if (chainId == ANVIL_LOCAL_CHAIN_ID) {
			// Get or Create config for ANVIL_LOCAL_CHAIN_ID
			return getOrCreateAnvilEthConfig();
		} else {
			revert HelperConfig__InvalidChainId();
		}
	}

	function getSepoliaConfig() public pure returns (NetworkConfig memory) {
		return NetworkConfig({
			entranceFee: 0.01 ether,
			interval: 30,
			vrfCordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
			gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
			callbackGasLimit: 500000,
			subscriptionId: 0
		});
	}

	function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
		if (networkConfig.vrfCordinator != address(0)) {
			return networkConfig;
		}

		// Deploy mock VRFCoordinatorV2_5
		vm.startBroadcast();
		VRFCoordinatorV2_5Mock vrfCordinator = new VRFCoordinatorV2_5Mock(
			MOCK_BASE_FEE,
			MOCK_GAS_PRICE_LINK,
			MOCK_WEI_PER_UNIT_LINK
		);
		vm.stopBroadcast();
		networkConfig = NetworkConfig({
			entranceFee: 0.01 ether,
			interval: 30,
			vrfCordinator: address(vrfCordinator),
			gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // This value doesn't matter
			callbackGasLimit: 500000,
			subscriptionId: 0
		});
		return networkConfig;
	}
}