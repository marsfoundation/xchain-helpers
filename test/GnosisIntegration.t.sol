// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import { GnosisDomain } from "../src/testing/GnosisDomain.sol";

import { GnosisReceiver } from "../src/GnosisReceiver.sol";

contract MessageOrderingGnosis is MessageOrdering, GnosisReceiver {

    constructor(address _l2CrossDomain, uint256 _chainId, address _l1Authority) GnosisReceiver(_l2CrossDomain, _chainId, _l1Authority) {}

    function push(uint256 messageId) public override onlyCrossChainMessage {
        super.push(messageId);
    }

}

contract GnosisIntegrationTest is IntegrationBaseTest {

    function test_gnosisChain() public {
        checkGnosisStyle(new GnosisDomain(getChain('gnosis_chain'), mainnet), 0x75Df5AF045d91108662D8080fD1FEFAd6aA0bb59);
    }

    function test_chiado() public {
        setChain("chiado", ChainData("Chiado", 10200, "https://rpc.chiadochain.net"));

        checkGnosisStyle(new GnosisDomain(getChain('chiado'), goerli), 0x99Ca51a3534785ED619f46A79C7Ad65Fa8d85e7a);
    }

    function checkGnosisStyle(GnosisDomain gnosis, address _l2CrossDomain) public {
        Domain host = gnosis.hostDomain();

        host.selectFork();

        MessageOrdering moHost = new MessageOrdering();
        uint256 _chainId = block.chainid;

        gnosis.selectFork();

        MessageOrderingGnosis moGnosis = new MessageOrderingGnosis(_l2CrossDomain, _chainId, l1Authority);

        // Queue up some L2 -> L1 messages
        gnosis.L2_AMB_CROSS_DOMAIN_MESSENGER().requireToPassMessage(
            address(moHost),
            abi.encodeWithSelector(MessageOrdering.push.selector, 3),
            100000
        );
        gnosis.L2_AMB_CROSS_DOMAIN_MESSENGER().requireToPassMessage(
            address(moHost),
            abi.encodeWithSelector(MessageOrdering.push.selector, 4),
            100000
        );

        assertEq(moGnosis.length(), 0);

        // Do not relay right away
        host.selectFork();

        // Queue up two more L1 -> L2 messages
        vm.startPrank(l1Authority);
        XChainForwarders.sendMessageGnosis(
            address(gnosis.L1_AMB_CROSS_DOMAIN_MESSENGER()),
            address(moGnosis),
            abi.encodeWithSelector(MessageOrdering.push.selector, 1),
            100000
        );
        XChainForwarders.sendMessageGnosis(
            address(gnosis.L1_AMB_CROSS_DOMAIN_MESSENGER()),
            address(moGnosis),
            abi.encodeWithSelector(MessageOrdering.push.selector, 2),
            100000
        );
        vm.stopPrank();

        assertEq(moHost.length(), 0);

        gnosis.relayFromHost(true);

        assertEq(moGnosis.length(), 2);
        assertEq(moGnosis.messages(0), 1);
        assertEq(moGnosis.messages(1), 2);

        gnosis.relayToHost(true);

        assertEq(moHost.length(), 2);
        assertEq(moHost.messages(0), 3);
        assertEq(moHost.messages(1), 4);

        // Validate the message receiver failure modes
        vm.startPrank(notL1Authority);
        XChainForwarders.sendMessageGnosis(
            address(gnosis.L1_AMB_CROSS_DOMAIN_MESSENGER()),
            address(moGnosis),
            abi.encodeWithSelector(MessageOrdering.push.selector, 999),
            100000
        );
        vm.stopPrank();

        // The revert is caught so it doesn't propagate
        // Just look at the no change to verify it didn't go through
        gnosis.relayFromHost(true);
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
