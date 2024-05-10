// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import { CircleCCTPDomain } from "../src/testing/CircleCCTPDomain.sol";

import { CCTPReceiver } from "../src/CCTPReceiver.sol";

contract MessageOrderingCCTP is MessageOrdering, CCTPReceiver {

    constructor(
        address _l2CrossDomain,
        uint32  _sourceDomain,
        address _l1Authority
    ) CCTPReceiver(
        _l2CrossDomain,
        _sourceDomain,
        _l1Authority
    ) {}

    function push(uint256 messageId) public override onlyCrossChainMessage {
        super.push(messageId);
    }

}

contract CircleCCTPIntegrationTest is IntegrationBaseTest {

    function test_avalanche() public {
        CircleCCTPDomain cctp = new CircleCCTPDomain(getChain("avalanche"), mainnet);
        checkCircleCCTPStyle(cctp, 1);
    }

    function test_optimism() public {
        CircleCCTPDomain cctp = new CircleCCTPDomain(getChain("optimism"), mainnet);
        checkCircleCCTPStyle(cctp, 2);
    }

    function test_arbitrum_one() public {
        CircleCCTPDomain cctp = new CircleCCTPDomain(getChain("arbitrum_one"), mainnet);
        checkCircleCCTPStyle(cctp, 3);
    }

    function test_base() public {
        CircleCCTPDomain cctp = new CircleCCTPDomain(getChain("base"), mainnet);
        checkCircleCCTPStyle(cctp, 6);
    }

    function test_polygon() public {
        CircleCCTPDomain cctp = new CircleCCTPDomain(getChain("polygon"), mainnet);
        checkCircleCCTPStyle(cctp, 7);
    }

    function checkCircleCCTPStyle(CircleCCTPDomain cctp, uint32 guestDomain) public {
        Domain host = cctp.hostDomain();
        uint32 hostDomain = 0;  // Ethereum

        host.selectFork();

        MessageOrderingCCTP moHost = new MessageOrderingCCTP(
            address(cctp.L1_MESSENGER()),
            guestDomain,
            l1Authority
        );

        cctp.selectFork();

        MessageOrderingCCTP moCCTP = new MessageOrderingCCTP(
            address(cctp.L2_MESSENGER()),
            hostDomain,
            l1Authority
        );

        // Queue up some L2 -> L1 messages
        vm.startPrank(l1Authority);
        XChainForwarders.sendMessageCCTP(
            address(cctp.L2_MESSENGER()),
            hostDomain,
            address(moHost),
            abi.encodeWithSelector(MessageOrdering.push.selector, 3)
        );
        XChainForwarders.sendMessageCCTP(
            address(cctp.L2_MESSENGER()),
            hostDomain,
            address(moHost),
            abi.encodeWithSelector(MessageOrdering.push.selector, 4)
        );
        vm.stopPrank();

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

        // Validate the message receiver failure modes
        vm.startPrank(notL1Authority);
        XChainForwarders.sendMessageCircleCCTP(
            guestDomain,
            address(moCCTP),
            abi.encodeWithSelector(MessageOrdering.push.selector, 999)
        );
        vm.stopPrank();

        vm.expectRevert("Receiver/invalid-l1Authority");
        cctp.relayFromHost(true);

        cctp.selectFork();
        vm.expectRevert("Receiver/invalid-sender");
        moCCTP.push(999);

        vm.expectRevert("Receiver/invalid-sender");
        moCCTP.handleReceiveMessage(0, bytes32(uint256(uint160(l1Authority))), abi.encodeWithSelector(MessageOrdering.push.selector, 999));

        assertEq(moCCTP.sourceDomain(), 0);
        vm.prank(address(cctp.L2_MESSENGER()));
        vm.expectRevert("Receiver/invalid-sourceDomain");
        moCCTP.handleReceiveMessage(1, bytes32(uint256(uint160(l1Authority))), abi.encodeWithSelector(MessageOrdering.push.selector, 999));
    }

}
