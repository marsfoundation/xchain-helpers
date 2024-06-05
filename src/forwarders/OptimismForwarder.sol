// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface ICrossDomainOptimism {
    function sendMessage(address _target, bytes calldata _message, uint32 _gasLimit) external;
}

library OptimismForwarder {

    address constant internal L1_CROSS_DOMAIN_OPTIMISM = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;
    address constant internal L1_CROSS_DOMAIN_BASE     = 0x866E82a600A1414e583f7F13623F1aC5d58b0Afa;
    address constant internal L2_CROSS_DOMAIN          = 0x4200000000000000000000000000000000000007;

    function sendMessageL1toL2(
        address l1CrossDomain,
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        ICrossDomainOptimism(l1CrossDomain).sendMessage(
            target,
            message,
            uint32(gasLimit)
        );
    }

    function sendMessageL2toL1(
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        ICrossDomainOptimism(L2_CROSS_DOMAIN).sendMessage(
            target,
            message,
            uint32(gasLimit)
        );
    }
    
}
