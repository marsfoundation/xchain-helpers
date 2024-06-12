// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface IArbitraryMessagingBridge {
    function requireToPassMessage(address _contract, bytes memory _data, uint256 _gas) external returns (bytes32);
}

library AMBForwarder {

    address constant internal GNOSIS_AMB_ETHEREUM     = 0x4C36d2919e407f0Cc2Ee3c993ccF8ac26d9CE64e;
    address constant internal GNOSIS_AMB_GNOSIS_CHAIN = 0x75Df5AF045d91108662D8080fD1FEFAd6aA0bb59;

    function sendMessage(
        address amb,
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        IArbitraryMessagingBridge(amb).requireToPassMessage(
            target,
            message,
            gasLimit
        );
    }

    function sendMessageEthereumToGnosisChain(
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        sendMessage(
            GNOSIS_AMB_ETHEREUM,
            target,
            message,
            gasLimit
        );
    }

    function sendMessageGnosisChainToEthereum(
        address target,
        bytes memory message,
        uint256 gasLimit
    ) internal {
        sendMessage(
            GNOSIS_AMB_GNOSIS_CHAIN,
            target,
            message,
            gasLimit
        );
    }
    
}
