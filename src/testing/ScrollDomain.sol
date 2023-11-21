// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { StdChains } from "forge-std/StdChains.sol";
import { Vm }        from "forge-std/Vm.sol";

import { Domain, BridgedDomain } from "./BridgedDomain.sol";
import { RecordedLogs }          from "./RecordedLogs.sol";

interface MessengerLike {
    function sendMessage(
        address target,
        uint256 value,
        bytes calldata message,
        uint256 gasLimit
    ) external payable;

    function sendMessage(
        address target,
        uint256 value,
        bytes calldata message,
        uint256 gasLimit,
        address refundAddress
    ) external payable;

    function relayMessage(
        address from,
        address to,
        uint256 value,
        uint256 nonce,
        bytes calldata message
    ) external;
}

interface MessageQueueLike {
    function estimateCrossDomainMessageFee(uint256 gasLimit) external view returns (uint256);
}

contract ScrollDomain is BridgedDomain {

    bytes32 private constant SENT_MESSAGE_TOPIC = keccak256("SentMessage(address,address,uint256,uint256,uint256,bytes)");
    uint160 private constant OFFSET = uint160(0x1111000000000000000000000000000000001111);

    MessengerLike public L1_SCROLL_MESSENGER;
    MessengerLike public L2_SCROLL_MESSENGER;
    MessageQueueLike public L1_MESSAGE_QUEUE;

    uint256 internal lastFromHostLogIndex;
    uint256 internal lastToHostLogIndex;

    constructor(StdChains.Chain memory _chain, Domain _hostDomain) Domain(_chain) BridgedDomain(_hostDomain) {
        bytes32 name = keccak256(bytes(_chain.chainAlias));
        if (name == keccak256("scroll")) {
            L1_SCROLL_MESSENGER = MessengerLike(0x6774Bcbd5ceCeF1336b5300fb5186a12DDD8b367);
            L2_SCROLL_MESSENGER = MessengerLike(0x781e90f1c8Fc4611c9b7497C3B47F99Ef6969CbC);
            L1_MESSAGE_QUEUE = MessageQueueLike(0x0d7E906BD9cAFa154b048cFa766Cc1E54E39AF9B);
        } else if (name == keccak256("scroll_sepolia")) {
            L1_SCROLL_MESSENGER = MessengerLike(0x50c7d3e7f7c656493D1D76aaa1a836CedfCBB16A);
            L2_SCROLL_MESSENGER = MessengerLike(0xBa50f5340FB9F3Bd074bD638c9BE13eCB36E603d);
            L1_MESSAGE_QUEUE = MessageQueueLike(0xF0B2293F5D834eAe920c6974D50957A1732de763);
        } else {
            revert("Unsupported chain");
        }

        vm.recordLogs();
    }

    function relayFromHost(bool switchToGuest) external override {
        selectFork();

        address malias;
        unchecked {
            malias = address(uint160(address(L1_SCROLL_MESSENGER)) + OFFSET);
        }

        // Read all L1 -> L2 messages and relay them under Optimism fork
        Vm.Log[] memory allLogs = RecordedLogs.getLogs();
        for (; lastFromHostLogIndex < allLogs.length; lastFromHostLogIndex++) {
            Vm.Log memory _log = allLogs[lastFromHostLogIndex];
            if (_log.topics[0] == SENT_MESSAGE_TOPIC && _log.emitter == address(L1_SCROLL_MESSENGER)) {
                address sender = address(uint160(uint256(_log.topics[1])));
                address target = address(uint160(uint256(_log.topics[2])));
                (uint256 value, uint256 nonce, uint256 gasLimit, bytes memory message) = abi.decode(
                    _log.data,
                    (uint256, uint256, uint256, bytes)
                );
                vm.prank(malias);
                L2_SCROLL_MESSENGER.relayMessage{gas: gasLimit}(
                    sender,
                    target,
                    value,
                    nonce,
                    message
                );
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
        Vm.Log[] memory allLogs = RecordedLogs.getLogs();
        for (; lastToHostLogIndex < allLogs.length; lastToHostLogIndex++) {
            Vm.Log memory _log = allLogs[lastToHostLogIndex];
            if (_log.topics[0] == SENT_MESSAGE_TOPIC && _log.emitter == address(L2_SCROLL_MESSENGER)) {
                address sender = address(uint160(uint256(_log.topics[1])));
                address target = address(uint160(uint256(_log.topics[2])));
                (uint256 value, , , bytes memory message) = abi.decode(_log.data, (uint256, uint256, uint256, bytes));
                // Set xDomainMessageSender
                vm.store(address(L1_SCROLL_MESSENGER), bytes32(uint256(201)), bytes32(uint256(uint160(sender))));
                vm.startPrank(address(L1_SCROLL_MESSENGER));
                (bool success, bytes memory response) = target.call{value: value}(message);
                vm.stopPrank();
                vm.store(address(L1_SCROLL_MESSENGER), bytes32(uint256(201)), bytes32(uint256(1)));
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

    function estimateMessageFee(uint256 gasLimit) public view returns (uint256) {
        return L1_MESSAGE_QUEUE.estimateCrossDomainMessageFee(gasLimit);
    }
}
