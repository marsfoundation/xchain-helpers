// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { Vm }        from "forge-std/Vm.sol";

import { RecordedLogs } from "src/testing/utils/RecordedLogs.sol";
import { BridgeData }   from "./BridgeData.sol";

library ArbitrumBridgeTesting {

    using DomainHelpers for *;

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    
    function createBridge(Domain memory source, Domain memory destination) internal returns (BridgeData memory bridge) {
        return init(BridgeData({
            source:                         ethereum,
            destination:                    arbitrumInstance,
            sourceCrossChainMessenger:      _getMessengerFromChainAlias(source.chain.chainAlias),
            destinationCrossChainMessenger: _getMessengerFromChainAlias(destination.chain.chainAlias),
            lastSourceLogIndex:             0,
            lastDestinationLogIndex:        0,
            extraData:                      ""
        }));
    }

    function getMessengerFromChainAlias(string memory chainAlias) internal pure returns (address) {
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

    function init(BridgeData memory bridge) internal returns (BridgeData memory bridge) {
        
    }

    function relayMessagesToDestination(BridgeData memory bridge, bool switchToDestinationFork) internal {
        
    }

    function relayMessagesToSource(BridgeData memory bridge, bool switchToSourceFork) internal {
        
    }

}
