// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import { ArbitrumBridgeTesting, ArbSysOverride } from "src/testing/bridges/ArbitrumBridgeTesting.sol";

import { ArbitrumForwarder } from "src/forwarders/ArbitrumForwarder.sol";
import { ArbitrumReceiver }  from "src/receivers/ArbitrumReceiver.sol";

contract ArbitrumIntegrationTest is IntegrationBaseTest {

    using ArbitrumBridgeTesting for *;
    using DomainHelpers         for *;

    function test_arbitrumOne() public {
        checkArbitrumStyle(getChain("arbitrum_one").createFork());
    }

    function test_arbitrumNova() public {
        checkArbitrumStyle(getChain("arbitrum_nova").createFork());
    }

    function initDestinationReceiver(address target) internal virtual returns (address receiver) {
        return new ArbitrumReceiver(sourceAuthority, target);
    }

    function checkArbitrumStyle(Domain memory _destination) internal {
        initDestination(_destination);

        Bridge memory bridge = ArbitrumBridgeTesting.createNativeBridge(source, destination);

        deal(sourceAuthority, 100 ether);
        deal(randomAddress,   100 ether);

        // Queue up some L2 -> L1 messages
        ArbitrumForwarder.sendMessageL2toL1(
            address(moSource),
            abi.encodeWithSelector(MessageOrdering.push.selector, 3)
        );
        ArbitrumForwarder.sendMessageL2toL1(
            address(moSource),
            abi.encodeWithSelector(MessageOrdering.push.selector, 4)
        );

        assertEq(moDestination.length(), 0);

        // Do not relay right away
        source.selectFork();

        // Queue up two more L1 -> L2 messages
        vm.startPrank(sourceAuthority);
        ArbitrumForwarder.sendMessageL1toL2(
            bridge.sourceCrossChainMessenger,
            address(moDestination),
            abi.encodeWithSelector(MessageOrdering.push.selector, 1),
            100000,
            1 gwei,
            block.basefee + 10 gwei
        );
        ArbitrumForwarder.sendMessageL1toL2(
            bridge.sourceCrossChainMessenger,
            address(moDestination),
            abi.encodeWithSelector(MessageOrdering.push.selector, 2),
            100000,
            1 gwei,
            block.basefee + 10 gwei
        );
        vm.stopPrank();

        assertEq(moSource.length(), 0);

        bridge.relayMessagesToDestination(true);

        assertEq(moDestination.length(), 2);
        assertEq(moDestination.messages(0), 1);
        assertEq(moDestination.messages(1), 2);

        bridge.relayMessagesToSource(true);

        assertEq(moSource.length(), 2);
        assertEq(moSource.messages(0), 3);
        assertEq(moSource.messages(1), 4);

        // Validate the message receiver failure mode
        vm.startPrank(notL1Authority);
        ArbitrumForwarder.sendMessageL1toL2(
            bridge.sourceCrossChainMessenger,
            address(moDestination),
            abi.encodeWithSelector(MessageOrdering.push.selector, 999),
            100000,
            1 gwei,
            block.basefee + 10 gwei
        );
        vm.stopPrank();

        vm.expectRevert("ArbitrumReceiver/invalid-l1Authority");
        bridge.relayMessagesToDestination(true);
    }

}
