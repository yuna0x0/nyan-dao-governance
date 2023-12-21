// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/utils/math/Math.sol";

library MathUtils {
    /**
     * @dev Compares the percentage of `length1` to `length2` and returns true if it's within the specified threshold.
     * @param length1 The first length to compare.
     * @param length2 The second length to compare.
     * @param thresholdPercentage The threshold percentage (e.g., 66 for 66%).
     */
    function isWithinPercentage(
        uint256 length1,
        uint256 length2,
        uint256 thresholdPercentage
    ) internal pure returns (bool) {
        require(length2 != 0, "Cannot divide by zero");
        require(length1 <= length2, "Length1 cannot exceed length2");
        require(thresholdPercentage <= 100, "Percentage cannot exceed 100");

        uint256 percentage = Math.mulDiv(length1, 100, length2);
        return percentage >= thresholdPercentage;
    }
}
