// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import { CCTPBridgeTesting } from "src/testing/bridges/CCTPBridgeTesting.sol";

import { CCTPForwarder } from "src/forwarders/CCTPForwarder.sol";
import { CCTPReceiver }  from "src/CCTPReceiver.sol";

contract MessageOrderingCCTP is MessageOrdering, CCTPReceiver {

    constructor(
        address _destinationMessenger,
        uint32  _sourceDomainId,
        address _sourceAuthority
    ) CCTPReceiver(
        _destinationMessenger,
        _sourceDomainId,
        _sourceAuthority
    ) {}

    function push(uint256 messageId) public override onlyCrossChainMessage {
        super.push(messageId);
    }

}

contract CircleCCTPIntegrationTest is IntegrationBaseTest {

    using CCTPBridgeTesting for *;
    using DomainHelpers     for *;

    address l2Authority = makeAddr("l2Authority");

    function test_avalanche() public {
        checkCircleCCTPStyle(getChain("avalanche").createFork(), CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE);
    }

    function test_optimism() public {
        checkCircleCCTPStyle(getChain("optimism").createFork(), CCTPForwarder.DOMAIN_ID_CIRCLE_OPTIMISM);
    }

    function test_arbitrum_one() public {
        checkCircleCCTPStyle(getChain("arbitrum_one").createFork(), CCTPForwarder.DOMAIN_ID_CIRCLE_ARBITRUM_ONE);
    }

    function test_base() public {
        checkCircleCCTPStyle(getChain("base").createFork(), CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
    }

    function test_polygon() public {
        checkCircleCCTPStyle(getChain("polygon").createFork(), CCTPForwarder.DOMAIN_ID_CIRCLE_POLYGON_POS);
    }

    function checkCircleCCTPStyle(Domain memory destination, uint32 destinationDomainId) public {
        Bridge memory bridge = CCTPBridgeTesting.createCircleBridge(mainnet, destination);

        uint32 sourceDomainId = CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM;

        mainnet.selectFork();

        MessageOrderingCCTP moHost = new MessageOrderingCCTP(
            bridge.sourceCrossChainMessenger,
            destinationDomainId,
            l2Authority
        );

        destination.selectFork();

        MessageOrderingCCTP moCCTP = new MessageOrderingCCTP(
            bridge.destinationCrossChainMessenger,
            sourceDomainId,
            l1Authority
        );

        // Queue up some L2 -> L1 messages
        vm.startPrank(l2Authority);
        CCTPForwarder.sendMessage(
            bridge.destinationCrossChainMessenger,
            sourceDomainId,
            address(moHost),
            abi.encodeWithSelector(MessageOrdering.push.selector, 3)
        );
        CCTPForwarder.sendMessage(
            bridge.destinationCrossChainMessenger,
            sourceDomainId,
            address(moHost),
            abi.encodeWithSelector(MessageOrdering.push.selector, 4)
        );
        vm.stopPrank();

        assertEq(moCCTP.length(), 0);

        // Do not relay right away
        mainnet.selectFork();

        // Queue up two more L1 -> L2 messages
        vm.startPrank(l1Authority);
        CCTPForwarder.sendMessage(
            bridge.sourceCrossChainMessenger,
            destinationDomainId,
            address(moCCTP),
            abi.encodeWithSelector(MessageOrdering.push.selector, 1)
        );
        CCTPForwarder.sendMessage(
            bridge.sourceCrossChainMessenger,
            destinationDomainId,
            address(moCCTP),
            abi.encodeWithSelector(MessageOrdering.push.selector, 2)
        );
        vm.stopPrank();

        assertEq(moHost.length(), 0);

        bridge.relayMessagesToDestination(true);

        assertEq(moCCTP.length(), 2);
        assertEq(moCCTP.messages(0), 1);
        assertEq(moCCTP.messages(1), 2);

        bridge.relayMessagesToSource(true);

        assertEq(moHost.length(), 2);
        assertEq(moHost.messages(0), 3);
        assertEq(moHost.messages(1), 4);

        // Validate the message receiver failure modes
        vm.startPrank(notL1Authority);
        CCTPForwarder.sendMessage(
            bridge.sourceCrossChainMessenger,
            destinationDomainId,
            address(moCCTP),
            abi.encodeWithSelector(MessageOrdering.push.selector, 999)
        );
        vm.stopPrank();

        vm.expectRevert("Receiver/invalid-sourceAuthority");
        bridge.relayMessagesToDestination(true);

        destination.selectFork();
        vm.expectRevert("Receiver/invalid-sender");
        moCCTP.push(999);

        vm.expectRevert("Receiver/invalid-sender");
        moCCTP.handleReceiveMessage(0, bytes32(uint256(uint160(l1Authority))), abi.encodeWithSelector(MessageOrdering.push.selector, 999));

        assertEq(moCCTP.sourceDomainId(), 0);
        vm.prank(bridge.destinationCrossChainMessenger);
        vm.expectRevert("Receiver/invalid-sourceDomain");
        moCCTP.handleReceiveMessage(1, bytes32(uint256(uint160(l1Authority))), abi.encodeWithSelector(MessageOrdering.push.selector, 999));
    }

}
