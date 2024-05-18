// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { StdChains } from "forge-std/StdChains.sol";
import { Vm }        from "forge-std/Vm.sol";

import { Domain, DomainHelpers } from "src/testing/Domain.sol";
import { RecordedLogs }          from "src/testing/utils/RecordedLogs.sol";

interface InboxLike {
    function createRetryableTicket(
        address destAddr,
        uint256 arbTxCallValue,
        uint256 maxSubmissionCost,
        address submissionRefundAddress,
        address valueRefundAddress,
        uint256 maxGas,
        uint256 gasPriceBid,
        bytes calldata data
    ) external payable returns (uint256);
    function bridge() external view returns (BridgeLike);
}

interface BridgeLike {
    function rollup() external view returns (address);
    function executeCall(
        address,
        uint256,
        bytes calldata
    ) external returns (bool, bytes memory);
    function setOutbox(address, bool) external;
}

contract ArbSysOverride {

    event SendTxToL1(address sender, address target, bytes data);

    function sendTxToL1(address target, bytes calldata message) external payable returns (uint256) {
        emit SendTxToL1(msg.sender, target, message);
        return 0;
    }

}

contract ArbitrumNativeBridge is IBidirectionalBridge {

    using DomainHelpers for *;

    bytes32 private constant MESSAGE_DELIVERED_TOPIC = keccak256("MessageDelivered(uint256,bytes32,address,uint8,address,bytes32,uint256,uint64)");
    bytes32 private constant SEND_TO_L1_TOPIC        = keccak256("SendTxToL1(address,address,bytes)");

    address public l2ToL1Sender;

    BridgeData public data;

    constructor(BridgeData memory _data) {
        data = _data;

        data.source.selectFork();
        BridgeLike bridge = InboxLike(data.sourceCrossChainMessenger).bridge();
        vm.recordLogs();
        vm.makePersistent(address(this));

        // Make this contract a valid outbox
        address _rollup = bridge.rollup();
        vm.store(
            address(bridge),
            bytes32(uint256(8)),
            bytes32(uint256(uint160(address(this))))
        );
        bridge.setOutbox(address(this), true);
        vm.store(
            address(bridge),
            bytes32(uint256(8)),
            bytes32(uint256(uint160(_rollup)))
        );

        // Need to replace ArbSys contract with custom code to make it compatible with revm
        destination.selectFork();
        bytes memory bytecode = vm.getCode("ArbitrumDomain.sol:ArbSysOverride");
        address deployed;
        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        vm.etch(ARB_SYS, deployed.code);

        source.selectFork();
    }

    function parseData(bytes memory orig) private pure returns (address target, bytes memory message) {
        // FIXME - this is not robust enough, only handling messages of a specific format
        uint256 mlen;
        (,,target ,,,,,,,, mlen) = abi.decode(orig, (uint256, uint256, address, uint256, uint256, uint256, address, address, uint256, uint256, uint256));
        message = new bytes(mlen);
        for (uint256 i = 0; i < mlen; i++) {
            message[i] = orig[i + 352];
        }
    }

    function relayMessagesToSource(bool switchToDestinationFork) external override {
        destination.selectFork();

        // Read all L1 -> L2 messages and relay them under Arbitrum fork
        Vm.Log[] memory logs = RecordedLogs.getLogs();
        for (; lastFromHostLogIndex < logs.length; lastFromHostLogIndex++) {
            Vm.Log memory log = logs[lastFromHostLogIndex];
            if (log.topics[0] == MESSAGE_DELIVERED_TOPIC) {
                // We need both the current event and the one that follows for all the relevant data
                Vm.Log memory logWithData = logs[lastFromHostLogIndex + 1];
                (,, address sender,,,) = abi.decode(log.data, (address, uint8, address, bytes32, uint256, uint64));
                (address target, bytes memory message) = parseData(logWithData.data);
                vm.startPrank(sender);
                (bool success, bytes memory response) = target.call(message);
                vm.stopPrank();
                if (!success) {
                    assembly {
                        revert(add(response, 32), mload(response))
                    }
                }
            }
        }

        if (!switchToDestinationFork) {
            source.selectFork();
        }
    }

    function relayMessagesToSource(bool switchToSourceFork) external override {
        source.selectFork();

        // Read all L2 -> L1 messages and relay them under host fork
        Vm.Log[] memory logs = RecordedLogs.getLogs();
        for (; lastToHostLogIndex < logs.length; lastToHostLogIndex++) {
            Vm.Log memory log = logs[lastToHostLogIndex];
            if (log.topics[0] == SEND_TO_L1_TOPIC) {
                (address sender, address target, bytes memory message) = abi.decode(log.data, (address, address, bytes));
                l2ToL1Sender = sender;
                (bool success, bytes memory response) = InboxLike(data.sourceCrossChainMessenger).bridge().executeCall(target, 0, message);
                if (!success) {
                    assembly {
                        revert(add(response, 32), mload(response))
                    }
                }
            }
        }

        if (!switchToSourceFork) {
            destination.selectFork();
        }
    }

}
