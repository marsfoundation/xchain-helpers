// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface ICrossDomainGnosis {
    function messageSender() external view returns (address);
    function messageSourceChainId() external view returns (bytes32);
}

/**
 * @title GnosisReceiver
 * @notice Receive messages to Gnosis-style chain.
 */
abstract contract GnosisReceiver {

    ICrossDomainGnosis public immutable l2CrossDomain;
    bytes32            public immutable chainId;
    address            public immutable l1Authority;

    constructor(
        address _l2CrossDomain,
        uint256 _chainId,
        address _l1Authority
    ) {
        l2CrossDomain = ICrossDomainGnosis(_l2CrossDomain);
        chainId = bytes32(_chainId);
        l1Authority = _l1Authority;
    }

    function _getL1MessageSender() internal view returns (address) {
        return l2CrossDomain.messageSender();
    }

    function _onlyCrossChainMessage() internal view {
        require(msg.sender == address(l2CrossDomain), "auth");
        require(l2CrossDomain.messageSourceChainId() == chainId, "auth");
        require(_getL1MessageSender() == l1Authority, "auth");
    }

    modifier onlyCrossChainMessage() {
        _onlyCrossChainMessage();
        _;
    }

}
