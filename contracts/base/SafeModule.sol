// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Enum} from "@safe-global/safe-contracts/contracts/common/Enum.sol";

import {ISafe} from "../interfaces/ISafe.sol";

abstract contract SafeModule {
    address public safeAccount;

    constructor(address _safeAccount) {
        safeAccount = _safeAccount;
    }

    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) internal returns (bool success) {
        return
            ISafe(safeAccount).execTransactionFromModule(
                to,
                value,
                data,
                operation
            );
    }

    function execTransactionFromModuleReturnData(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) internal returns (bool success, bytes memory returnData) {
        return
            ISafe(safeAccount).execTransactionFromModuleReturnData(
                to,
                value,
                data,
                operation
            );
    }
}
