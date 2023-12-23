// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Enum} from "@safe-global/safe-contracts/contracts/common/Enum.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {SafeModule} from "../base/SafeModule.sol";
import {ISafeGovernance} from "../interfaces/ISafeGovernance.sol";
import {Voting} from "../common/Voting.sol";
import "../utils/MathUtils.sol";

abstract contract StewardManager {
    enum StewardStatus {
        NotExist,
        Valid,
        Expired
    }

    using EnumerableMap for EnumerableMap.AddressToUintMap;

    // Steward address => Steward expire block timestamp (After this block timestamp, the steward is no longer valid)
    EnumerableMap.AddressToUintMap private _stewards;

    modifier onlySteward() {
        require(
            getStewardStatus(msg.sender) == StewardStatus.Valid,
            "Not a valid steward"
        );
        _;
    }

    modifier checkStewardIndex(uint256 index, bool onlyValid) {
        if (onlyValid) {
            require(index < getValidStewardsLength(), "Index out of bounds");
        } else {
            require(index < getStewardsLength(), "Index out of bounds");
        }
        _;
    }

    constructor(
        address[] memory stewardAddresses,
        uint256[] memory stewardExpireTimestamps
    ) {
        require(
            stewardAddresses.length == stewardExpireTimestamps.length,
            "Length mismatch"
        );
        for (uint256 i = 0; i < stewardAddresses.length; i++) {
            require(
                _stewards.set(stewardAddresses[i], stewardExpireTimestamps[i]),
                "Duplicate address"
            );
        }
    }

    function getStewardStatus(
        address address_
    ) public view returns (StewardStatus status) {
        if (!_stewards.contains(address_)) {
            return StewardStatus.NotExist;
        } else if (_stewards.get(address_) <= block.timestamp) {
            return StewardStatus.Expired;
        } else {
            return StewardStatus.Valid;
        }
    }

    function getValidStewards()
        public
        view
        returns (address[] memory addresses)
    {
        address[] memory _addresses = _stewards.keys();
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (getStewardStatus(_addresses[i]) != StewardStatus.Valid) {
                delete _addresses[i];
            }
        }
        return _addresses;
    }

    function getValidStewardsLength() public view returns (uint256 length) {
        address[] memory _addresses = getValidStewards();
        return _addresses.length;
    }

    function getValidStewardAtIndex(
        uint256 index
    )
        public
        view
        checkStewardIndex(index, true)
        returns (address address_, uint256 expireTimestamp)
    {
        address[] memory _addresses = getValidStewards();
        return (_addresses[index], _stewards.get(_addresses[index]));
    }

    function getStewards() public view returns (address[] memory addresses) {
        return _stewards.keys();
    }

    function getStewardsLength() public view returns (uint256 length) {
        return _stewards.length();
    }

    function getStewardAtIndex(
        uint256 index
    )
        public
        view
        checkStewardIndex(index, false)
        returns (address address_, uint256 expireTimestamp)
    {
        return _stewards.at(index);
    }

    function removeExpiredStewards() public onlySteward {
        address[] memory _addresses = _stewards.keys();
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (getStewardStatus(_addresses[i]) == StewardStatus.Expired) {
                assert(_stewards.remove(_addresses[i]));
            }
        }
    }

    function _setSteward(
        address address_,
        uint256 expireTimestamp
    ) internal returns (bool isNewEntry) {
        return _stewards.set(address_, expireTimestamp);
    }

    function _removeSteward(address address_) internal returns (bool success) {
        return _stewards.remove(address_);
    }
}

abstract contract StewardProposalVoting is StewardManager, Voting {
    enum StewardAction {
        Set,
        Remove
    }

    struct StewardProposal {
        StewardAction action;
        address targetAddress;
        uint256 newExpireTimestamp;
        ProposalVote[] votes;
        uint256 votingEndTimestamp;
    }

    StewardProposal[] private _stewardProposals;
    uint256 public proposalVoteDuration;

    modifier checkStewardPropose(
        StewardAction action,
        address targetAddress,
        uint256 newExpireTimestamp
    ) {
        require(
            action == StewardAction.Set || action == StewardAction.Remove,
            "Invalid action"
        );
        if (action == StewardAction.Set) {
            require(
                newExpireTimestamp > block.timestamp,
                "New expire timestamp must be in the future"
            );
        } else if (action == StewardAction.Remove) {
            require(
                getStewardStatus(targetAddress) != StewardStatus.NotExist,
                "Steward does not exist"
            );
            require(
                newExpireTimestamp == 0,
                "New expire timestamp must be zero"
            );
        }
        _;
    }

    modifier checkStewardProposeIndex(uint256 index) {
        require(index < getStewardProposalsLength(), "Index out of bounds");
        _;
    }

    constructor(
        address[] memory stewardAddresses,
        uint256[] memory stewardExpireTimestamps,
        uint256 proposalVoteDuration_
    ) StewardManager(stewardAddresses, stewardExpireTimestamps) {
        proposalVoteDuration = proposalVoteDuration_;
    }

    function getStewardProposals()
        public
        view
        returns (StewardProposal[] memory proposals)
    {
        return _stewardProposals;
    }

    function getStewardProposalsLength() public view returns (uint256 length) {
        return _stewardProposals.length;
    }

    function getStewardProposalAtIndex(
        uint256 index
    )
        public
        view
        checkStewardProposeIndex(index)
        returns (
            StewardAction action,
            address targetAddress,
            uint256 newExpireTimestamp,
            ProposalVote[] memory votes,
            uint256 votingEndTimestamp
        )
    {
        StewardProposal memory proposal = _stewardProposals[index];
        return (
            proposal.action,
            proposal.targetAddress,
            proposal.newExpireTimestamp,
            proposal.votes,
            proposal.votingEndTimestamp
        );
    }

    // TODO
    // function proposeSteward(
    //     StewardAction action,
    //     address targetAddress,
    //     uint256 newExpireTimestamp
    // )
    //     external
    //     onlySteward
    //     checkStewardPropose(action, targetAddress, newExpireTimestamp)
    //     returns (uint256 proposalId)
    // {
    //     StewardProposal memory proposal = StewardProposal({
    //         action: action,
    //         targetAddress: targetAddress,
    //         newExpireTimestamp: newExpireTimestamp,
    //         votes: new ProposalVote[](0), // TODO
    //         votingEndTimestamp: block.timestamp + proposalVoteDuration
    //     });
    //     _stewardProposals.push(proposal);
    //     return _stewardProposals.length - 1;
    // }

    function _setStewardVoteDuration(uint256 duration) internal {
        proposalVoteDuration = duration;
    }
}

contract StewardModule is SafeModule, StewardProposalVoting {
    constructor(
        address safeAccount_,
        address[] memory stewardAddresses,
        uint256[] memory stewardExpireTimestamps,
        uint256 initProposalVoteDuration
    )
        SafeModule(safeAccount_)
        StewardProposalVoting(
            stewardAddresses,
            stewardExpireTimestamps,
            initProposalVoteDuration
        )
    {}

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
