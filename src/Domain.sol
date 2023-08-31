// SPDX-FileCopyrightText: © 2022 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
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

import { StdChains } from "forge-std/StdChains.sol";
import { Vm } from "forge-std/Vm.sol";

contract Domain {

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    StdChains.Chain private _details;
    uint256 public forkId;

    constructor(StdChains.Chain memory _chain) {
        _details = _chain;
        forkId = vm.createFork(_chain.rpcUrl);
        vm.makePersistent(address(this));
    }

    function details() public view returns (StdChains.Chain memory) {
        return _details;
    }
    
    function selectFork() public {
        vm.selectFork(forkId);
        require(block.chainid == _details.chainId, string(abi.encodePacked(_details.chainAlias, " is pointing to the wrong RPC endpoint '", _details.rpcUrl, "'")));
    }
    
    function rollFork(uint256 blocknum) public {
        vm.rollFork(forkId, blocknum);
    }

}
