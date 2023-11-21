// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import {Domain} from "../src/testing/Domain.sol";
import {ScrollDomain} from "../src/testing/ScrollDomain.sol";

import {ScrollReceiver} from "../src/ScrollReceiver.sol";

contract MessageOrderingScroll is MessageOrdering, ScrollReceiver {
    constructor(
        address _l2CrossDomain,
        address _l1Authority
    ) ScrollReceiver(_l2CrossDomain, _l1Authority) {}

    function push(uint256 messageId) public override onlyCrossChainMessage {
        super.push(messageId);
    }
}

contract ScrollIntegrationTest is IntegrationBaseTest {
    function test_scroll() public {
        setChain(
            "scroll",
            ChainData("Scroll Chain", 534352, "https://rpc.scroll.io")
        );

        checkScrollStyle(new ScrollDomain(getChain("scroll"), mainnet));
    }

    function test_scrollSepolia() public {
        setChain(
            "scroll_sepolia",
            ChainData(
                "Scroll Sepolia Testnet",
                534351,
                "https://sepolia-rpc.scroll.io"
            )
        );
        setChain(
            "sepolia",
            ChainData("Sepolia Testnet", 11155111, "https://1rpc.io/sepolia")
        );
        Domain sepolia = new Domain(getChain("sepolia"));

        checkScrollStyle(new ScrollDomain(getChain("scroll_sepolia"), sepolia));
    }

    function checkScrollStyle(ScrollDomain scroll) public {
        Domain host = scroll.hostDomain();

        host.selectFork();

        MessageOrdering moHost = new MessageOrdering();

        scroll.selectFork();

        MessageOrdering moScroll = new MessageOrderingScroll(
            address(scroll.L2_SCROLL_MESSENGER()),
            l1Authority
        );

        // Queue up some L2 -> L1 messages
        scroll.L2_SCROLL_MESSENGER().sendMessage(
            address(moHost),
            0,
            abi.encodeWithSelector(MessageOrdering.push.selector, 3),
            100000
        );
        scroll.L2_SCROLL_MESSENGER().sendMessage(
            address(moHost),
            0,
            abi.encodeWithSelector(MessageOrdering.push.selector, 4),
            100000
        );

        assertEq(moScroll.length(), 0);

        // Do not relay right away
        host.selectFork();

        // Queue up two more L1 -> L2 messages
        vm.deal(l1Authority, scroll.estimateMessageFee(100000) * 2);
        vm.startPrank(l1Authority);
        XChainForwarders.sendMessageScroll(
            address(scroll.L1_SCROLL_MESSENGER()),
            address(moScroll),
            abi.encodeWithSelector(MessageOrdering.push.selector, 1),
            100000,
            scroll.estimateMessageFee(100000)
        );
        XChainForwarders.sendMessageScroll(
            address(scroll.L1_SCROLL_MESSENGER()),
            address(moScroll),
            abi.encodeWithSelector(MessageOrdering.push.selector, 2),
            100000,
            scroll.estimateMessageFee(100000)
        );
        vm.stopPrank();

        assertEq(moHost.length(), 0);

        scroll.relayFromHost(true);

        assertEq(moScroll.length(), 2);
        assertEq(moScroll.messages(0), 1);
        assertEq(moScroll.messages(1), 2);

        scroll.relayToHost(true);

        assertEq(moHost.length(), 2);
        assertEq(moHost.messages(0), 3);
        assertEq(moHost.messages(1), 4);

        // Validate the message receiver failure modes
        vm.deal(notL1Authority, scroll.estimateMessageFee(100000));
        vm.startPrank(notL1Authority);
        XChainForwarders.sendMessageScroll(
            address(scroll.L1_SCROLL_MESSENGER()),
            address(moScroll),
            abi.encodeWithSelector(MessageOrdering.push.selector, 999),
            100000,
            scroll.estimateMessageFee(100000)
        );
        vm.stopPrank();

        // The revert is caught so it doesn't propagate
        // Just look at the no change to verify it didn't go through
        scroll.relayFromHost(true);
        assertEq(moScroll.length(), 2); // No change

        scroll.selectFork();
        vm.expectRevert("Receiver/invalid-sender");
        moScroll.push(999);
    }
}
