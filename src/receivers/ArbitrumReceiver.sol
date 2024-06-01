// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title  ArbitrumReceiver
 * @notice Receive messages to an Arbitrum-style chain.
 */
contract ArbitrumReceiver {

    address public immutable l1Authority;
    address public immutable target;

    constructor(
        address _l1Authority,
        address _target
    ) {
        l1Authority = _l1Authority;
        target      = _target;
    }

    function _getL1MessageSender() internal view returns (address) {
        unchecked {
            return address(uint160(msg.sender) - uint160(0x1111000000000000000000000000000000001111));
        }
    }

    function forward(bytes memory message) external {
        require(_getL1MessageSender() == l1Authority, "ArbitrumReceiver/invalid-l1Authority");

        (bool success, bytes memory ret) = target.call(message);
        if (!success) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
    }

}
