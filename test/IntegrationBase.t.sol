// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2021 Dai Foundation
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import { Domain } from "../src/testing/Domain.sol";
import { XChainForwarders } from "../src/XChainForwarders.sol";

abstract contract MessageOrdering {

    uint256[] public messages;

    function push(uint256 messageId) external virtual;

    function length() public view returns (uint256) {
        return messages.length;
    }

}

contract MessageOrderingNoAuth is MessageOrdering {

    function push(uint256 messageId) external override {
        messages.push(messageId);
    }

}

abstract contract IntegrationBaseTest is Test {

    Domain mainnet;
    Domain goerli;

    function setUp() public {
        mainnet = new Domain(getChain("mainnet"));
        goerli = new Domain(getChain("goerli"));
    }

}