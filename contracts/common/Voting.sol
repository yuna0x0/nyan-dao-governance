// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

abstract contract Voting {
    enum Vote {
        Abstain,
        Approve,
        Reject
    }
}
