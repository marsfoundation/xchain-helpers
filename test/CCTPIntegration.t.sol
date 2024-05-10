// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import { CircleCCTPDomain } from "../src/testing/CircleCCTPDomain.sol";

import { CCTPReceiver } from "../src/CCTPReceiver.sol";

contract MessageOrderingCCTP is MessageOrdering, CCTPReceiver {

    constructor(
        address _l2CrossDomain,
        uint32  _chainId,
        address _l1Authority
    ) CCTPReceiver(
        _l2CrossDomain,
        _chainId,
        _l1Authority
    ) {}

    function push(uint256 messageId) public override onlyCrossChainMessage {
        super.push(messageId);
    }

}

contract CircleCCTPIntegrationTest is IntegrationBaseTest {

    function test_optimism() public {
        CircleCCTPDomain cctp = new CircleCCTPDomain(getChain("optimism"), mainnet);
        checkCircleCCTPStyle(cctp, 2);
    }

    function checkCircleCCTPStyle(CircleCCTPDomain cctp, uint32 guestDomain) public {
        Domain host = cctp.hostDomain();

        host.selectFork();

        MessageOrdering moHost = new MessageOrdering();

        cctp.selectFork();

        MessageOrderingCCTP moCCTP = new MessageOrderingCCTP(
            address(cctp.L2_MESSENGER()),
            0,  // Ethereum
            l1Authority
        );

        // Queue up some L2 -> L1 messages
        XChainForwarders.sendMessageCCTP(
            address(cctp.L2_MESSENGER()),
            0,  // Ethereum
            address(moHost),
            abi.encodeWithSelector(MessageOrdering.push.selector, 3)
        );
        XChainForwarders.sendMessageCCTP(
            address(cctp.L2_MESSENGER()),
            0,
            address(moHost),
            abi.encodeWithSelector(MessageOrdering.push.selector, 4)
        );

        assertEq(moCCTP.length(), 0);

        // Do not relay right away
        host.selectFork();

        // Queue up two more L1 -> L2 messages
        vm.startPrank(l1Authority);
        XChainForwarders.sendMessageCircleCCTP(
            guestDomain,
            address(moCCTP),
            abi.encodeWithSelector(MessageOrdering.push.selector, 1)
        );
        XChainForwarders.sendMessageCircleCCTP(
            guestDomain,
            address(moCCTP),
            abi.encodeWithSelector(MessageOrdering.push.selector, 2)
        );
        vm.stopPrank();

        assertEq(moHost.length(), 0);

        cctp.relayFromHost(true);

        assertEq(moCCTP.length(), 2);
        assertEq(moCCTP.messages(0), 1);
        assertEq(moCCTP.messages(1), 2);

        cctp.relayToHost(true);

        assertEq(moHost.length(), 2);
        assertEq(moHost.messages(0), 3);
        assertEq(moHost.messages(1), 4);

        return;

        // Validate the message receiver failure modes
        vm.startPrank(notL1Authority);
        XChainForwarders.sendMessageCircleCCTP(
            guestDomain,
            address(moCCTP),
            abi.encodeWithSelector(MessageOrdering.push.selector, 999)
        );
        vm.stopPrank();

        vm.expectRevert("handleReceiveMessage() failed");
        cctp.relayFromHost(true);

        cctp.selectFork();
        vm.expectRevert("Receiver/invalid-sender");
        moCCTP.push(999);

        // TODO test the source domain doesn't match will revert
    }

}
