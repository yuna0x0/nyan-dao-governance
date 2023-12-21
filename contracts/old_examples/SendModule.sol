// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Enum} from "@safe-global/safe-contracts/contracts/common/Enum.sol";

import {SafeModule} from "../base/SafeModule.sol";
import {ISafeGovernance} from "../interfaces/ISafeGovernance.sol";

contract SendModule is SafeModule {
    address public safeGovernance;

    constructor(
        address safeAccount,
        address _safeGovernance
    ) SafeModule(safeAccount) {
        safeGovernance = _safeGovernance;
    }

    modifier onlyGovernanceOwner() {
        require(
            msg.sender == ISafeGovernance(safeGovernance).owner(),
            "Not SafeGovernance owner"
        );
        _;
    }

    function send(
        address to,
        uint256 value
    ) external onlyGovernanceOwner returns (bool success) {
        return execTransactionFromModule(to, value, "0x", Enum.Operation.Call);
    }
}
