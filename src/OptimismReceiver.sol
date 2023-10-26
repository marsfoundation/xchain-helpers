// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface ICrossDomainOptimism {
    function xDomainMessageSender() external view returns (address);
}

/**
 * @title OptimismReceiver
 * @notice Receive messages to an Optimism-style chain.
 */
abstract contract OptimismReceiver {

    ICrossDomainOptimism public constant l2CrossDomain = ICrossDomainOptimism(0x4200000000000000000000000000000000000007);

    address public immutable l1Authority;

    constructor(
        address _l1Authority
    ) {
        l1Authority = _l1Authority;
    }

    function _getL1MessageSender() internal view returns (address) {
        return l2CrossDomain.xDomainMessageSender();
    }

    function _onlyCrossChainMessage() internal view {
        require(msg.sender == address(l2CrossDomain), "Receiver/invalid-sender");
        require(_getL1MessageSender() == l1Authority, "Receiver/invalid-l1Authority");
    }

    modifier onlyCrossChainMessage() {
        _onlyCrossChainMessage();
        _;
    }

}
