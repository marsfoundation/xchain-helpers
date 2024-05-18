// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { IUnidirectionalBridge } from "./IUnidirectionalBridge.sol";

interface IUnidirectionalBridge is IUnidirectionalBridge {
    function relayMessagesToSource(bool switchToSourceFork) external;
}
