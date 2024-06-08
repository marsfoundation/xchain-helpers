// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import { Address } from "lib/openzeppelin-contracts/contracts/utils/Address.sol";

/**
 * @title  ArbitrumReceiver
 * @notice Receive messages to an Arbitrum-style chain.
 */
contract ArbitrumReceiver {

    using Address for address;

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

    fallback(bytes calldata message) external returns (bytes memory) {
        require(_getL1MessageSender() == l1Authority, "ArbitrumReceiver/invalid-l1Authority");

        return target.functionCall(message);
    }

}
