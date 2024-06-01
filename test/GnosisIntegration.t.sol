// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import { AMBBridgeTesting } from "src/testing/bridges/AMBBridgeTesting.sol";

import { AMBForwarder }   from "src/forwarders/AMBForwarder.sol";
import { GnosisReceiver } from "src/GnosisReceiver.sol";

contract MessageOrderingGnosis is MessageOrdering, GnosisReceiver {

    constructor(address _l2CrossDomain, uint256 _chainId, address _l1Authority) GnosisReceiver(_l2CrossDomain, _chainId, _l1Authority) {}

    function push(uint256 messageId) public override onlyCrossChainMessage {
        super.push(messageId);
    }

}

contract GnosisIntegrationTest is IntegrationBaseTest {
    
    using AMBBridgeTesting for *;
    using DomainHelpers    for *;

    function test_gnosisChain() public {
        checkGnosisStyle(getChain('gnosis_chain').createFork());
    }

    function checkGnosisStyle(Domain memory gnosis) public {
        Bridge memory bridge = AMBBridgeTesting.createGnosisBridge(mainnet, gnosis);

        mainnet.selectFork();

        MessageOrdering moHost = new MessageOrdering();
        uint256 _chainId = block.chainid;

        gnosis.selectFork();

        MessageOrderingGnosis moGnosis = new MessageOrderingGnosis(bridge.destinationCrossChainMessenger, _chainId, l1Authority);

        // Queue up some Gnosis -> Ethereum messages
        AMBForwarder.sendMessageGnosisChainToEthereum(
            address(moHost),
            abi.encodeWithSelector(MessageOrdering.push.selector, 3),
            100000
        );
        AMBForwarder.sendMessageGnosisChainToEthereum(
            address(moHost),
            abi.encodeWithSelector(MessageOrdering.push.selector, 4),
            100000
        );

        assertEq(moGnosis.length(), 0);

        // Do not relay right away
        mainnet.selectFork();

        // Queue up two more Ethereum -> Gnosis messages
        vm.startPrank(l1Authority);
        AMBForwarder.sendMessageEthereumToGnosisChain(
            address(moGnosis),
            abi.encodeWithSelector(MessageOrdering.push.selector, 1),
            100000
        );
        AMBForwarder.sendMessageEthereumToGnosisChain(
            address(moGnosis),
            abi.encodeWithSelector(MessageOrdering.push.selector, 2),
            100000
        );
        vm.stopPrank();

        assertEq(moHost.length(), 0);

        bridge.relayMessagesToDestination(true);

        assertEq(moGnosis.length(), 2);
        assertEq(moGnosis.messages(0), 1);
        assertEq(moGnosis.messages(1), 2);

        bridge.relayMessagesToSource(true);

        assertEq(moHost.length(), 2);
        assertEq(moHost.messages(0), 3);
        assertEq(moHost.messages(1), 4);

        // Validate the message receiver failure modes
        vm.startPrank(notL1Authority);
        AMBForwarder.sendMessageEthereumToGnosisChain(
            address(moGnosis),
            abi.encodeWithSelector(MessageOrdering.push.selector, 999),
            100000
        );
        vm.stopPrank();

        // The revert is caught so it doesn't propagate
        // Just look at the no change to verify it didn't go through
        bridge.relayMessagesToDestination(true);
        assertEq(moGnosis.length(), 2);   // No change

        gnosis.selectFork();
        vm.expectRevert("Receiver/invalid-sender");
        moGnosis.push(999);

        assertEq(moGnosis.l2CrossDomain().messageSourceChainId(), 0);
        vm.prank(address(moGnosis.l2CrossDomain()));
        vm.expectRevert("Receiver/invalid-chainId");
        moGnosis.push(999);
    }

}
