// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Enum} from "@safe-global/safe-contracts/contracts/common/Enum.sol";

import {SafeModule} from "./base/SafeModule.sol";
import {ISafeGovernance} from "./interfaces/ISafeGovernance.sol";

interface IFeeToSetter {
    function setOwner(address owner_) external;

    function setFeeToSetter(address feeToSetter_) external;

    function toggleFees(bool on) external;
}

interface IFeeTo {
    function setOwner(address owner_) external;

    function setFeeRecipient(address feeRecipient_) external;
}

contract UniswapV2Manager is SafeModule {
    address public safeGovernance;

    address public feeToSetter;
    address public feeTo;

    constructor(
        address safeAccount,
        address _safeGovernance,
        address _feeToSetter,
        address _feeTo
    ) SafeModule(safeAccount) {
        safeGovernance = _safeGovernance;
        feeToSetter = _feeToSetter;
        feeTo = _feeTo;
    }

    modifier onlyGovernanceOwner() {
        require(
            msg.sender == ISafeGovernance(safeGovernance).owner(),
            "Not SafeGovernance owner"
        );
        _;
    }

    function setFeeToSetterOwner(
        address owner_
    ) external onlyGovernanceOwner returns (bool success) {
        return
            execTransactionFromModule(
                feeToSetter,
                0,
                abi.encodeCall(IFeeToSetter.setOwner, (owner_)),
                Enum.Operation.Call
            );
    }

    function setFeeToSetter(
        address feeToSetter_
    ) external onlyGovernanceOwner returns (bool success) {
        return
            execTransactionFromModule(
                feeToSetter,
                0,
                abi.encodeCall(IFeeToSetter.setFeeToSetter, (feeToSetter_)),
                Enum.Operation.Call
            );
    }

    function toggleFees(
        bool on
    ) external onlyGovernanceOwner returns (bool success) {
        return
            execTransactionFromModule(
                feeToSetter,
                0,
                abi.encodeCall(IFeeToSetter.toggleFees, (on)),
                Enum.Operation.Call
            );
    }

    function setFeeToOwner(
        address owner_
    ) external onlyGovernanceOwner returns (bool success) {
        return
            execTransactionFromModule(
                feeTo,
                0,
                abi.encodeCall(IFeeTo.setOwner, (owner_)),
                Enum.Operation.Call
            );
    }

    function setFeeRecipient(
        address feeRecipient_
    ) external onlyGovernanceOwner returns (bool success) {
        return
            execTransactionFromModule(
                feeTo,
                0,
                abi.encodeCall(IFeeTo.setFeeRecipient, (feeRecipient_)),
                Enum.Operation.Call
            );
    }
}
