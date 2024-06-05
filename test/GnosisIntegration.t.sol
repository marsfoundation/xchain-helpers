// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import { AMBBridgeTesting } from "src/testing/bridges/AMBBridgeTesting.sol";
import { AMBForwarder }     from "src/forwarders/AMBForwarder.sol";
import { AMBReceiver }      from "src/receivers/AMBReceiver.sol";

contract GnosisIntegrationTest is IntegrationBaseTest {
    
    using AMBBridgeTesting for *;
    using DomainHelpers    for *;

    function test_receiver_constructor() public {
        initBaseContracts(getChain("gnosis_chain").createFork());
        destination.selectFork();

        AMBReceiver receiver = new AMBReceiver(bridge.destinationCrossChainMessenger, bytes32(uint256(1)), sourceAuthority, address(moDestination));

        assertEq(receiver.amb(),             bridge.destinationCrossChainMessenger);
        assertEq(receiver.sourceChainId(),   bytes32(uint256(1)));
        assertEq(receiver.sourceAuthority(), sourceAuthority);
        assertEq(receiver.target(),          address(moDestination));
    }

    function test_invalidSourceAuthority() public {
        initBaseContracts(getChain("gnosis_chain").createFork());

        vm.startPrank(randomAddress);
        queueSourceToDestination(abi.encodeCall(MessageOrdering.push, (1)));
        vm.stopPrank();

        // The revert is caught so it doesn't propagate
        // Just look at the no change to verify it didn't go through
        relaySourceToDestination();
        assertEq(moDestination.length(), 0);
    }

    function test_invalidSender() public {
        initBaseContracts(getChain("gnosis_chain").createFork());

        destination.selectFork();

        vm.prank(randomAddress);
        vm.expectRevert("AMBReceiver/invalid-sender");
        AMBReceiver(destinationReceiver).forward(abi.encodeCall(MessageOrdering.push, (1)));
    }

    function test_invalidSourceChainId() public {
        initBaseContracts(getChain("gnosis_chain").createFork());

        destination.selectFork();
        destinationReceiver = address(new AMBReceiver(
            bridge.destinationCrossChainMessenger,
            bytes32(uint256(2)),  // Random chain id (not Ethereum)
            sourceAuthority,
            address(moDestination)
        ));

        source.selectFork();
        vm.startPrank(sourceAuthority);
        queueSourceToDestination(abi.encodeCall(MessageOrdering.push, (1)));
        vm.stopPrank();

        // The revert is caught so it doesn't propagate
        // Just look at the no change to verify it didn't go through
        relaySourceToDestination();
        assertEq(moDestination.length(), 0);
    }

    function test_gnosisChain() public {
        runCrossChainTests(getChain('gnosis_chain').createFork());
    }

    function initSourceReceiver() internal override returns (address) {
        return address(new AMBReceiver(bridge.sourceCrossChainMessenger, bytes32(uint256(100)), destinationAuthority, address(moSource)));
    }

    function initDestinationReceiver() internal override returns (address) {
        return address(new AMBReceiver(bridge.destinationCrossChainMessenger, bytes32(uint256(1)), sourceAuthority, address(moDestination)));
    }

    function initBridgeTesting() internal override returns (Bridge memory) {
        return AMBBridgeTesting.createGnosisBridge(source, destination);
    }

    function queueSourceToDestination(bytes memory message) internal override {
        AMBForwarder.sendMessageEthereumToGnosisChain(
            destinationReceiver,
            abi.encodeCall(AMBReceiver.forward, (message)),
            100000
        );
    }

    function queueDestinationToSource(bytes memory message) internal override {
        AMBForwarder.sendMessageGnosisChainToEthereum(
            sourceReceiver,
            abi.encodeCall(AMBReceiver.forward, (message)),
            100000
        );
    }

    function relaySourceToDestination() internal override {
        bridge.relayMessagesToDestination(true);
    }

    function relayDestinationToSource() internal override {
        bridge.relayMessagesToSource(true);
    }

}
