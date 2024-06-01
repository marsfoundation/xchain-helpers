// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import { OptimismBridgeTesting, IMessenger } from "src/testing/bridges/OptimismBridgeTesting.sol";

import { OptimismForwarder } from "src/forwarders/OptimismForwarder.sol";
import { OptimismReceiver }  from "src/OptimismReceiver.sol";

contract MessageOrderingOptimism is MessageOrdering, OptimismReceiver {

    constructor(address _l1Authority) OptimismReceiver(_l1Authority) {}

    function push(uint256 messageId) public override onlyCrossChainMessage {
        super.push(messageId);
    }

}

contract OptimismIntegrationTest is IntegrationBaseTest {

    using OptimismBridgeTesting for *;
    using DomainHelpers         for *;

    event FailedRelayedMessage(bytes32);

    function test_optimism() public {
        checkOptimismStyle(getChain("optimism").createFork());
    }

    function test_base() public {
        checkOptimismStyle(getChain("base").createFork());
    }

    function checkOptimismStyle(Domain memory optimism) public {
        Bridge memory bridge = OptimismBridgeTesting.createNativeBridge(mainnet, optimism);

        mainnet.selectFork();

        MessageOrdering moHost = new MessageOrdering();

        optimism.selectFork();

        MessageOrdering moOptimism = new MessageOrderingOptimism(l1Authority);

        // Queue up some L2 -> L1 messages
        OptimismForwarder.sendMessageL2toL1(
            address(moHost),
            abi.encodeWithSelector(MessageOrdering.push.selector, 3),
            100000
        );
        OptimismForwarder.sendMessageL2toL1(
            address(moHost),
            abi.encodeWithSelector(MessageOrdering.push.selector, 4),
            100000
        );

        assertEq(moOptimism.length(), 0);

        // Do not relay right away
        mainnet.selectFork();

        // Queue up two more L1 -> L2 messages
        vm.startPrank(l1Authority);
        OptimismForwarder.sendMessageL1toL2(
            bridge.sourceCrossChainMessenger,
            address(moOptimism),
            abi.encodeWithSelector(MessageOrdering.push.selector, 1),
            100000
        );
        OptimismForwarder.sendMessageL1toL2(
            bridge.sourceCrossChainMessenger,
            address(moOptimism),
            abi.encodeWithSelector(MessageOrdering.push.selector, 2),
            100000
        );
        vm.stopPrank();

        assertEq(moHost.length(), 0);

        bridge.relayMessagesToDestination(true);

        assertEq(moOptimism.length(), 2);
        assertEq(moOptimism.messages(0), 1);
        assertEq(moOptimism.messages(1), 2);

        bridge.relayMessagesToSource(true);

        assertEq(moHost.length(), 2);
        assertEq(moHost.messages(0), 3);
        assertEq(moHost.messages(1), 4);

        // Validate the message receiver failure modes
        vm.startPrank(notL1Authority);
        OptimismForwarder.sendMessageL1toL2(
            bridge.sourceCrossChainMessenger,
            address(moOptimism),
            abi.encodeWithSelector(MessageOrdering.push.selector, 999),
            100000
        );
        vm.stopPrank();

        // The revert is caught so it doesn't propagate
        // Just look at the no change to verify it didn't go through
        bridge.relayMessagesToDestination(true);
        assertEq(moOptimism.length(), 2);   // No change

        optimism.selectFork();
        vm.expectRevert("Receiver/invalid-sender");
        moOptimism.push(999);
    }

}
