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

import "forge-std/Test.sol";

import { Domain } from "../src/Domain.sol";
import { OptimismDomain } from "../src/OptimismDomain.sol";
import { ArbitrumDomain, ArbSysOverride } from "../src/ArbitrumDomain.sol";
import { GnosisDomain } from "../src/GnosisDomain.sol";
import { XChainForwarders } from "../src/XChainForwarders.sol";
import { ZkEVMDomain, IBridgeMessageReceiver } from "../src/ZkEVMDomain.sol";

contract MessageOrdering {

    uint256[] public messages;

    function push(uint256 messageId) public {
        messages.push(messageId);
    }

    function length() public view returns (uint256) {
        return messages.length;
    }
}

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

contract IntegrationTest is Test {

    Domain mainnet;
    Domain goerli;

    function setUp() public {
        mainnet = new Domain(getChain("mainnet"));
        goerli = new Domain(getChain("goerli"));
    }

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

    function test_arbitrumOne() public {
        checkArbitrumStyle(new ArbitrumDomain(getChain("arbitrum_one"), mainnet));
    }

    function test_arbitrumOneGoerli() public {
        checkArbitrumStyle(new ArbitrumDomain(getChain("arbitrum_one_goerli"), goerli));
    }

    function test_arbitrumNova() public {
        checkArbitrumStyle(new ArbitrumDomain(getChain("arbitrum_nova"), mainnet));
    }

    function test_gnosisChain() public {
        checkGnosisStyle(new GnosisDomain(getChain('gnosis_chain'), mainnet));
    }

    function test_chiado() public {
        setChain("chiado", ChainData("Chiado", 10200, "https://rpc.chiadochain.net"));

        checkGnosisStyle(new GnosisDomain(getChain('chiado'), goerli));
    }

    function test_zkevm() public {
        setChain("zkevm", ChainData("ZkEVM", 1101, "https://zkevm-rpc.com"));

        checkZkEVM(new ZkEVMDomain(getChain("zkevm"), mainnet));
    }

    function checkOptimismStyle(OptimismDomain optimism) public {
        Domain host = optimism.hostDomain();

        host.selectFork();

        MessageOrdering moHost = new MessageOrdering();

        optimism.selectFork();

        MessageOrdering moOptimism = new MessageOrdering();

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

        assertEq(moHost.length(), 0);

        optimism.relayFromHost(true);

        assertEq(moOptimism.length(), 2);
        assertEq(moOptimism.messages(0), 1);
        assertEq(moOptimism.messages(1), 2);

        optimism.relayToHost(true);

        assertEq(moHost.length(), 2);
        assertEq(moHost.messages(0), 3);
        assertEq(moHost.messages(1), 4);
    }

    function checkArbitrumStyle(ArbitrumDomain arbitrum) public {
        Domain host = arbitrum.hostDomain();

        host.selectFork();

        MessageOrdering moHost = new MessageOrdering();

        arbitrum.selectFork();

        MessageOrdering moArbitrum = new MessageOrdering();

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

        assertEq(moHost.length(), 0);

        arbitrum.relayFromHost(true);

        assertEq(moArbitrum.length(), 2);
        assertEq(moArbitrum.messages(0), 1);
        assertEq(moArbitrum.messages(1), 2);

        arbitrum.relayToHost(true);

        assertEq(moHost.length(), 2);
        assertEq(moHost.messages(0), 3);
        assertEq(moHost.messages(1), 4);
    }

    function checkGnosisStyle(GnosisDomain gnosis) public {
        Domain host = gnosis.hostDomain();

        host.selectFork();

        MessageOrdering moHost = new MessageOrdering();

        gnosis.selectFork();

        MessageOrdering moGnosis = new MessageOrdering();

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

        assertEq(moHost.length(), 0);

        gnosis.relayFromHost(true);

        assertEq(moGnosis.length(), 2);
        assertEq(moGnosis.messages(0), 1);
        assertEq(moGnosis.messages(1), 2);

        gnosis.relayToHost(true);

        assertEq(moHost.length(), 2);
        assertEq(moHost.messages(0), 3);
        assertEq(moHost.messages(1), 4);

    }

    function checkZkEVM(ZkEVMDomain zkevm) public {
        Domain host = zkevm.hostDomain();

        host.selectFork();

        ZkevmMessageOrdering moHost = new ZkevmMessageOrdering();

        zkevm.selectFork();

        ZkevmMessageOrdering moZkevm = new ZkevmMessageOrdering();

        // Queue up two more L1 -> L2 messages
        zkevm.bridge().bridgeMessage(0, address(moHost), true, abi.encodeCall(MessageOrdering.push, (3)));
        zkevm.bridge().bridgeMessage(0, address(moHost), true, abi.encodeCall(MessageOrdering.push, (4)));

        assertEq(moZkevm.length(), 0);

        host.selectFork();

        // Queue up two more L1 -> L2 messages
        XChainForwarders.sendMessageZkevm(1, address(moZkevm), true, abi.encodeCall(MessageOrdering.push, (1)));
        XChainForwarders.sendMessageZkevm(1, address(moZkevm), true, abi.encodeCall(MessageOrdering.push, (2)));

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
