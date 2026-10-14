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

    /// @dev H-20: indice 1-based del topic en `claimTopics` (`0` = no presente) para borrado O(1).
    mapping(uint256 => uint256) private topicIndex;

    /// @dev H-20: pertenencia O(1); antes `claimTopicExists` recorria el array.
    mapping(uint256 => bool) private topicExistsFlag;

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
     *
     * HB-15: topic `0` is reserved/never a real requirement and is rejected explicitly.
     */
    function addClaimTopic(uint256 _claimTopic) external onlyOwner {
        require(_claimTopic != 0, "Invalid claim topic");
        require(!topicExistsFlag[_claimTopic], "Claim topic already exists");

        claimTopics.push(_claimTopic);
        topicIndex[_claimTopic] = claimTopics.length;
        topicExistsFlag[_claimTopic] = true;

        emit ClaimTopicAdded(_claimTopic);
    }

    /**
     * @dev Remove a claim topic
     * @param _claimTopic Claim topic ID
     */
    function removeClaimTopic(uint256 _claimTopic) external onlyOwner {
        require(topicExistsFlag[_claimTopic], "Claim topic does not exist");

        // H-20: borrado O(1) por indice (swap-and-pop), sin escanear el array.
        uint256 idx = topicIndex[_claimTopic];
        uint256 i = idx - 1;
        uint256 lastIndex = claimTopics.length - 1;
        if (i != lastIndex) {
            uint256 moved = claimTopics[lastIndex];
            claimTopics[i] = moved;
            topicIndex[moved] = idx;
        }
        claimTopics.pop();
        delete topicIndex[_claimTopic];
        topicExistsFlag[_claimTopic] = false;

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
        return topicExistsFlag[_claimTopic];
    }

    /**
     * @dev Get number of claim topics
     */
    function getClaimTopicsCount() external view returns (uint256) {
        return claimTopics.length;
    }

    /**
     * @dev H-20: vista paginada de `claimTopics`. `offset >= length` o `limit == 0` devuelve vacio.
     * @param offset Indice inicial (0-based)
     * @param limit Numero maximo de elementos
     */
    function getClaimTopicsPaginated(uint256 offset, uint256 limit) external view returns (uint256[] memory page) {
        uint256 total = claimTopics.length;
        if (offset >= total || limit == 0) {
            return new uint256[](0);
        }
        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        page = new uint256[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            page[i - offset] = claimTopics[i];
        }
    }
}

