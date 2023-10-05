// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface ICrossDomainOptimism {
    function sendMessage(address _target, bytes calldata _message, uint32 _gasLimit) external;
}

interface ICrossDomainArbitrum {
    function createRetryableTicket(
        address to,
        uint256 l2CallValue,
        uint256 maxSubmissionCost,
        address excessFeeRefundAddress,
        address callValueRefundAddress,
        uint256 gasLimit,
        uint256 maxFeePerGas,
        bytes calldata data
    ) external payable returns (uint256);
    function calculateRetryableSubmissionFee(uint256 dataLength, uint256 baseFee) external view returns (uint256);
}

interface ICrossDomainGnosisChain {
    function requireToPassMessage(address _contract, bytes memory _data, uint256 _gas) external returns (bytes32);
}

/**
 * @title XChainForwarders
 * @notice Helper functions to abstract over L1 -> L2 message passing.
 * @dev General structure is sendMessageXXX(target, message, gasLimit) where XXX is the remote domain name (IE Optimism, Arbitrum, Base, etc).
 */
library XChainForwarders {

    /// ================================ Optimism Style ================================

    function sendMessageOptimism(
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

    function sendMessageOptimism(
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        sendMessageOptimism(
            0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1,
            target,
            message,
            uint32(gasLimit)
        );
    }

    function sendMessageOptimismGoerli(
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        sendMessageOptimism(
            0x5086d1eEF304eb5284A0f6720f79403b4e9bE294,
            target,
            message,
            uint32(gasLimit)
        );
    }

    function sendMessageBase(
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        sendMessageOptimism(
            0x866E82a600A1414e583f7F13623F1aC5d58b0Afa,
            target,
            message,
            uint32(gasLimit)
        );
    }

    function sendMessageBaseGoerli(
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        sendMessageOptimism(
            0x8e5693140eA606bcEB98761d9beB1BC87383706D,
            target,
            message,
            uint32(gasLimit)
        );
    }

    /// ================================ Arbitrum Style ================================

    function sendMessageArbitrum(
        address l1CrossDomain,
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        // These constants are reasonable estimates based on current market conditions
        // They can be updated as needed
        uint256 maxFeePerGas = 1 gwei;
        uint256 baseFeeMargin = 10 gwei;

        uint256 maxSubmission = ICrossDomainArbitrum(l1CrossDomain).calculateRetryableSubmissionFee(message.length, block.basefee + baseFeeMargin);
        uint256 maxRedemption = gasLimit * maxFeePerGas;
        ICrossDomainArbitrum(l1CrossDomain).createRetryableTicket{value: maxSubmission + maxRedemption}(
            target,
            0, // we always assume that l2CallValue = 0
            maxSubmission,
            address(0), // burn the excess gas
            address(0), // burn the excess gas
            gasLimit,
            maxFeePerGas,
            message
        );
    }

    function sendMessageArbitrumOne(
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        sendMessageArbitrum(
            0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f,
            target,
            message,
            gasLimit
        );
    }

    function sendMessageArbitrumOneGoerli(
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        sendMessageArbitrum(
            0x6BEbC4925716945D46F0Ec336D5C2564F419682C,
            target,
            message,
            gasLimit
        );
    }

    function sendMessageArbitrumNova(
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        sendMessageArbitrum(
            0xc4448b71118c9071Bcb9734A0EAc55D18A153949,
            target,
            message,
            gasLimit
        );
    }

    /// ================================ Gnosis Chain ================================

    function sendMessageGnosisChain(
        address l1CrossDomain,
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        ICrossDomainGnosisChain(l1CrossDomain).requireToPassMessage(
            target,
            message,
            gasLimit
        );
    }

    function sendMessageGnosisChain(
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        sendMessageGnosisChain(
            0x4C36d2919e407f0Cc2Ee3c993ccF8ac26d9CE64e,
            target,
            message,
            gasLimit
        );
    }
    
    function sendMessageGnosisChainGoerli(
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        sendMessageGnosisChain(
            0x87A19d769D875964E9Cd41dDBfc397B2543764E6,
            target,
            message,
            gasLimit
        );
    }

}
