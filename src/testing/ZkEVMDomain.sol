// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { StdChains } from "forge-std/StdChains.sol";
import { Vm }        from "forge-std/Vm.sol";

import { Domain, BridgedDomain } from "./BridgedDomain.sol";
import { RecordedLogs }          from "./RecordedLogs.sol";

interface IBridgeMessageReceiver {
    function onMessageReceived(address originAddress, uint32 originNetwork, bytes memory data) external payable;
}

interface IZkEVMBridgeLike {
    function bridgeMessage(
        uint32 destinationNetwork,
        address destinationAddress,
        bool forceUpdateGlobalExitRoot,
        bytes calldata metadata
    ) external payable;
}

contract ZkEVMDomain is BridgedDomain {
    IZkEVMBridgeLike public L1_MESSENGER;

    bytes32 constant BRIDGE_EVENT_TOPIC =
        keccak256("BridgeEvent(uint8,uint32,address,uint32,address,uint256,bytes,uint32)");

    uint256 internal lastFromHostLogIndex;
    uint256 internal lastToHostLogIndex;

    constructor(StdChains.Chain memory _chain, Domain _hostDomain) Domain(_chain) BridgedDomain(_hostDomain) {
        bytes32 name = keccak256(bytes(_chain.chainAlias));
        if (name == keccak256("zkevm")) {
            L1_MESSENGER = IZkEVMBridgeLike(0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe);
        } else {
            revert("Unsupported chain");
        }
        vm.recordLogs();
    }

    function relayFromHost(bool switchToGuest) external override {
        selectFork();

        // Read all L1 -> L2 messages and relay them under zkevm fork
        Vm.Log[] memory logs = RecordedLogs.getLogs();
        for (; lastFromHostLogIndex < logs.length; lastFromHostLogIndex++) {
            Vm.Log memory log = logs[lastFromHostLogIndex];
            if (_isBridgeMessageEvent(log, true)) _claimMessage(log);
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
            if (_isBridgeMessageEvent(log, false)) _claimMessage(log);
        }

        if (!switchToHost) {
            selectFork();
        }
    }

    function _isBridgeMessageEvent(Vm.Log memory log, bool host) internal view returns (bool) {
        // early return to prevent abi decode errors
        if (log.topics[0] != BRIDGE_EVENT_TOPIC) return false;

        (uint8 messageType, uint32 originNetwork,,,,,,) =
            abi.decode(log.data, (uint8, uint32, address, uint32, address, uint256, bytes, uint32));
        return
            log.emitter == address(L1_MESSENGER) && messageType == 1 && (host ? originNetwork == 0 : originNetwork == 1);
    }

    function _claimMessage(Vm.Log memory log) internal {
        (
            /* uint8 messageType */
            ,
            uint32 originNetwork,
            address originAddress,
            /* uint32 destinationNetwork */
            ,
            address destinationAddress,
            uint256 msgValue,
            bytes memory metadata,
            /* uint32 depositCount */
        ) = abi.decode(log.data, (uint8, uint32, address, uint32, address, uint256, bytes, uint32));

        // mock bridged eth balance increase
        uint256 prevBalance = address(L1_MESSENGER).balance;
        vm.deal(address(L1_MESSENGER), prevBalance + msgValue);

        // mock bridge callback
        // ref: https://github.com/0xPolygonHermez/zkevm-contracts/blob/main/contracts/PolygonZkEVMBridge.sol#L455-L465
        vm.prank(address(L1_MESSENGER));
        (bool success, bytes memory response) = destinationAddress.call{value: msgValue}(
            abi.encodeCall(IBridgeMessageReceiver.onMessageReceived, (originAddress, originNetwork, metadata))
        );
        if (!success) {
            assembly {
                revert(add(response, 32), mload(response))
            }
        }
    }
}
