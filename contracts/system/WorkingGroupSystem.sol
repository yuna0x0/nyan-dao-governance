// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Enum} from "@safe-global/safe-contracts/contracts/common/Enum.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {SafeModule} from "../base/SafeModule.sol";
import {IStewardSystem} from "../interfaces/IStewardSystem.sol";
import {Voting} from "../common/Voting.sol";
import "../utils/MathUtils.sol";

abstract contract WorkingGroupManager {
    enum WorkingGroupStatus {
        NotExist,
        Valid,
        Expired
    }

    using EnumerableMap for EnumerableMap.AddressToUintMap;

    // Working Group address => Working Group expire block timestamp (After this block timestamp, the Working Group is no longer valid)
    EnumerableMap.AddressToUintMap private _workingGroups;

    address public stewardSystem;

    modifier onlySteward() {
        require(
            IStewardSystem(stewardSystem).getStewardStatus(msg.sender) ==
                IStewardSystem.StewardStatus.Valid,
            "Not a valid steward"
        );
        _;
    }

    modifier checkWorkingGroupIndex(uint256 index) {
        require(index < getWorkingGroupsLength(), "Index out of bounds");
        _;
    }

    constructor(
        address _stewardSystem,
        address[] memory workingGroupAddresses,
        uint256[] memory workingGroupExpireTimestamps
    ) {
        stewardSystem = _stewardSystem;
        require(
            workingGroupAddresses.length == workingGroupExpireTimestamps.length,
            "Length mismatch"
        );
        for (uint256 i = 0; i < workingGroupAddresses.length; i++) {
            require(
                _workingGroups.set(
                    workingGroupAddresses[i],
                    workingGroupExpireTimestamps[i]
                ),
                "Duplicate address"
            );
        }
    }

    function getWorkingGroupStatus(
        address address_
    ) public view returns (WorkingGroupStatus status) {
        if (!_workingGroups.contains(address_)) {
            return WorkingGroupStatus.NotExist;
        } else if (_workingGroups.get(address_) <= block.timestamp) {
            return WorkingGroupStatus.Expired;
        } else {
            return WorkingGroupStatus.Valid;
        }
    }

    function getWorkingGroup(
        address address_
    )
        public
        view
        returns (WorkingGroupStatus status, uint256 workingGroupExpireTimestamp)
    {
        status = getWorkingGroupStatus(address_);
        if (status == WorkingGroupStatus.NotExist) {
            return (status, 0);
        }
        return (status, _workingGroups.get(address_));
    }

    function getWorkingGroups()
        public
        view
        returns (address[] memory addresses)
    {
        return _workingGroups.keys();
    }

    function getWorkingGroupsLength() public view returns (uint256 length) {
        return _workingGroups.length();
    }

    function getWorkingGroupAtIndex(
        uint256 index
    )
        public
        view
        checkWorkingGroupIndex(index)
        returns (address address_, uint256 expireTimestamp)
    {
        return _workingGroups.at(index);
    }

    // function _checkAddress(address address_) internal view {
    //     require(address_ != address(0), "Cannot target zero address");
    //     require(address_ != address(this), "Cannot target self");
    // }

    // TODO: To be used by WorkingGroupSystem
    function _removeExpiredWorkingGroups() internal {
        address[] memory _addresses = _workingGroups.keys();
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (
                getWorkingGroupStatus(_addresses[i]) ==
                WorkingGroupStatus.Expired
            ) {
                assert(_workingGroups.remove(_addresses[i]));
            }
        }
    }

    function _setWorkingGroup(
        address address_,
        uint256 expireTimestamp
    ) internal returns (bool isNewEntry) {
        return _workingGroups.set(address_, expireTimestamp);
    }

    function _removeWorkingGroup(
        address address_
    ) internal returns (bool success) {
        return _workingGroups.remove(address_);
    }

    function _setStewardSystem(address stewardSystem_) internal {
        stewardSystem = stewardSystem_;
    }
}

abstract contract WorkingGroupAllowance is WorkingGroupManager {
    event Approval(address indexed spender, uint256 value);

    error InsufficientAllowance(
        address spender,
        uint256 allowance,
        uint256 needed
    );

    mapping(address spender => uint256 value) private _allowances;

    function allowance(address spender) public view virtual returns (uint256) {
        return _allowances[spender];
    }

    function _approve(address spender, uint256 value) internal {
        _approve(spender, value, true);
    }

    function _approve(
        address spender,
        uint256 value,
        bool emitEvent
    ) internal virtual {
        if (value > 0) {
            require(
                getWorkingGroupStatus(spender) == WorkingGroupStatus.Valid,
                "Spender is not a valid Working Group"
            );
        }
        _allowances[spender] = value;
        if (emitEvent) {
            emit Approval(spender, value);
        }
    }

    function _spendAllowance(address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(spender, currentAllowance - value, false);
            }
        }
    }
}

abstract contract WorkingGroupProposalVoting is WorkingGroupAllowance, Voting {
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    enum WorkingGroupAction {
        Set,
        Remove
    }

    event WorkingGroupProposalCreated(
        uint256 proposalId,
        WorkingGroupAction action,
        address targetAddress,
        uint256 newExpireTimestamp,
        uint256 allowance,
        uint256 votingEndTimestamp,
        address[] voters
    );

    struct WorkingGroupProposal {
        WorkingGroupAction action;
        address targetAddress;
        uint256 newExpireTimestamp;
        uint256 allowance;
        uint256 votingEndTimestamp;
        address[] voters;
        Vote[] votes;
        bool executed;
    }

    WorkingGroupProposal[] private _workingGroupProposals;
    uint256 public workingGroupVoteDuration;

    modifier checkWorkingGroupPropose(
        WorkingGroupAction action,
        address targetAddress,
        uint256 newExpireTimestamp,
        uint256 allowance
    ) {
        require(
            action == WorkingGroupAction.Set ||
                action == WorkingGroupAction.Remove,
            "Invalid action"
        );
        // require(targetAddress != address(0), "Cannot target zero address");
        // require(targetAddress != address(this), "Cannot target self");
        if (action == WorkingGroupAction.Set) {
            require(
                newExpireTimestamp > block.timestamp,
                "New expire timestamp must be in the future"
            );
        } else if (action == WorkingGroupAction.Remove) {
            require(
                getWorkingGroupStatus(targetAddress) !=
                    WorkingGroupStatus.NotExist,
                "Working Group does not exist"
            );
            require(
                newExpireTimestamp == 0,
                "New expire timestamp must be zero"
            );
            require(allowance == 0, "Allowance must be zero");
        }
        _;
    }

    constructor(
        address _stewardSystem,
        address[] memory workingGroupAddresses,
        uint256[] memory workingGroupExpireTimestamps,
        uint256[] memory workingGroupAllowances,
        uint256 proposalVoteDuration_
    )
        WorkingGroupManager(
            _stewardSystem,
            workingGroupAddresses,
            workingGroupExpireTimestamps
        )
    {
        // for (uint256 i = 0; i < workingGroupAddresses.length; i++) {
        //     require(workingGroupAddresses[i] != address(0), "Cannot target zero address");
        //     require(workingGroupAddresses[i] != address(this), "Cannot target self");
        // }
        require(
            workingGroupAddresses.length == workingGroupAllowances.length,
            "Length mismatch"
        );
        for (uint256 i = 0; i < workingGroupAddresses.length; i++) {
            _approve(workingGroupAddresses[i], workingGroupAllowances[i]);
        }
        workingGroupVoteDuration = proposalVoteDuration_;
    }

    function getWorkingGroupProposalsLength()
        public
        view
        returns (uint256 length)
    {
        return _workingGroupProposals.length;
    }

    function getWorkingGroupProposalById(
        uint256 proposalId
    )
        public
        view
        returns (
            WorkingGroupAction action,
            address targetAddress,
            uint256 newExpireTimestamp,
            uint256 allowance,
            uint256 votingEndTimestamp,
            address[] memory voters,
            Vote[] memory votes,
            bool executed
        )
    {
        _checkWorkingGroupProposeIndex(proposalId);
        return (
            _workingGroupProposals[proposalId].action,
            _workingGroupProposals[proposalId].targetAddress,
            _workingGroupProposals[proposalId].newExpireTimestamp,
            _workingGroupProposals[proposalId].allowance,
            _workingGroupProposals[proposalId].votingEndTimestamp,
            _workingGroupProposals[proposalId].voters,
            _workingGroupProposals[proposalId].votes,
            _workingGroupProposals[proposalId].executed
        );
    }

    function proposeWorkingGroup(
        WorkingGroupAction action,
        address targetAddress,
        uint256 newExpireTimestamp,
        uint256 allowance
    )
        external
        onlySteward
        checkWorkingGroupPropose(
            action,
            targetAddress,
            newExpireTimestamp,
            allowance
        )
        returns (uint256 proposalId)
    {
        (bool voteDurationNotOverflow, uint256 votingEndTimestamp_) = Math
            .tryAdd(block.timestamp, workingGroupVoteDuration);
        require(voteDurationNotOverflow, "Vote duration overflow");

        WorkingGroupProposal memory proposal = WorkingGroupProposal({
            action: action,
            targetAddress: targetAddress,
            newExpireTimestamp: newExpireTimestamp,
            allowance: allowance,
            votingEndTimestamp: votingEndTimestamp_,
            voters: new address[](0),
            votes: new Vote[](0),
            executed: false
        });

        _workingGroupProposals.push(proposal);
        proposalId = _workingGroupProposals.length - 1;
        _checkWorkingGroupProposeIndex(proposalId);

        address[] memory unscreenedVoters = IStewardSystem(stewardSystem)
            .getStewards();
        for (uint256 i = 0; i < unscreenedVoters.length; i++) {
            if (
                IStewardSystem(stewardSystem).getStewardStatus(
                    unscreenedVoters[i]
                ) == IStewardSystem.StewardStatus.Valid
            ) {
                _workingGroupProposals[proposalId].voters.push(
                    unscreenedVoters[i]
                );
                _workingGroupProposals[proposalId].votes.push(Vote.Abstain);
            }
        }
        require(
            _workingGroupProposals[proposalId].voters.length > 0,
            "No valid stewards"
        );

        _checkWorkingGroupProposalVotersAndVotesLength(proposalId);

        // DEBUG
        // for (
        //     uint256 i = 0;
        //     i < _workingGroupProposals[proposalId].voters.length;
        //     i++
        // ) {
        //     if (_workingGroupProposals[proposalId].voters[i] == msg.sender)
        //         _workingGroupProposals[proposalId].votes[i] = Vote.Approve;
        // }

        emit WorkingGroupProposalCreated(
            proposalId,
            _workingGroupProposals[proposalId].action,
            _workingGroupProposals[proposalId].targetAddress,
            _workingGroupProposals[proposalId].newExpireTimestamp,
            _workingGroupProposals[proposalId].allowance,
            _workingGroupProposals[proposalId].votingEndTimestamp,
            _workingGroupProposals[proposalId].voters
        );
    }

    function voteOnWorkingGroupProposal(
        uint256 proposalId,
        Vote vote
    ) external {
        _checkWorkingGroupProposeIndex(proposalId);
        _checkWorkingGroupProposalVotersAndVotesLength(proposalId);

        require(
            vote == Vote.Approve || vote == Vote.Reject,
            "Invalid vote, must be approve or reject"
        );

        WorkingGroupProposal storage proposal = _workingGroupProposals[
            proposalId
        ];
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

    function executeWorkingGroupProposal(uint256 proposalId) external {
        _checkWorkingGroupProposeIndex(proposalId);
        _checkWorkingGroupProposalVotersAndVotesLength(proposalId);

        WorkingGroupProposal storage proposal = _workingGroupProposals[
            proposalId
        ];

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

        if (proposal.action == WorkingGroupAction.Set) {
            _setWorkingGroup(
                proposal.targetAddress,
                proposal.newExpireTimestamp
            );
        } else if (proposal.action == WorkingGroupAction.Remove) {
            _removeWorkingGroup(proposal.targetAddress);
        }
        _approve(proposal.targetAddress, proposal.allowance);
    }

    function _checkWorkingGroupProposeIndex(uint256 index) internal view {
        require(
            index < getWorkingGroupProposalsLength(),
            "Index out of bounds"
        );
    }

    function _checkWorkingGroupProposalVotersAndVotesLength(
        uint256 proposalId
    ) internal view {
        require(
            _workingGroupProposals[proposalId].voters.length ==
                _workingGroupProposals[proposalId].votes.length,
            "Voters and Votes length mismatch"
        );
    }

    // [TODO] To be used by WorkingGroupSystem
    function _setWorkingGroupVoteDuration(uint256 duration) internal {
        workingGroupVoteDuration = duration;
    }
}

contract WorkingGroupSystem is SafeModule, WorkingGroupProposalVoting, Ownable {
    constructor(
        address safeAccount,
        address _stewardSystem,
        address[] memory workingGroupAddresses,
        uint256[] memory workingGroupTimestamps,
        uint256[] memory workingGroupAllowances,
        uint256 proposalVoteDuration_,
        address owner
    )
        SafeModule(safeAccount)
        WorkingGroupProposalVoting(
            _stewardSystem,
            workingGroupAddresses,
            workingGroupTimestamps,
            workingGroupAllowances,
            proposalVoteDuration_
        )
        Ownable(owner)
    {}

    function setWorkingGroupVoteDuration(uint256 duration) external onlyOwner {
        _setWorkingGroupVoteDuration(duration);
    }

    function setStewardSystem(address stewardSystem_) external onlyOwner {
        _setStewardSystem(stewardSystem_);
    }

    function sendFromSafe(
        address to,
        uint256 value
    ) external returns (bool success) {
        _spendAllowance(msg.sender, value);
        return _sendFromSafe(to, value);
    }

    function _sendFromSafe(
        address to,
        uint256 value
    ) internal returns (bool success) {
        return execTransactionFromModule(to, value, "0x", Enum.Operation.Call);
    }

    // function execute(
    //     address target,
    //     bytes memory data
    // ) external onlyOwner {
    //     (bool success, bytes memory returnData) = target.call(data);
    //     require(success, string(returnData));
    // }
}
