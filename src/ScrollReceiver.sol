// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface ICrossDomainScroll {
    function xDomainMessageSender() external view returns (address);
}

/**
 * @title ScrollReceiver
 * @notice Receive messages to an Scroll-style chain.
 */
abstract contract ScrollReceiver {

    ICrossDomainScroll public immutable l2CrossDomain;

    address public immutable l1Authority;

    constructor(
        address _l2CrossDomain,
        address _l1Authority
    ) {
        l2CrossDomain = ICrossDomainScroll(_l2CrossDomain);
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
