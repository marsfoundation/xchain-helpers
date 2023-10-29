// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import { ZkEVMDomain } from "../src/testing/ZkEVMDomain.sol";
import { ZkEvmReceiver } from "../src/ZkEvmReceiver.sol";

contract ZkevmMessageOrdering is MessageOrdering, ZkEvmReceiver {
    constructor(address l1Authority) ZkEvmReceiver(l1Authority) {}

    function push(uint256 messageId) public override onlySelf {
        super.push(messageId);
    }

}

contract ZkEVMIntegrationTest is IntegrationBaseTest {
    address l2Authority = makeAddr("l2Authority");

    function test_zkevm() public {
        setChain("zkevm", ChainData("ZkEVM", 1101, "https://zkevm-rpc.com"));

        checkZkEVMStyle(new ZkEVMDomain(getChain("zkevm"), mainnet));
    }

   function checkZkEVMStyle(ZkEVMDomain zkevm) public {
        Domain host = zkevm.hostDomain();

        host.selectFork();

        ZkevmMessageOrdering moHost = new ZkevmMessageOrdering(l2Authority);

        zkevm.selectFork();

        ZkevmMessageOrdering moZkevm = new ZkevmMessageOrdering(l1Authority);

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
    }

}
