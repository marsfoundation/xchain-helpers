// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { Vm } from "forge-std/Vm.sol";

library RecordedLogs {

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function getLogs() internal returns (Vm.Log[] memory) {
        string memory _logs = vm.serializeUint("RECORDED_LOGS", "a", 0); // this is the only way to get the logs from the memory object
        uint256 count = keccak256(bytes(_logs)) == keccak256('{"a":0}') ? 0 : abi.decode(vm.parseJson(_logs, ".count"), (uint256));

        Vm.Log[] memory newLogs = vm.getRecordedLogs();
        Vm.Log[] memory logs = new Vm.Log[](count + newLogs.length);
        for (uint256 i = 0; i < count; i++) {
            bytes memory data = vm.parseJson(_logs, string(abi.encodePacked(".", vm.toString(i), "_", "data")));
            logs[i].data = data.length > 32 ? abi.decode(data, (bytes)) : data;
            logs[i].topics  = abi.decode(vm.parseJson(_logs, string(abi.encodePacked(".", vm.toString(i), "_", "topics"))), (bytes32[]));
            logs[i].emitter = abi.decode(vm.parseJson(_logs, string(abi.encodePacked(".", vm.toString(i), "_", "emitter"))), (address));
        }

        for (uint256 i = 0; i < newLogs.length; i++) {
            vm.serializeBytes("RECORDED_LOGS", string(abi.encodePacked(vm.toString(count), "_", "data")), logs[count].data = newLogs[i].data);
            vm.serializeBytes32("RECORDED_LOGS", string(abi.encodePacked(vm.toString(count), "_", "topics")), logs[count].topics = newLogs[i].topics);
            vm.serializeAddress("RECORDED_LOGS", string(abi.encodePacked(vm.toString(count), "_", "emitter")), logs[count].emitter = newLogs[i].emitter);
            count++;
        }
        vm.serializeUint("RECORDED_LOGS", "count", count);

        return logs;
    }

}
