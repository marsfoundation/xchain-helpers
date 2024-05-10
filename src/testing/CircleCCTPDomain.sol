// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { StdChains } from "forge-std/StdChains.sol";
import { Vm }        from "forge-std/Vm.sol";

import { Domain, BridgedDomain } from "./BridgedDomain.sol";
import { RecordedLogs }          from "./RecordedLogs.sol";

interface MessengerLike {
    function receiveMessage(bytes calldata message, bytes calldata attestation) external returns (bool success);
}

contract CircleCCTPDomain is BridgedDomain {

    bytes32 private constant SENT_MESSAGE_TOPIC = keccak256("MessageSent(bytes)");

    MessengerLike public constant L1_MESSENGER = MessengerLike(0x0a992d191DEeC32aFe36203Ad87D7d289a738F81);
    MessengerLike public L2_MESSENGER;

    uint256 internal lastFromHostLogIndex;
    uint256 internal lastToHostLogIndex;

    constructor(StdChains.Chain memory _chain, Domain _hostDomain) Domain(_chain) BridgedDomain(_hostDomain) {
        bytes32 name = keccak256(bytes(_chain.chainAlias));
        if (name == keccak256("avalanche")) {
            L2_MESSENGER = MessengerLike(0x8186359aF5F57FbB40c6b14A588d2A59C0C29880);
        } else if (name == keccak256("optimism")) {
            L2_MESSENGER = MessengerLike(0x4D41f22c5a0e5c74090899E5a8Fb597a8842b3e8);
        } else if (name == keccak256("arbitrum_one")) {
            L2_MESSENGER = MessengerLike(0xC30362313FBBA5cf9163F0bb16a0e01f01A896ca);
        } else if (name == keccak256("base")) {
            L2_MESSENGER = MessengerLike(0xAD09780d193884d503182aD4588450C416D6F9D4);
        } else if (name == keccak256("polygon")) {
            L2_MESSENGER = MessengerLike(0xF3be9355363857F3e001be68856A2f96b4C39Ba9);
        } else {
            revert("Unsupported chain");
        }

        // Set minimum required signatures to zero for both domains
        selectFork();
        vm.store(
            address(L2_MESSENGER),
            bytes32(uint256(4)),
            0
        );
        hostDomain.selectFork();
        vm.store(
            address(L1_MESSENGER),
            bytes32(uint256(4)),
            0
        );

        vm.recordLogs();
    }

    function relayFromHost(bool switchToGuest) external override {
        selectFork();

        // Read all L1 -> L2 messages and relay them under CCTP fork
        Vm.Log[] memory logs = RecordedLogs.getLogs();
        for (; lastFromHostLogIndex < logs.length; lastFromHostLogIndex++) {
            Vm.Log memory log = logs[lastFromHostLogIndex];
            if (log.topics[0] == SENT_MESSAGE_TOPIC && log.emitter == address(L1_MESSENGER)) {
                L2_MESSENGER.receiveMessage(removeFirst64Bytes(log.data), "");
            }
        }

        if (!switchToGuest) {
            hostDomain.selectFork();
        }
    }

    function relayToHost(bool switchToHost) external override {
        hostDomain.selectFork();

        // Read all L2 -> L1 messages and relay them under host fork
        Vm.Log[] memory logs = RecordedLogs.getLogs();
        for (; lastToHostLogIndex < logs.length; lastToHostLogIndex++) {
            Vm.Log memory log = logs[lastToHostLogIndex];
            if (log.topics[0] == SENT_MESSAGE_TOPIC && log.emitter == address(L2_MESSENGER)) {
                L1_MESSENGER.receiveMessage(removeFirst64Bytes(log.data), "");
            }
        }

        if (!switchToHost) {
            selectFork();
        }
    }

    function removeFirst64Bytes(bytes memory inputData) public pure returns (bytes memory) {
        bytes memory returnValue = new bytes(inputData.length - 64);
        for (uint256 i = 0; i < inputData.length - 64; i++) {
            returnValue[i] = inputData[i + 64];
        }
        return returnValue;
    }

}
