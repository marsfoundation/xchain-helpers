// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

contract TargetContractMock {

    uint256 public data;

    function someFunc() external {
        data++;
    }

    function revertFunc() external pure {
        revert("error");
    }
    
}
