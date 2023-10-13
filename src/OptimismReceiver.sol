// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface ICrossDomain {
    function xDomainMessageSender() external view returns (address);
}

/**
 * @title OptimismReceiver
 * @notice Receive messages to an Optimism-style chain.
 */
abstract contract OptimismReceiver {

    ICrossDomain public constant l2CrossDomain = ICrossDomain(0x4200000000000000000000000000000000000007);

    address public immutable l1Authority;

    constructor(
        address _l1Authority
    ) {
        l1Authority = _l1Authority;
    }

    function _onlyCrossChainMessage() internal view {
        require(msg.sender == address(l2CrossDomain));
        require(l2CrossDomain.xDomainMessageSender() == l1Authority);
    }

    modifier onlyCrossChainMessage() {
        _onlyCrossChainMessage();
        _;
    }

}
