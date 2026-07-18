// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IClaimTopicsRegistry} from "./IClaimTopicsRegistry.sol";

/**
 * @title ClaimTopicsRegistryCloneable
 * @dev Registry of required claim topics that can be cloned using EIP-1167 minimal proxy pattern
 * Uses Initializable pattern instead of constructor for clone compatibility
 */
contract ClaimTopicsRegistryCloneable is OwnableUpgradeable, IClaimTopicsRegistry {
    // Array of required claim topics
    uint256[] private claimTopics;

    event ClaimTopicAdded(uint256 indexed claimTopic);
    event ClaimTopicRemoved(uint256 indexed claimTopic);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize the registry (replaces constructor for clones)
     * @param initialOwner Owner of this registry
     */
    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
    }

    /**
     * @dev Add a required claim topic
     * @param _claimTopic Claim topic ID
     */
    function addClaimTopic(uint256 _claimTopic) external onlyOwner {
        require(!claimTopicExists(_claimTopic), "Claim topic already exists");

        claimTopics.push(_claimTopic);

        emit ClaimTopicAdded(_claimTopic);
    }

    /**
     * @dev Remove a claim topic
     * @param _claimTopic Claim topic ID
     */
    function removeClaimTopic(uint256 _claimTopic) external onlyOwner {
        require(claimTopicExists(_claimTopic), "Claim topic does not exist");

        for (uint256 i = 0; i < claimTopics.length; i++) {
            if (claimTopics[i] == _claimTopic) {
                claimTopics[i] = claimTopics[claimTopics.length - 1];
                claimTopics.pop();
                break;
            }
        }

        emit ClaimTopicRemoved(_claimTopic);
    }

    /**
     * @dev Get all claim topics
     */
    function getClaimTopics() external view returns (uint256[] memory) {
        return claimTopics;
    }

    /**
     * @dev Check if a claim topic exists
     * @param _claimTopic Claim topic ID
     */
    function claimTopicExists(uint256 _claimTopic) public view returns (bool) {
        for (uint256 i = 0; i < claimTopics.length; i++) {
            if (claimTopics[i] == _claimTopic) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Get number of claim topics
     */
    function getClaimTopicsCount() external view returns (uint256) {
        return claimTopics.length;
    }
}

