// SPDX-FileCopyrightText: © 2022 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
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

import {Vm} from "forge-std/Vm.sol";
import {StdChains} from "forge-std/StdChains.sol";

import {Domain, BridgedDomain} from "./BridgedDomain.sol";
import {RecordedLogs} from "./RecordedLogs.sol";

interface IBridgeMessageReceiver {
    function onMessageReceived(address originAddress, uint32 originNetwork, bytes memory data) external payable;
}

contract ZkEVMDomain is BridgedDomain {
    error MessageFailed();

    address constant ZKEVM_BRIDGE = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;

    // event BridgeEvent(
    //     uint8 leafType, // type asset = 0, type message = 1
    //     uint32 originNetwork,
    //     address originAddress,
    //     uint32 destinationNetwork,
    //     address destinationAddress,
    //     uint256 amount,
    //     bytes metadata,
    //     uint32 depositCount
    // );
    bytes32 constant BRIDGE_EVENT_TOPIC =
        keccak256("BridgeEvent(uint8,uint32,address,uint32,address,uint256,bytes,uint32)");

    uint256 internal lastFromHostLogIndex;
    uint256 internal lastToHostLogIndex;

    constructor(StdChains.Chain memory _chain, Domain _hostDomain) Domain(_chain) BridgedDomain(_hostDomain) {
        bytes32 name = keccak256(bytes(_chain.chainAlias));

        vm.recordLogs();
    }

    function relayFromHost(bool switchToGuest) external override {
        selectFork();

        // Read all L1 -> L2 messages and relay them under zkevm fork
        Vm.Log[] memory logs = RecordedLogs.getLogs();
        for (; lastFromHostLogIndex < logs.length; lastFromHostLogIndex++) {
            Vm.Log memory log = logs[lastFromHostLogIndex];
            if (_isBridgeMessageEvent(log)) _claimMessage(log);
        }

        if (!switchToGuest) {
            hostDomain.selectFork();
        }
    }

    function relayToHost(bool switchToHost) external override {
        hostDomain.selectFork();

        // Read all L2 -> L1 messages and relay them under Primary fork
        Vm.Log[] memory logs = RecordedLogs.getLogs();
        for (; lastToHostLogIndex < logs.length; lastToHostLogIndex++) {
            Vm.Log memory log = logs[lastToHostLogIndex];
            if (_isBridgeMessageEvent(log)) _claimMessage(log);
        }

        if (!switchToHost) {
            selectFork();
        }
    }

    function _isBridgeMessageEvent(Vm.Log memory log) internal pure returns (bool) {
        (uint8 messageType,,,,,,,) =
            abi.decode(log.data, (uint8, uint32, address, uint32, address, uint256, bytes, uint32));
        return log.topics[0] == BRIDGE_EVENT_TOPIC && log.emitter == address(ZKEVM_BRIDGE) && messageType == 1;
    }

    function _claimMessage(Vm.Log memory log) internal {
        require(_isBridgeMessageEvent(log), "ZkEVMDomain: !bridgeMessage");
        (
            uint8 messageType,
            uint32 originNetwork,
            address originAddress,
            uint32 destinationNetwork,
            address destinationAddress,
            uint256 msgValue,
            bytes memory metadata,
            /* uint32 depositCount */
        ) = abi.decode(log.data, (uint8, uint32, address, uint32, address, uint256, bytes, uint32));

        // mock bridged eth balance increase
        uint256 prevBalance = ZKEVM_BRIDGE.balance;
        vm.deal(ZKEVM_BRIDGE, prevBalance + msgValue);

        // mock bridge callback
        // ref: https://github.com/0xPolygonHermez/zkevm-contracts/blob/main/contracts/PolygonZkEVMBridge.sol#L455-L465
        vm.prank(ZKEVM_BRIDGE);
        (bool success,) = destinationAddress.call{value: msgValue}(
            abi.encodeCall(IBridgeMessageReceiver.onMessageReceived, (originAddress, originNetwork, metadata))
        );
        if (!success) {
            revert MessageFailed();
        }
    }
}
