// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import { OptimismDomain } from "../src/testing/OptimismDomain.sol";

import { OptimismReceiver } from "../src/OptimismReceiver.sol";

contract MessageOrderingOptimism is MessageOrdering, OptimismReceiver {

    constructor(address _l1Authority) OptimismReceiver(_l1Authority) {}

    function push(uint256 messageId) public override onlyCrossChainMessage {
        super.push(messageId);
    }

}

contract OptimismIntegrationTest is IntegrationBaseTest {

    event FailedRelayedMessage(bytes32);

    function test_optimism() public {
        checkOptimismStyle(new OptimismDomain(getChain("optimism"), mainnet));
    }

    function test_optimismGoerli() public {
        checkOptimismStyle(new OptimismDomain(getChain("optimism_goerli"), goerli));
    }

    function test_base() public {
        checkOptimismStyle(new OptimismDomain(getChain("base"), mainnet));
    }

    function test_baseGoerli() public {
        checkOptimismStyle(new OptimismDomain(getChain("base_goerli"), goerli));
    }

    function checkOptimismStyle(OptimismDomain optimism) public {
        Domain host = optimism.hostDomain();

        host.selectFork();

        MessageOrdering moHost = new MessageOrdering();

        optimism.selectFork();

        MessageOrdering moOptimism = new MessageOrderingOptimism(l1Authority);

        // Queue up some L2 -> L1 messages
        optimism.L2_MESSENGER().sendMessage(
            address(moHost),
            abi.encodeWithSelector(MessageOrdering.push.selector, 3),
            100000
        );
        optimism.L2_MESSENGER().sendMessage(
            address(moHost),
            abi.encodeWithSelector(MessageOrdering.push.selector, 4),
            100000
        );

        assertEq(moOptimism.length(), 0);

        // Do not relay right away
        host.selectFork();

        // Queue up two more L1 -> L2 messages
        vm.startPrank(l1Authority);
        XChainForwarders.sendMessageOptimism(
            address(optimism.L1_MESSENGER()),
            address(moOptimism),
            abi.encodeWithSelector(MessageOrdering.push.selector, 1),
            100000
        );
        XChainForwarders.sendMessageOptimism(
            address(optimism.L1_MESSENGER()),
            address(moOptimism),
            abi.encodeWithSelector(MessageOrdering.push.selector, 2),
            100000
        );
        vm.stopPrank();

        assertEq(moHost.length(), 0);

        optimism.relayFromHost(true);

        assertEq(moOptimism.length(), 2);
        assertEq(moOptimism.messages(0), 1);
        assertEq(moOptimism.messages(1), 2);

        optimism.relayToHost(true);

        assertEq(moHost.length(), 2);
        assertEq(moHost.messages(0), 3);
        assertEq(moHost.messages(1), 4);

        // Validate the message receiver failure modes
        vm.startPrank(notL1Authority);
        XChainForwarders.sendMessageOptimism(
            address(optimism.L1_MESSENGER()),
            address(moOptimism),
            abi.encodeWithSelector(MessageOrdering.push.selector, 999),
            100000
        );
        vm.stopPrank();

        // The revert is caught so it doesn't propagate
        // Just look at the no change to verify it didn't go through
        optimism.relayFromHost(true);
        assertEq(moOptimism.length(), 2);   // No change

        optimism.selectFork();
        vm.expectRevert("Receiver/invalid-sender");
        moOptimism.push(999);
    }

}
