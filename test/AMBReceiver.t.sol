// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import { AMBReceiver } from "src/receivers/AMBReceiver.sol";

contract AMBMock {

    bytes32 public messageSourceChainId;
    address public messageSender;

    constructor(bytes32 _messageSourceChainId, address _messageSender) {
        messageSourceChainId = _messageSourceChainId;
        messageSender = _messageSender;
    }

    function __setSourceChainId(bytes32 _messageSourceChainId) public {
        messageSourceChainId = _messageSourceChainId;
    }

    function __setSender(address _messageSender) public {
        messageSender = _messageSender;
    }

}

contract TargetContractMock {

    uint256 public s;

    function someFunc() external {
        s++;
    }

    function revertFunc() external pure {
        revert("error");
    }
    
}

contract AMBReceiverTest is Test {

    AMBMock            amb;
    TargetContractMock target;

    AMBReceiver receiver;

    bytes32 sourceChainId   = bytes32(uint256(1));
    address sourceAuthority = makeAddr("sourceAuthority");
    address randomAddress   = makeAddr("randomAddress");

    function setUp() public {
        amb    = new AMBMock(sourceChainId, sourceAuthority);
        target = new TargetContractMock();

        receiver = new AMBReceiver(
            address(amb),
            sourceChainId,
            sourceAuthority,
            address(target)
        );
    }

    function test_constructor() public {
        receiver = new AMBReceiver(
            address(amb),
            sourceChainId,
            sourceAuthority,
            address(target)
        );

        assertEq(receiver.amb(),             address(amb));
        assertEq(receiver.sourceChainId(),   sourceChainId);
        assertEq(receiver.sourceAuthority(), sourceAuthority);
        assertEq(receiver.target(),          address(target));
    }

    function test_forward_invalidSender() public {
        vm.prank(randomAddress);
        vm.expectRevert("AMBReceiver/invalid-sender");
        receiver.forward(abi.encodeCall(TargetContractMock.someFunc, ()));
    }

    function test_forward_invalidSourceChainId() public {
        amb.__setSourceChainId(bytes32(uint256(2)));

        vm.prank(address(amb));
        vm.expectRevert("AMBReceiver/invalid-sourceChainId");
        receiver.forward(abi.encodeCall(TargetContractMock.someFunc, ()));
    }

    function test_forward_invalidSourceAuthority() public {
        amb.__setSender(randomAddress);

        vm.prank(address(amb));
        vm.expectRevert("AMBReceiver/invalid-sourceAuthority");
        receiver.forward(abi.encodeCall(TargetContractMock.someFunc, ()));
    }

    function test_forward_success() public {
        vm.prank(address(amb));
        receiver.forward(abi.encodeCall(TargetContractMock.someFunc, ()));
        assertEq(target.s(), 1);
    }

    function test_forward_revert() public {
        vm.prank(address(amb));
        vm.expectRevert("error");
        receiver.forward(abi.encodeCall(TargetContractMock.revertFunc, ()));
    }
    
}
