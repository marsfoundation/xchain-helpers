// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface ICrossDomain {
    function xDomainMessageSender() external view returns (address);
}

/**
 * @title ArbitrumReceiver
 * @notice Receive messages to an Arbitrum-style chain.
 */
abstract contract ArbitrumReceiver {

    address public immutable l1Authority;

    constructor(
        address _l1Authority
    ) {
        l1Authority = _l1Authority;
    }

    function _onlyCrossChainMessage() internal view {
        unchecked {
            require(address(uint160(msg.sender) - uint160(0x1111000000000000000000000000000000001111)) == l1Authority);
        }
    }

    modifier onlyCrossChainMessage() {
        _onlyCrossChainMessage();
        _;
    }

}
