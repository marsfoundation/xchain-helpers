// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { BridgeData } from "./BridgeData.sol";

library Arbitrum {
    
    function createArbitrumNativeBridge(Domain memory ethereum, Domain memory arbitrumInstance) internal returns (ArbitrumNativeBridge memory bridge) {
        require(keccak256(bytes(ethereum.chain.chainAlias)) == keccak256("mainnet"), "Source must be Ethereum.");

        bytes32 name = keccak256(bytes(arbitrumInstance.chain.chainAlias));
        address inbox;
        if (name == keccak256("arbitrum_one")) {
            inbox = 0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f;
        } else if (name == keccak256("arbitrum_nova")) {
            inbox = 0xc4448b71118c9071Bcb9734A0EAc55D18A153949;
        } else {
            revert("Unsupported destination chain");
        }

        return new ArbitrumNativeBridge(BridgeData({
            source:                         ethereum,
            destination:                    arbitrumInstance,
            sourceCrossChainMessenger:      inbox,
            destinationCrossChainMessenger: 0x0000000000000000000000000000000000000064,
            lastSourceLogIndex:             0,
            lastDestinationLogIndex:        0
        }));
    }

}
