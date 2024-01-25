// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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

    modifier checkStewardIndex(uint256 index) {
        require(index < getStewardsLength(), "Index out of bounds");
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

    function getSteward(
        address address_
    )
        public
        view
        returns (StewardStatus status, uint256 stewardExpireTimestamp)
    {
        status = getStewardStatus(address_);
        if (status == StewardStatus.NotExist) {
            return (status, 0);
        }
        return (status, _stewards.get(address_));
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
        checkStewardIndex(index)
        returns (address address_, uint256 expireTimestamp)
    {
        return _stewards.at(index);
    }

    // function _checkAddress(address address_) internal view {
    //     require(address_ != address(0), "Cannot target zero address");
    //     require(address_ != address(this), "Cannot target self");
    // }

    function _removeExpiredStewards() internal {
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
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    enum StewardAction {
        Set,
        Remove
    }

    event StewardProposalCreated(
        uint256 proposalId,
        StewardAction action,
        address targetAddress,
        uint256 newExpireTimestamp,
        uint256 votingEndTimestamp,
        address[] voters
    );

    struct StewardProposal {
        StewardAction action;
        address targetAddress;
        uint256 newExpireTimestamp;
        uint256 votingEndTimestamp;
        address[] voters;
        Vote[] votes;
        bool executed;
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
        // require(targetAddress != address(0), "Cannot target zero address");
        // require(targetAddress != address(this), "Cannot target self");
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

    constructor(
        address[] memory stewardAddresses,
        uint256[] memory stewardExpireTimestamps,
        uint256 proposalVoteDuration_
    ) StewardManager(stewardAddresses, stewardExpireTimestamps) {
        // for (uint256 i = 0; i < stewardAddresses.length; i++) {
        //     require(stewardAddresses[i] != address(0), "Cannot target zero address");
        //     require(stewardAddresses[i] != address(this), "Cannot target self");
        // }
        proposalVoteDuration = proposalVoteDuration_;
    }

    function getStewardProposalsLength() public view returns (uint256 length) {
        return _stewardProposals.length;
    }

    function getStewardProposalById(
        uint256 proposalId
    )
        public
        view
        returns (
            StewardAction action,
            address targetAddress,
            uint256 newExpireTimestamp,
            uint256 votingEndTimestamp,
            address[] memory voters,
            Vote[] memory votes,
            bool executed
        )
    {
        _checkStewardProposeIndex(proposalId);
        return (
            _stewardProposals[proposalId].action,
            _stewardProposals[proposalId].targetAddress,
            _stewardProposals[proposalId].newExpireTimestamp,
            _stewardProposals[proposalId].votingEndTimestamp,
            _stewardProposals[proposalId].voters,
            _stewardProposals[proposalId].votes,
            _stewardProposals[proposalId].executed
        );
    }

    function proposeSteward(
        StewardAction action,
        address targetAddress,
        uint256 newExpireTimestamp
    )
        external
        onlySteward
        checkStewardPropose(action, targetAddress, newExpireTimestamp)
        returns (uint256 proposalId)
    {
        (bool voteDurationNotOverflow, uint256 votingEndTimestamp_) = Math
            .tryAdd(block.timestamp, proposalVoteDuration);
        require(voteDurationNotOverflow, "Vote duration overflow");

        StewardProposal memory proposal = StewardProposal({
            action: action,
            targetAddress: targetAddress,
            newExpireTimestamp: newExpireTimestamp,
            votingEndTimestamp: votingEndTimestamp_,
            voters: new address[](0),
            votes: new Vote[](0),
            executed: false
        });

        _stewardProposals.push(proposal);
        proposalId = _stewardProposals.length - 1;
        _checkStewardProposeIndex(proposalId);

        address[] memory unscreenedVoters = getStewards();
        for (uint256 i = 0; i < unscreenedVoters.length; i++) {
            if (getStewardStatus(unscreenedVoters[i]) == StewardStatus.Valid) {
                _stewardProposals[proposalId].voters.push(unscreenedVoters[i]);
                _stewardProposals[proposalId].votes.push(Vote.Abstain);
            }
        }
        require(
            _stewardProposals[proposalId].voters.length > 0,
            "No valid stewards"
        );

        _checkStewardProposalVotersAndVotesLength(proposalId);

        // DEBUG
        // for (
        //     uint256 i = 0;
        //     i < _stewardProposals[proposalId].voters.length;
        //     i++
        // ) {
        //     if (_stewardProposals[proposalId].voters[i] == msg.sender)
        //         _stewardProposals[proposalId].votes[i] = Vote.Approve;
        // }

        emit StewardProposalCreated(
            proposalId,
            _stewardProposals[proposalId].action,
            _stewardProposals[proposalId].targetAddress,
            _stewardProposals[proposalId].newExpireTimestamp,
            _stewardProposals[proposalId].votingEndTimestamp,
            _stewardProposals[proposalId].voters
        );
    }

    function voteOnStewardProposal(uint256 proposalId, Vote vote) external {
        _checkStewardProposeIndex(proposalId);
        _checkStewardProposalVotersAndVotesLength(proposalId);

        require(
            vote == Vote.Approve || vote == Vote.Reject,
            "Invalid vote, must be approve or reject"
        );

        StewardProposal storage proposal = _stewardProposals[proposalId];
        require(
            proposal.votingEndTimestamp > block.timestamp,
            "Voting has ended"
        );

        bool isVoter = false;
        uint256 voterIndex = 0;
        for (uint256 i = 0; i < proposal.voters.length; i++) {
            if (proposal.voters[i] != msg.sender) continue;
            isVoter = true;
            voterIndex = i;
            break;
        }
        require(isVoter, "Not a valid voter");
        require(proposal.votes[voterIndex] == Vote.Abstain, "Already voted");

        proposal.votes[voterIndex] = vote;
    }

    function executeStewardProposal(uint256 proposalId) external {
        _checkStewardProposeIndex(proposalId);
        _checkStewardProposalVotersAndVotesLength(proposalId);

        StewardProposal storage proposal = _stewardProposals[proposalId];

        require(
            proposal.votingEndTimestamp <= block.timestamp,
            "Voting has not ended"
        );
        require(!proposal.executed, "Already executed");

        uint256 approveVotes = 0;
        for (uint256 i = 0; i < proposal.votes.length; i++) {
            if (proposal.votes[i] == Vote.Approve) {
                approveVotes++;
            }
        }

        require(
            MathUtils.isWithinPercentage(
                approveVotes,
                proposal.voters.length,
                66
            ),
            "Not enough votes"
        );

        // mark as executed before calls to avoid reentrancy
        proposal.executed = true;

        if (proposal.action == StewardAction.Set) {
            _setSteward(proposal.targetAddress, proposal.newExpireTimestamp);
        } else if (proposal.action == StewardAction.Remove) {
            _removeSteward(proposal.targetAddress);
        }
    }

    function _checkStewardProposeIndex(uint256 index) internal view {
        require(index < getStewardProposalsLength(), "Index out of bounds");
    }

    function _checkStewardProposalVotersAndVotesLength(
        uint256 proposalId
    ) internal view {
        require(
            _stewardProposals[proposalId].voters.length ==
                _stewardProposals[proposalId].votes.length,
            "Voters and Votes length mismatch"
        );
    }

    function _setStewardVoteDuration(uint256 duration) internal {
        proposalVoteDuration = duration;
    }
}

contract StewardSystem is StewardProposalVoting, Ownable {
    constructor(
        address[] memory stewardAddresses,
        uint256[] memory stewardExpireTimestamps,
        uint256 proposalVoteDuration_,
        address owner
    )
        StewardProposalVoting(
            stewardAddresses,
            stewardExpireTimestamps,
            proposalVoteDuration_
        )
        Ownable(owner)
    {}

    function removeExpiredStewards() external onlyOwner {
        _removeExpiredStewards();
    }

    function setSteward(
        address address_,
        uint256 expireTimestamp
    ) external onlyOwner returns (bool isNewEntry) {
        return _setSteward(address_, expireTimestamp);
    }

    function removeSteward(
        address address_
    ) external onlyOwner returns (bool success) {
        require(
            getStewardStatus(address_) != StewardStatus.NotExist,
            "Steward does not exist"
        );
        return _removeSteward(address_);
    }

    function setStewardVoteDuration(uint256 duration) external onlyOwner {
        _setStewardVoteDuration(duration);
    }

    // function execute(
    //     address target,
    //     bytes memory data
    // ) external onlyOwner {
    //     (bool success, bytes memory returnData) = target.call(data);
    //     require(success, string(returnData));
    // }
}
