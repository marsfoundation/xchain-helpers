// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2021 Dai Foundation
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
pragma solidity >=0.8.0;

import "./IntegrationBase.t.sol";

import { ZkEVMDomain, IBridgeMessageReceiver } from "../src/testing/ZkEVMDomain.sol";

contract ZkevmMessageOrdering is MessageOrdering, IBridgeMessageReceiver {
    function onMessageReceived(address /*originAddress*/, uint32 /*originNetwork*/, bytes memory data) external payable {
        // call the specific method
        (bool success, bytes memory ret) = address(this).call(data);
        if (!success) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
    }

}

contract ZkEVMIntegrationTest is IntegrationBaseTest {

    function test_zkevm() public {
        setChain("zkevm", ChainData("ZkEVM", 1101, "https://zkevm-rpc.com"));

        checkZkEVMStyle(new ZkEVMDomain(getChain("zkevm"), mainnet));
    }

   function checkZkEVMStyle(ZkEVMDomain zkevm) public {
        Domain host = zkevm.hostDomain();

        host.selectFork();

        ZkevmMessageOrdering moHost = new ZkevmMessageOrdering();

        zkevm.selectFork();

        ZkevmMessageOrdering moZkevm = new ZkevmMessageOrdering();

        // Queue up two more L1 -> L2 messages
        zkevm.L1_MESSENGER().bridgeMessage(0, address(moHost), true, abi.encodeCall(MessageOrdering.push, (3)));
        zkevm.L1_MESSENGER().bridgeMessage(0, address(moHost), true, abi.encodeCall(MessageOrdering.push, (4)));

        assertEq(moZkevm.length(), 0);

        host.selectFork();

        // Queue up two more L1 -> L2 messages
        XChainForwarders.sendMessageZkEVM(1, address(moZkevm), true, abi.encodeCall(MessageOrdering.push, (1)));
        XChainForwarders.sendMessageZkEVM(1, address(moZkevm), true, abi.encodeCall(MessageOrdering.push, (2)));

        assertEq(moHost.length(), 0);

        zkevm.relayFromHost(true);

        assertEq(moZkevm.length(), 2);
        assertEq(moZkevm.messages(0), 1);
        assertEq(moZkevm.messages(1), 2);

        zkevm.relayToHost(true);

        assertEq(moHost.length(), 2);
        assertEq(moHost.messages(0), 3);
        assertEq(moHost.messages(1), 4);
    }

}
