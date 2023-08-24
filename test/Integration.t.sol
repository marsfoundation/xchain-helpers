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

contract MessageOrdering {

    uint256[] public messages;

    function push(uint256 messageId) public {
        messages.push(messageId);
    }

}

interface OptimismDaiBridgeLike {
    function depositERC20To(address, address, address, uint256, uint32, bytes calldata) external;
    function withdrawTo(address, address, uint256, uint32, bytes calldata) external;
    function l2Token() external view returns (address);
    function l2DAITokenBridge() external view returns (address);
}

interface ArbitrumDaiBridgeLike {
    function l1Dai() external view returns (address);
    function outboundTransfer(address, address, uint256, uint256, uint256, bytes calldata) external payable;
    function outboundTransfer(address, address, uint256, bytes calldata) external;
    function l2Dai() external view returns (address);
    function l2Counterpart() external view returns (address);
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

    function test_arbitrumOne() public {
        checkArbitrumStyle(new ArbitrumDomain(getChain("arbitrum_one"), mainnet));
    }

    function test_arbitrumOneGoerli() public {
        checkArbitrumStyle(new ArbitrumDomain(getChain("arbitrum_one_goerli"), goerli));
    }

    function test_arbitrumNova() public {
        checkArbitrumStyle(new ArbitrumDomain(getChain("arbitrum_nova"), mainnet));
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

        // Do not relay right away
        host.selectFork();

        // Queue up two more L1 -> L2 messages
        optimism.L1_MESSENGER().sendMessage(
            address(moOptimism),
            abi.encodeWithSelector(MessageOrdering.push.selector, 1),
            100000
        );
        optimism.L1_MESSENGER().sendMessage(
            address(moOptimism),
            abi.encodeWithSelector(MessageOrdering.push.selector, 2),
            100000
        );

        optimism.relayFromHost(true);

        assertEq(moOptimism.messages(0), 1);
        assertEq(moOptimism.messages(1), 2);

        optimism.relayToHost(true);

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

        // Do not relay right away
        host.selectFork();

        // Queue up two more L1 -> L2 messages
        arbitrum.INBOX().createRetryableTicket{value: 1 ether}(
            address(moArbitrum),
            0,
            1 ether,
            msg.sender,
            msg.sender,
            100000,
            0,
            abi.encodeWithSelector(MessageOrdering.push.selector, 1)
        );
        arbitrum.INBOX().createRetryableTicket{value: 1 ether}(
            address(moArbitrum),
            0,
            1 ether,
            msg.sender,
            msg.sender,
            100000,
            0,
            abi.encodeWithSelector(MessageOrdering.push.selector, 2)
        );

        arbitrum.relayFromHost(true);

        assertEq(moArbitrum.messages(0), 1);
        assertEq(moArbitrum.messages(1), 2);

        arbitrum.relayToHost(true);

        assertEq(moHost.messages(0), 3);
        assertEq(moHost.messages(1), 4);
    }

}
