// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { StdChains } from "forge-std/StdChains.sol";
import { Vm }        from "forge-std/Vm.sol";

struct Domain {
    StdChains.Chain chain;
    uint256         forkId;
}

library DomainHelpers {

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function createFork(StdChains.Chain memory chain, uint256 blockNumber) internal returns (Domain memory domain) {
        domain = Domain({
            chain:  chain,
            forkId: vm.createFork(chain.rpcUrl, blockNum)
        });
    }

    function createFork(StdChains.Chain memory chain) internal returns (Domain memory domain) {
        domain = Domain({
            chain:  chain,
            forkId: vm.createFork(chain.rpcUrl)
        });
    }

    function createSelectFork(StdChains.Chain memory chain, uint256 blockNumber) internal returns (Domain memory domain) {
        domain = Domain({
            chain:  chain,
            forkId: vm.createSelectFork(chain.rpcUrl, blockNum)
        });
        _assertExpectedRpc(chain);
    }

    function createSelectFork(StdChains.Chain memory chain) internal returns (Domain memory domain) {
        domain = Domain({
            chain:  chain,
            forkId: vm.createSelectFork(chain.rpcUrl)
        });
        _assertExpectedRpc(chain);
    }

    function selectFork(Domain memory domain) internal {
        vm.selectFork(domain.forkId);
        _assertExpectedRpc(domain);
    }

    function rollFork(Domain memory domain, uint256 blockNumber) internal {
        vm.rollFork(domain.forkId, blockNumber);
    }

    function _assertExpectedRpc(StdChains.Chain memory chain) private {
        require(block.chainid == chain.chainId, string(abi.encodePacked(chain.chainAlias, " is pointing to the wrong RPC endpoint '", chain.rpcUrl, "'")));
    }

}
