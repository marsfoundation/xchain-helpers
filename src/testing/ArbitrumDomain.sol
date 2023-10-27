// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { StdChains } from "forge-std/StdChains.sol";
import { Vm }        from "forge-std/Vm.sol";

import { Domain, BridgedDomain } from "./BridgedDomain.sol";
import { RecordedLogs }          from "./RecordedLogs.sol";

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
    function bridge() external view returns (address);
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

contract ArbitrumDomain is BridgedDomain {

    bytes32 private constant MESSAGE_DELIVERED_TOPIC = keccak256("MessageDelivered(uint256,bytes32,address,uint8,address,bytes32,uint256,uint64)");
    bytes32 private constant SEND_TO_L1_TOPIC        = keccak256("SendTxToL1(address,address,bytes)");

    address public constant ARB_SYS = 0x0000000000000000000000000000000000000064;
    InboxLike public INBOX;
    BridgeLike public immutable BRIDGE;

    address public l2ToL1Sender;

    uint256 internal lastFromHostLogIndex;
    uint256 internal lastToHostLogIndex;

    constructor(StdChains.Chain memory _chain, Domain _hostDomain) Domain(_chain) BridgedDomain(_hostDomain) {
        bytes32 name = keccak256(bytes(_chain.chainAlias));
        if (name == keccak256("arbitrum_one")) {
            INBOX = InboxLike(0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f);
        } else if (name == keccak256("arbitrum_one_goerli")) {
            INBOX = InboxLike(0x6BEbC4925716945D46F0Ec336D5C2564F419682C);
        } else if (name == keccak256("arbitrum_nova")) {
            INBOX = InboxLike(0xc4448b71118c9071Bcb9734A0EAc55D18A153949);
        } else {
            revert("Unsupported chain");
        }

        _hostDomain.selectFork();
        BRIDGE = BridgeLike(INBOX.bridge());
        vm.recordLogs();

        // Make this contract a valid outbox
        address _rollup = BRIDGE.rollup();
        vm.store(
            address(BRIDGE),
            bytes32(uint256(8)),
            bytes32(uint256(uint160(address(this))))
        );
        BRIDGE.setOutbox(address(this), true);
        vm.store(
            address(BRIDGE),
            bytes32(uint256(8)),
            bytes32(uint256(uint160(_rollup)))
        );

        // Need to replace ArbSys contract with custom code to make it compatible with revm
        selectFork();
        bytes memory bytecode = vm.getCode("ArbitrumDomain.sol:ArbSysOverride");
        address deployed;
        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        vm.etch(ARB_SYS, deployed.code);

        _hostDomain.selectFork();
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

    function relayFromHost(bool switchToGuest) external override {
        selectFork();

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
            if (log.topics[0] == SEND_TO_L1_TOPIC) {
                (address sender, address target, bytes memory message) = abi.decode(log.data, (address, address, bytes));
                l2ToL1Sender = sender;
                (bool success, bytes memory response) = BRIDGE.executeCall(target, 0, message);
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
