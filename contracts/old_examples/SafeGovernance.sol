// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Enum} from "@safe-global/safe-contracts/contracts/common/Enum.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {SafeModule} from "../base/SafeModule.sol";

contract SafeGovernance is SafeModule, Ownable {
    constructor(
        address safeAccount,
        address initialOwner
    ) SafeModule(safeAccount) Ownable(initialOwner) {}

    function execSafeTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) external onlyOwner returns (bool success) {
        return execTransactionFromModule(to, value, data, operation);
    }

    function execSafeTransactionReturnData(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) external onlyOwner returns (bool success, bytes memory returnData) {
        return execTransactionFromModuleReturnData(to, value, data, operation);
    }
}
