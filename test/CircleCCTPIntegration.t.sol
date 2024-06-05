// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import { CCTPBridgeTesting } from "src/testing/bridges/CCTPBridgeTesting.sol";
import { CCTPForwarder }     from "src/forwarders/CCTPForwarder.sol";
import { CCTPReceiver }      from "src/receivers/CCTPReceiver.sol";

contract CircleCCTPIntegrationTest is IntegrationBaseTest {

    using CCTPBridgeTesting for *;
    using DomainHelpers     for *;

    uint32 sourceDomainId = CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM;
    uint32 destinationDomainId;

    // Use Optimism for failure tests as the code logic is the same

    function test_invalidSourceAuthority() public {
        destinationDomainId = CCTPForwarder.DOMAIN_ID_CIRCLE_OPTIMISM;
        initBaseContracts(getChain("optimism").createFork());

        vm.startPrank(randomAddress);
        queueSourceToDestination(abi.encodeCall(MessageOrdering.push, (1)));
        vm.stopPrank();

        vm.expectRevert("CCTPReceiver/invalid-sourceAuthority");
        relaySourceToDestination();
    }

    function test_invalidSender() public {
        destinationDomainId = CCTPForwarder.DOMAIN_ID_CIRCLE_OPTIMISM;
        initBaseContracts(getChain("optimism").createFork());

        destination.selectFork();

        vm.prank(randomAddress);
        vm.expectRevert("CCTPReceiver/invalid-sender");
        CCTPReceiver(destinationReceiver).handleReceiveMessage(0, bytes32(uint256(uint160(sourceAuthority))), abi.encodeCall(MessageOrdering.push, (1)));
    }

    function test_invalidSourceDomain() public {
        destinationDomainId = CCTPForwarder.DOMAIN_ID_CIRCLE_OPTIMISM;
        initBaseContracts(getChain("optimism").createFork());

        destination.selectFork();

        vm.prank(bridge.destinationCrossChainMessenger);
        vm.expectRevert("CCTPReceiver/invalid-sourceDomain");
        CCTPReceiver(destinationReceiver).handleReceiveMessage(1, bytes32(uint256(uint160(sourceAuthority))), abi.encodeCall(MessageOrdering.push, (1)));
    }

    function test_avalanche() public {
        destinationDomainId = CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE;
        runCrossChainTests(getChain("avalanche").createFork());
    }

    function test_optimism() public {
        destinationDomainId = CCTPForwarder.DOMAIN_ID_CIRCLE_OPTIMISM;
        runCrossChainTests(getChain("optimism").createFork());
    }

    function test_arbitrum_one() public {
        destinationDomainId = CCTPForwarder.DOMAIN_ID_CIRCLE_ARBITRUM_ONE;
        runCrossChainTests(getChain("arbitrum_one").createFork());
    }

    function test_base() public {
        destinationDomainId = CCTPForwarder.DOMAIN_ID_CIRCLE_BASE;
        runCrossChainTests(getChain("base").createFork());
    }

    function test_polygon() public {
        destinationDomainId = CCTPForwarder.DOMAIN_ID_CIRCLE_POLYGON_POS;
        runCrossChainTests(getChain("polygon").createFork());
    }

    function initSourceReceiver() internal override returns (address) {
        return address(new CCTPReceiver(bridge.sourceCrossChainMessenger, destinationDomainId, bytes32(uint256(uint160(destinationAuthority))), address(moSource)));
    }

    function initDestinationReceiver() internal override returns (address) {
        return address(new CCTPReceiver(bridge.destinationCrossChainMessenger, sourceDomainId, bytes32(uint256(uint160(sourceAuthority))), address(moDestination)));
    }

    function initBridgeTesting() internal override returns (Bridge memory) {
        return CCTPBridgeTesting.createCircleBridge(source, destination);
    }

    function queueSourceToDestination(bytes memory message) internal override {
        CCTPForwarder.sendMessage(
            bridge.sourceCrossChainMessenger,
            destinationDomainId,
            destinationReceiver,
            message
        );
    }

    function queueDestinationToSource(bytes memory message) internal override {
        CCTPForwarder.sendMessage(
            bridge.destinationCrossChainMessenger,
            sourceDomainId,
            sourceReceiver,
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
