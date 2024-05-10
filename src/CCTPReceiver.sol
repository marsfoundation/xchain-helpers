// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title CCTPReceiver
 * @notice Receive messages from CCTP-style bridge.
 */
abstract contract CCTPReceiver {

    address public immutable l2CrossDomain;
    uint32 public immutable  sourceDomain;
    address public immutable l1Authority;

    constructor(
        address _l2CrossDomain,
        uint32  _sourceDomain,
        address _l1Authority
    ) {
        l2CrossDomain = _l2CrossDomain;
        sourceDomain  = _sourceDomain;
        l1Authority   = _l1Authority;
    }

    function _getL1MessageSender() internal view returns (address) {
        return l1Authority;
    }

    function _onlyCrossChainMessage() internal view {
        require(msg.sender == address(this), "Receiver/invalid-sender");
    }

    modifier onlyCrossChainMessage() {
        _onlyCrossChainMessage();
        _;
    }

    function handleReceiveMessage(
        uint32 _sourceDomain,
        bytes32 sender,
        bytes calldata messageBody
    ) external returns (bool) {
        require(msg.sender == l2CrossDomain,                      "Receiver/invalid-sender");
        require(_sourceDomain == sourceDomain,                    "Receiver/invalid-sourceDomain");
        require(sender == bytes32(uint256(uint160(l1Authority))), "Receiver/invalid-l1Authority");

        (bool success, bytes memory ret) = address(this).call(messageBody);
        if (!success) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }

        return true;
    }

}
