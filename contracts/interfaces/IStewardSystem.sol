// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IStewardSystem {
    enum StewardStatus {
        NotExist,
        Valid,
        Expired
    }

    function getStewardStatus(
        address address_
    ) external view returns (StewardStatus status);

    function getSteward(
        address address_
    )
        external
        view
        returns (StewardStatus status, uint256 stewardExpireTimestamp);

    function getStewards() external view returns (address[] memory addresses);

    function getStewardsLength() external view returns (uint256 length);

    function getStewardAtIndex(
        uint256 index
    ) external view returns (address address_, uint256 expireTimestamp);
}
