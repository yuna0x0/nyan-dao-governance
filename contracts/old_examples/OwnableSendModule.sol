// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Enum} from "@safe-global/safe-contracts/contracts/common/Enum.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {SafeModule} from "../base/SafeModule.sol";

contract OwnableSendModule is SafeModule, Ownable {
    constructor(
        address safeAccount,
        address initialOwner
    ) SafeModule(safeAccount) Ownable(initialOwner) {}

    function send(
        address to,
        uint256 value
    ) external onlyOwner returns (bool success) {
        return execTransactionFromModule(to, value, "0x", Enum.Operation.Call);
    }
}
