// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IClaimTopicsRegistry
 * @dev Interface for ClaimTopicsRegistry contracts
 * This allows Token contracts to use any implementation (regular or cloneable)
 */
interface IClaimTopicsRegistry {
    /**
     * @dev Get all claim topics
     * @return Array of claim topic IDs
     */
    function getClaimTopics() external view returns (uint256[] memory);

    /**
     * @dev Check if a claim topic exists
     * @param _claimTopic Claim topic ID
     * @return True if the topic exists
     */
    function claimTopicExists(uint256 _claimTopic) external view returns (bool);

    /**
     * @dev Get number of claim topics
     * @return Count of claim topics
     */
    function getClaimTopicsCount() external view returns (uint256);
}

