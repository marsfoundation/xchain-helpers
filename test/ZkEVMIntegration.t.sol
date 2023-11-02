// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import { ZkEVMDomain } from "../src/testing/ZkEVMDomain.sol";

import { ZkEVMReceiver } from "../src/ZkEVMReceiver.sol";

contract ZkEVMMessageOrdering is MessageOrdering, ZkEVMReceiver {
    constructor(address l1Authority, uint32 networkId) ZkEVMReceiver(l1Authority, networkId) {}

    function push(uint256 messageId) public override onlyCrossChainMessage {
        super.push(messageId);
    }

}

contract ZkEVMIntegrationTest is IntegrationBaseTest {
    address l2Authority    = makeAddr("l2Authority");
    address notL2Authority = makeAddr("notL2Authority");

    function test_zkevm() public {
        setChain("zkevm", ChainData("ZkEVM", 1101, "https://zkevm-rpc.com"));

        checkZkEVMStyle(new ZkEVMDomain(getChain("zkevm"), mainnet));
    }

    function checkZkEVMStyle(ZkEVMDomain zkevm) public {
        Domain host = zkevm.hostDomain();

        host.selectFork();

        // origin network of the other leg, so 1 for host and 0 for l2
        ZkEVMMessageOrdering moHost = new ZkEVMMessageOrdering(l2Authority, 1);

        zkevm.selectFork();

        ZkEVMMessageOrdering moZkevm = new ZkEVMMessageOrdering(l1Authority, 0);

        vm.startPrank(l2Authority);
        // Queue up two more L2 -> L1 messages
        zkevm.L1_MESSENGER().bridgeMessage(0, address(moHost), true, abi.encodeCall(MessageOrdering.push, (3)));
        zkevm.L1_MESSENGER().bridgeMessage(0, address(moHost), true, abi.encodeCall(MessageOrdering.push, (4)));
        vm.stopPrank();

        assertEq(moZkevm.length(), 0);

        host.selectFork();

        vm.startPrank(l1Authority);
        // Queue up two more L1 -> L2 messages
        XChainForwarders.sendMessageZkEVM(address(moZkevm), abi.encodeCall(MessageOrdering.push, (1)));
        XChainForwarders.sendMessageZkEVM(address(moZkevm), abi.encodeCall(MessageOrdering.push, (2)));
        vm.stopPrank();

        assertEq(moHost.length(), 0);

        zkevm.relayFromHost(true);

        assertEq(moZkevm.length(), 2);
        assertEq(moZkevm.messages(0), 1);
        assertEq(moZkevm.messages(1), 2);

        zkevm.relayToHost(true);

        assertEq(moHost.length(), 2);
        assertEq(moHost.messages(0), 3);
        assertEq(moHost.messages(1), 4);

        // Validate the message receiver failure modes
        vm.startPrank(notL1Authority);
        XChainForwarders.sendMessageZkEVM(address(moZkevm), abi.encodeCall(MessageOrdering.push, (999)));
        vm.stopPrank();

        vm.expectRevert("Receiver/invalid-l1Authority");
        zkevm.relayFromHost(true);
        assertEq(moZkevm.length(), 2); // No change

        zkevm.selectFork();
        vm.expectRevert("Receiver/invalid-sender");
        moZkevm.push(999);

        // validate message sender is bridge
        vm.expectRevert("Receiver/invalid-sender");
        moZkevm.onMessageReceived(address(moHost), 0, abi.encodeCall(MessageOrdering.push, (1000)));

        // validate origin network is correct
        // cannot queue from l1 and relayFromHost because relayFromHost filters
        // on the basis of origin network being 1
        vm.startPrank(moZkevm.bridge());
        vm.expectRevert("Receiver/invalid-originNetwork");
        moZkevm.onMessageReceived(address(moZkevm), 2, abi.encodeCall(MessageOrdering.push, (1001)));
        vm.stopPrank();
    }

}
