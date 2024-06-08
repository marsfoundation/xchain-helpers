// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { Vm }        from "forge-std/Vm.sol";

import { Bridge }                from "../Bridge.sol";
import { Domain, DomainHelpers } from "../Domain.sol";
import { RecordedLogs }          from "../utils/RecordedLogs.sol";

interface IMessenger {
    function receiveMessage(bytes calldata message, bytes calldata attestation) external returns (bool success);
}

library CCTPBridgeTesting {

    bytes32 private constant SENT_MESSAGE_TOPIC = keccak256("MessageSent(bytes)");

    using DomainHelpers for *;
    using RecordedLogs  for *;

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    
    function createCircleBridge(Domain memory source, Domain memory destination) internal returns (Bridge memory bridge) {
        return init(Bridge({
            source:                         source,
            destination:                    destination,
            sourceCrossChainMessenger:      getCircleMessengerFromChainAlias(source.chain.chainAlias),
            destinationCrossChainMessenger: getCircleMessengerFromChainAlias(destination.chain.chainAlias),
            lastSourceLogIndex:             0,
            lastDestinationLogIndex:        0,
            extraData:                      ""
        }));
    }

    function getCircleMessengerFromChainAlias(string memory chainAlias) internal pure returns (address) {
        bytes32 name = keccak256(bytes(chainAlias));
        if (name == keccak256("mainnet")) {
            return 0x0a992d191DEeC32aFe36203Ad87D7d289a738F81;
        } else if (name == keccak256("avalanche")) {
            return 0x8186359aF5F57FbB40c6b14A588d2A59C0C29880;
        } else if (name == keccak256("optimism")) {
            return 0x4D41f22c5a0e5c74090899E5a8Fb597a8842b3e8;
        } else if (name == keccak256("arbitrum_one")) {
            return 0xC30362313FBBA5cf9163F0bb16a0e01f01A896ca;
        } else if (name == keccak256("base")) {
            return 0xAD09780d193884d503182aD4588450C416D6F9D4;
        } else if (name == keccak256("polygon")) {
            return 0xF3be9355363857F3e001be68856A2f96b4C39Ba9;
        } else {
            revert("Unsupported chain");
        }
    }

    function init(Bridge memory bridge) internal returns (Bridge memory) {
         // Set minimum required signatures to zero for both domains
        bridge.destination.selectFork();
        vm.store(
            bridge.destinationCrossChainMessenger,
            bytes32(uint256(4)),
            0
        );
        bridge.source.selectFork();
        vm.store(
            bridge.sourceCrossChainMessenger,
            bytes32(uint256(4)),
            0
        );

        vm.recordLogs();

        return bridge;
    }

    function relayMessagesToDestination(Bridge memory bridge, bool switchToDestinationFork) internal {
        bridge.destination.selectFork();

        Vm.Log[] memory logs = bridge.ingestAndFilterLogs(true, SENT_MESSAGE_TOPIC, bridge.sourceCrossChainMessenger);
        for (uint256 i = 0; i < logs.length; i++) {
            IMessenger(bridge.destinationCrossChainMessenger).receiveMessage(abi.decode(logs[i].data, (bytes)), "");
        }

        if (!switchToDestinationFork) {
            bridge.source.selectFork();
        }
    }

    function relayMessagesToSource(Bridge memory bridge, bool switchToSourceFork) internal {
        bridge.source.selectFork();
        
        Vm.Log[] memory logs = bridge.ingestAndFilterLogs(false, SENT_MESSAGE_TOPIC, bridge.destinationCrossChainMessenger);
        for (uint256 i = 0; i < logs.length; i++) {
            IMessenger(bridge.sourceCrossChainMessenger).receiveMessage(abi.decode(logs[i].data, (bytes)), "");
        }

        if (!switchToSourceFork) {
            bridge.destination.selectFork();
        }
    }

}
