// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Enum} from "@safe-global/safe-contracts/contracts/common/Enum.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {SafeModule} from "../base/SafeModule.sol";
import {ISafeGovernance} from "../interfaces/ISafeGovernance.sol";
import "../utils/MathUtils.sol";

contract StewardModule is SafeModule {
    enum StewardAction {
        Add,
        Remove,
        Modify
    }

    struct StewardActionProposal {
        StewardAction action;
        address stewardAddress;
        uint256 newExpireTimestamp;
    }

    using EnumerableMap for EnumerableMap.AddressToUintMap;

    // Steward address => Steward expire timestamp (After this timestamp, this steward no longer has access and waiting to be removed.)
    EnumerableMap.AddressToUintMap private _stewards;

    StewardActionProposal[] private _stewardActionProposals;

    modifier onlySteward() {
        require(isStewardAddress(msg.sender), "Not a steward");
        _;
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "Not self");
        _;
    }

    constructor(
        address safeAccount_,
        address[] memory stewardAddresses,
        uint256[] memory stewardExpireTimestamps
    ) SafeModule(safeAccount_) {
        for (uint256 i = 0; i < stewardAddresses.length; i++) {
            require(
                _stewards.set(stewardAddresses[i], stewardExpireTimestamps[i]),
                "Duplicate address"
            );
        }
    }

    /**
     * @dev Check if the address is a steward and the stewardship has not expired.
     * @param address_ Address to check.
     * @return isSteward Boolean flag indicating if the address is a steward and the stewardship has not expired.
     */
    function isStewardAddress(
        address address_
    ) public view returns (bool isSteward) {
        return
            _stewards.contains(address_) &&
            _stewards.get(address_) > block.timestamp;
    }

    function getStewardsLength() public view returns (uint256 length) {
        return _stewards.length();
    }

    function getStewards() public view returns (address[] memory addresses) {
        return _stewards.keys();
    }

    // TODO
    // function execute(
    //     address to,
    //     uint value
    // ) external onlySteward returns (bool success) {
    //     return true;
    // }

    function send(
        address to,
        uint256 value
    ) external onlySteward returns (bool success) {
        return execTransactionFromModule(to, value, "0x", Enum.Operation.Call);
    }
}
