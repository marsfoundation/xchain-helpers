pragma solidity >=0.8.0;

import { Vm } from "forge-std/Vm.sol";
import { StdChains } from "forge-std/StdChains.sol";

import { Domain, BridgedDomain } from "./BridgedDomain.sol";
import { RecordedLogs } from "./RecordedLogs.sol";

interface IAMB {
    function requireToPassMessage(
        address _contract,
        bytes memory _data,
        uint256 _gas
    ) external returns (bytes32);
    function maxGasPerTx() external view returns (uint256);
    function executeAffirmation(bytes memory message) external;
    function validatorContract() external view returns (address);
}

interface IValidatorContract {
    function validatorList() external view returns (address[] memory);
    function requiredSignatures() external view returns (uint256);
}

contract GnosisDomain is BridgedDomain {

    bytes32 private constant USER_REQUEST_FOR_AFFIRMATION_TOPIC = keccak256("UserRequestForAffirmation(bytes32,bytes)");

    IAMB public immutable L1_AMB_CROSS_DOMAIN_MESSENGER;
    IAMB public immutable L2_AMB_CROSS_DOMAIN_MESSENGER;

    uint256 internal lastFromHostLogIndex;
    uint256 internal lastToHostLogIndex;

    constructor(StdChains.Chain memory _chain, Domain _hostDomain) Domain(_chain) BridgedDomain(_hostDomain) {
        bytes32 name = keccak256(bytes(_chain.chainAlias));
        if (name == keccak256("gnosis_chain")) {
            L1_AMB_CROSS_DOMAIN_MESSENGER = IAMB(0x4C36d2919e407f0Cc2Ee3c993ccF8ac26d9CE64e);
            L2_AMB_CROSS_DOMAIN_MESSENGER = IAMB(0x75Df5AF045d91108662D8080fD1FEFAd6aA0bb59);
        } else {
            revert("Unsupported chain");
        }

        vm.recordLogs();
    }

    function relayFromHost(bool switchToGuest) external override {
        selectFork();

        Vm.Log[] memory logs = RecordedLogs.getLogs();
        for (; lastFromHostLogIndex < logs.length; lastFromHostLogIndex++) {
            Vm.Log memory log = logs[lastFromHostLogIndex];
            if (
                log.topics[0] == USER_REQUEST_FOR_AFFIRMATION_TOPIC
                && log.emitter == address(L1_AMB_CROSS_DOMAIN_MESSENGER)
            ) {
                IValidatorContract validatorContract = IValidatorContract(L2_AMB_CROSS_DOMAIN_MESSENGER.validatorContract());
                address[] memory validators = validatorContract.validatorList();
                uint256 requiredSignatures = validatorContract.requiredSignatures();
                bytes memory messageToRelay = removeFirst64Bytes(log.data);
                for (uint256 i = 0; i < requiredSignatures; i++) {
                    vm.prank(validators[i]);
                    L2_AMB_CROSS_DOMAIN_MESSENGER.executeAffirmation(messageToRelay);
                }
            }
        }

        if (!switchToGuest) {
            hostDomain.selectFork();
        }
    }

    function relayToHost(bool switchToHost) external override {}

    function removeFirst64Bytes(bytes memory inputData) public pure returns (bytes memory) {
        bytes memory returnValue = new bytes(inputData.length - 64);
        for (uint256 i = 0; i < inputData.length - 64; i++) {
            returnValue[i] = inputData[i + 64];
        }
        return returnValue;
    }
}
