// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import { ArbitrumBridgeTesting } from "src/testing/bridges/ArbitrumBridgeTesting.sol";
import { ArbitrumForwarder }     from "src/forwarders/ArbitrumForwarder.sol";
import { ArbitrumReceiver }      from "src/receivers/ArbitrumReceiver.sol";

contract ArbitrumIntegrationTest is IntegrationBaseTest {

    using ArbitrumBridgeTesting for *;
    using DomainHelpers         for *;

    function setUp() public override {
        super.setUp();

        // Needed for arbitrum cross-chain messages
        deal(sourceAuthority, 100 ether);
        deal(randomAddress,   100 ether);
    }

    // Use Arbitrum One for failure test as the code logic is the same

    function test_invalidSourceAuthority() public {
        initBaseContracts(getChain("arbitrum_one").createFork());

        vm.startPrank(randomAddress);
        queueSourceToDestination(abi.encodeCall(MessageOrdering.push, (1)));
        vm.stopPrank();

        vm.expectRevert("ArbitrumReceiver/invalid-l1Authority");
        bridge.relayMessagesToDestination(true);
    }

    function test_arbitrumOne() public {
        runCrossChainTests(getChain("arbitrum_one").createFork());
    }

    function test_arbitrumNova() public {
        runCrossChainTests(getChain("arbitrum_nova").createFork());
    }

    function initSourceReceiver() internal override pure returns (address) {
        return address(0);
    }

    function initDestinationReceiver() internal override returns (address) {
        return address(new ArbitrumReceiver(sourceAuthority, address(moDestination)));
    }

    function initBridgeTesting() internal override returns (Bridge memory) {
        return ArbitrumBridgeTesting.createNativeBridge(source, destination);
    }

    function queueSourceToDestination(bytes memory message) internal override {
        ArbitrumForwarder.sendMessageL1toL2(
            bridge.sourceCrossChainMessenger,
            destinationReceiver,
            abi.encodeCall(ArbitrumReceiver.forward, (message)),
            100000,
            1 gwei,
            block.basefee + 10 gwei
        );
    }

    function queueDestinationToSource(bytes memory message) internal override {
        ArbitrumForwarder.sendMessageL2toL1(
            address(moSource),  // No receiver so send directly to the message ordering contract
            message
        );
    }

    function relaySourceToDestination() internal override {
        bridge.relayMessagesToDestination(true);
    }

    function relayDestinationToSource() internal override {
        bridge.relayMessagesToSource(true);
    }

}
