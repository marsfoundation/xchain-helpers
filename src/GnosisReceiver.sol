// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface ICrossDomain {
    function messageSender() external view returns (address);
    function messageSourceChainId() external view returns (bytes32);
}

/**
 * @title GnosisReceiver
 * @notice Receive messages to Gnosis-style chain.
 */
abstract contract GnosisReceiver {

    ICrossDomain public immutable l2CrossDomain;
    bytes32      public immutable chainId;
    address      public immutable l1Authority;

    constructor(
        address _l2CrossDomain,
        uint256 _chainId,
        address _l1Authority
    ) {
        l2CrossDomain = ICrossDomain(_l2CrossDomain);
        chainId = bytes32(_chainId);
        l1Authority = _l1Authority;
    }

    function _onlyCrossChainMessage() internal view {
        require(msg.sender == address(l2CrossDomain));
        require(l2CrossDomain.messageSourceChainId() == chainId);
        require(l2CrossDomain.messageSender() == l1Authority);
    }

    modifier onlyCrossChainMessage() {
        _onlyCrossChainMessage();
        _;
    }

}
