// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title CCTPReceiver
 * @notice Receive messages from CCTP-style bridge.
 */
abstract contract CCTPReceiver {

    address public immutable destinationCrossDomain;
    uint32 public immutable  sourceDomainId;
    address public immutable sourceAuthority;

    constructor(
        address _destinationCrossDomain,
        uint32  _sourceDomainId,
        address _sourceAuthority
    ) {
        destinationCrossDomain = _destinationCrossDomain;
        sourceDomainId         = _sourceDomainId;
        sourceAuthority        = _sourceAuthority;
    }

    function _onlyCrossChainMessage() internal view {
        require(msg.sender == address(this), "Receiver/invalid-sender");
    }

    modifier onlyCrossChainMessage() {
        _onlyCrossChainMessage();
        _;
    }

    function handleReceiveMessage(
        uint32 sourceDomain,
        bytes32 sender,
        bytes calldata messageBody
    ) external returns (bool) {
        require(msg.sender == destinationCrossDomain,                 "Receiver/invalid-sender");
        require(sourceDomainId == sourceDomain,                       "Receiver/invalid-sourceDomain");
        require(sender == bytes32(uint256(uint160(sourceAuthority))), "Receiver/invalid-sourceAuthority");

        (bool success, bytes memory ret) = address(this).call(messageBody);
        if (!success) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }

        return true;
    }

}
