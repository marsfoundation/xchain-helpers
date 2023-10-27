// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { StdChains } from "forge-std/StdChains.sol";
import { Vm }        from "forge-std/Vm.sol";

import { Domain, BridgedDomain } from "./BridgedDomain.sol";
import { RecordedLogs }          from "./RecordedLogs.sol";

interface MessengerLike {
    function sendMessage(
        address target,
        bytes memory message,
        uint32 gasLimit
    ) external;
    function relayMessage(
        uint256 _nonce,
        address _sender,
        address _target,
        uint256 _value,
        uint256 _minGasLimit,
        bytes calldata _message
    ) external payable;
}

contract OptimismDomain is BridgedDomain {

    bytes32 private constant SENT_MESSAGE_TOPIC = keccak256("SentMessage(address,address,bytes,uint256,uint256)");
    uint160 private constant OFFSET = uint160(0x1111000000000000000000000000000000001111);

    MessengerLike public L1_MESSENGER;
    MessengerLike public constant L2_MESSENGER = MessengerLike(0x4200000000000000000000000000000000000007);

    uint256 internal lastFromHostLogIndex;
    uint256 internal lastToHostLogIndex;

    constructor(StdChains.Chain memory _chain, Domain _hostDomain) Domain(_chain) BridgedDomain(_hostDomain) {
        bytes32 name = keccak256(bytes(_chain.chainAlias));
        if (name == keccak256("optimism")) {
            L1_MESSENGER = MessengerLike(0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1);
        } else if (name == keccak256("optimism_goerli")) {
            L1_MESSENGER = MessengerLike(0x5086d1eEF304eb5284A0f6720f79403b4e9bE294);
        } else if (name == keccak256("base")) {
            L1_MESSENGER = MessengerLike(0x866E82a600A1414e583f7F13623F1aC5d58b0Afa);
        } else if (name == keccak256("base_goerli")) {
            L1_MESSENGER = MessengerLike(0x8e5693140eA606bcEB98761d9beB1BC87383706D);
        } else {
            revert("Unsupported chain");
        }

        vm.recordLogs();
    }

    function relayFromHost(bool switchToGuest) external override {
        selectFork();
        address malias;
        unchecked {
            malias = address(uint160(address(L1_MESSENGER)) + OFFSET);
        }

        // Read all L1 -> L2 messages and relay them under Optimism fork
        Vm.Log[] memory logs = RecordedLogs.getLogs();
        for (; lastFromHostLogIndex < logs.length; lastFromHostLogIndex++) {
            Vm.Log memory log = logs[lastFromHostLogIndex];
            if (log.topics[0] == SENT_MESSAGE_TOPIC && log.emitter == address(L1_MESSENGER)) {
                address target = address(uint160(uint256(log.topics[1])));
                (address sender, bytes memory message, uint256 nonce, uint256 gasLimit) = abi.decode(log.data, (address, bytes, uint256, uint256));
                vm.prank(malias);
                L2_MESSENGER.relayMessage(nonce, sender, target, 0, gasLimit, message);
            }
        }

        if (!switchToGuest) {
            hostDomain.selectFork();
        }
    }

    function relayToHost(bool switchToHost) external override {
        hostDomain.selectFork();

        // Read all L2 -> L1 messages and relay them under Primary fork
        // Note: We bypass the L1 messenger relay here because it's easier to not have to generate valid state roots / merkle proofs
        Vm.Log[] memory logs = RecordedLogs.getLogs();
        for (; lastToHostLogIndex < logs.length; lastToHostLogIndex++) {
            Vm.Log memory log = logs[lastToHostLogIndex];
            if (log.topics[0] == SENT_MESSAGE_TOPIC && log.emitter == address(L2_MESSENGER)) {
                address target = address(uint160(uint256(log.topics[1])));
                (address sender, bytes memory message,,) = abi.decode(log.data, (address, bytes, uint256, uint256));
                // Set xDomainMessageSender
                vm.store(
                    address(L1_MESSENGER),
                    bytes32(uint256(204)),
                    bytes32(uint256(uint160(sender)))
                );
                vm.startPrank(address(L1_MESSENGER));
                (bool success, bytes memory response) = target.call(message);
                vm.stopPrank();
                vm.store(
                    address(L1_MESSENGER),
                    bytes32(uint256(204)),
                    bytes32(uint256(0))
                );
                if (!success) {
                    assembly {
                        revert(add(response, 32), mload(response))
                    }
                }
            }
        }

        if (!switchToHost) {
            selectFork();
        }
    }

}
