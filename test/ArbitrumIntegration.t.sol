// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import { ArbitrumBridgeTesting, ArbSysOverride } from "src/testing/bridges/ArbitrumBridgeTesting.sol";

import { ArbitrumForwarder } from "src/forwarders/ArbitrumForwarder.sol";
import { ArbitrumReceiver }  from "src/ArbitrumReceiver.sol";

contract MessageOrderingArbitrum is MessageOrdering, ArbitrumReceiver {

    constructor(address _l1Authority) ArbitrumReceiver(_l1Authority) {}

    function push(uint256 messageId) public override onlyCrossChainMessage {
        super.push(messageId);
    }

}

contract ArbitrumIntegrationTest is IntegrationBaseTest {

    using ArbitrumBridgeTesting for *;
    using DomainHelpers         for *;

    function test_arbitrumOne() public {
        checkArbitrumStyle(getChain("arbitrum_one").createFork());
    }

    function test_arbitrumNova() public {
        checkArbitrumStyle(getChain("arbitrum_nova").createFork());
    }

    function checkArbitrumStyle(Domain memory arbitrum) public {
        Bridge memory bridge = ArbitrumBridgeTesting.createNativeBridge(mainnet, arbitrum);

        deal(l1Authority, 100 ether);
        deal(notL1Authority, 100 ether);

        mainnet.selectFork();

        MessageOrdering moHost = new MessageOrdering();

        arbitrum.selectFork();

        MessageOrdering moArbitrum = new MessageOrderingArbitrum(l1Authority);

        // Queue up some L2 -> L1 messages
        ArbitrumForwarder.sendMessageL2toL1(
            address(moHost),
            abi.encodeWithSelector(MessageOrdering.push.selector, 3)
        );
        ArbitrumForwarder.sendMessageL2toL1(
            address(moHost),
            abi.encodeWithSelector(MessageOrdering.push.selector, 4)
        );

        assertEq(moArbitrum.length(), 0);

        // Do not relay right away
        mainnet.selectFork();

        // Queue up two more L1 -> L2 messages
        vm.startPrank(l1Authority);
        ArbitrumForwarder.sendMessageL1toL2(
            bridge.sourceCrossChainMessenger,
            address(moArbitrum),
            abi.encodeWithSelector(MessageOrdering.push.selector, 1),
            100000,
            1 gwei,
            block.basefee + 10 gwei
        );
        ArbitrumForwarder.sendMessageL1toL2(
            bridge.sourceCrossChainMessenger,
            address(moArbitrum),
            abi.encodeWithSelector(MessageOrdering.push.selector, 2),
            100000,
            1 gwei,
            block.basefee + 10 gwei
        );
        vm.stopPrank();

        assertEq(moHost.length(), 0);

        bridge.relayMessagesToDestination(true);

        assertEq(moArbitrum.length(), 2);
        assertEq(moArbitrum.messages(0), 1);
        assertEq(moArbitrum.messages(1), 2);

        bridge.relayMessagesToSource(true);

        assertEq(moHost.length(), 2);
        assertEq(moHost.messages(0), 3);
        assertEq(moHost.messages(1), 4);

        // Validate the message receiver failure mode
        vm.startPrank(notL1Authority);
        ArbitrumForwarder.sendMessageL1toL2(
            bridge.sourceCrossChainMessenger,
            address(moArbitrum),
            abi.encodeWithSelector(MessageOrdering.push.selector, 999),
            100000,
            1 gwei,
            block.basefee + 10 gwei
        );
        vm.stopPrank();

        vm.expectRevert("Receiver/invalid-l1Authority");
        bridge.relayMessagesToDestination(true);
    }

}
