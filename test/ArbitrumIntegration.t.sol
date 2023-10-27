// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import { ArbitrumDomain, ArbSysOverride } from "../src/testing/ArbitrumDomain.sol";

import { ArbitrumReceiver } from "../src/ArbitrumReceiver.sol";

contract MessageOrderingArbitrum is MessageOrdering, ArbitrumReceiver {

    constructor(address _l1Authority) ArbitrumReceiver(_l1Authority) {}

    function push(uint256 messageId) public override onlyCrossChainMessage {
        super.push(messageId);
    }

}

contract ArbitrumIntegrationTest is IntegrationBaseTest {

    function test_arbitrumOne() public {
        checkArbitrumStyle(new ArbitrumDomain(getChain("arbitrum_one"), mainnet));
    }

    function test_arbitrumOneGoerli() public {
        checkArbitrumStyle(new ArbitrumDomain(getChain("arbitrum_one_goerli"), goerli));
    }

    function test_arbitrumNova() public {
        checkArbitrumStyle(new ArbitrumDomain(getChain("arbitrum_nova"), mainnet));
    }

    function checkArbitrumStyle(ArbitrumDomain arbitrum) public {
        deal(l1Authority, 100 ether);
        deal(notL1Authority, 100 ether);

        Domain host = arbitrum.hostDomain();

        host.selectFork();

        MessageOrdering moHost = new MessageOrdering();

        arbitrum.selectFork();

        MessageOrdering moArbitrum = new MessageOrderingArbitrum(l1Authority);

        // Queue up some L2 -> L1 messages
        ArbSysOverride(arbitrum.ARB_SYS()).sendTxToL1(
            address(moHost),
            abi.encodeWithSelector(MessageOrdering.push.selector, 3)
        );
        ArbSysOverride(arbitrum.ARB_SYS()).sendTxToL1(
            address(moHost),
            abi.encodeWithSelector(MessageOrdering.push.selector, 4)
        );

        assertEq(moArbitrum.length(), 0);

        // Do not relay right away
        host.selectFork();

        // Queue up two more L1 -> L2 messages
        vm.startPrank(l1Authority);
        XChainForwarders.sendMessageArbitrum(
            address(arbitrum.INBOX()),
            address(moArbitrum),
            abi.encodeWithSelector(MessageOrdering.push.selector, 1),
            100000
        );
        XChainForwarders.sendMessageArbitrum(
            address(arbitrum.INBOX()),
            address(moArbitrum),
            abi.encodeWithSelector(MessageOrdering.push.selector, 2),
            100000
        );
        vm.stopPrank();

        assertEq(moHost.length(), 0);

        arbitrum.relayFromHost(true);

        assertEq(moArbitrum.length(), 2);
        assertEq(moArbitrum.messages(0), 1);
        assertEq(moArbitrum.messages(1), 2);

        arbitrum.relayToHost(true);

        assertEq(moHost.length(), 2);
        assertEq(moHost.messages(0), 3);
        assertEq(moHost.messages(1), 4);

        // Validate the message receiver failure mode
        vm.startPrank(notL1Authority);
        XChainForwarders.sendMessageArbitrum(
            address(arbitrum.INBOX()),
            address(moArbitrum),
            abi.encodeWithSelector(MessageOrdering.push.selector, 999),
            100000
        );
        vm.stopPrank();

        vm.expectRevert("Receiver/invalid-l1Authority");
        arbitrum.relayFromHost(true);
    }

}
