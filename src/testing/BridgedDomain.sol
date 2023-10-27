// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { Domain } from "./Domain.sol";

abstract contract BridgedDomain is Domain {

    Domain public immutable hostDomain;

    constructor(Domain _hostDomain) {
        hostDomain = _hostDomain;
    }

    function relayFromHost(bool switchToGuest) external virtual;
    function relayToHost(bool switchToHost) external virtual;
}
