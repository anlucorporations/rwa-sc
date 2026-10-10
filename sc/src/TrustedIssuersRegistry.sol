// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TrustedIssuersRegistry
 * @dev Registry of trusted claim issuers
 * Only claims from trusted issuers are accepted for compliance checks
 */
contract TrustedIssuersRegistry is Ownable {
    // Mapping of issuer address to their claim topics
    mapping(address => uint256[]) private issuerClaimTopics;

    // Mapping to check if an issuer is trusted
    mapping(address => bool) private trustedIssuers;

    // Array of all trusted issuer addresses
    address[] private trustedIssuersList;

    event TrustedIssuerAdded(address indexed issuer, uint256[] claimTopics);
    event TrustedIssuerRemoved(address indexed issuer);
    event ClaimTopicsUpdated(address indexed issuer, uint256[] claimTopics);

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev Add a trusted issuer
     * @param _issuer Issuer address
     * @param _claimTopics Array of claim topics the issuer can issue
     */
    function addTrustedIssuer(address _issuer, uint256[] memory _claimTopics) external onlyOwner {
        require(_issuer != address(0), "Invalid issuer address");
        require(!trustedIssuers[_issuer], "Issuer already trusted");
        require(_claimTopics.length > 0, "Must specify at least one claim topic");

        trustedIssuers[_issuer] = true;
        issuerClaimTopics[_issuer] = _claimTopics;
        trustedIssuersList.push(_issuer);

        emit TrustedIssuerAdded(_issuer, _claimTopics);
    }

    /**
     * @dev Remove a trusted issuer
     * @param _issuer Issuer address
     */
    function removeTrustedIssuer(address _issuer) external onlyOwner {
        require(trustedIssuers[_issuer], "Issuer not trusted");

        trustedIssuers[_issuer] = false;
        delete issuerClaimTopics[_issuer];

        // Remove from list
        for (uint256 i = 0; i < trustedIssuersList.length; i++) {
            if (trustedIssuersList[i] == _issuer) {
                trustedIssuersList[i] = trustedIssuersList[trustedIssuersList.length - 1];
                trustedIssuersList.pop();
                break;
            }
        }

        emit TrustedIssuerRemoved(_issuer);
    }

    /**
     * @dev Update claim topics for a trusted issuer
     * @param _issuer Issuer address
     * @param _claimTopics New array of claim topics
     */
    function updateIssuerClaimTopics(address _issuer, uint256[] memory _claimTopics) external onlyOwner {
        require(trustedIssuers[_issuer], "Issuer not trusted");
        require(_claimTopics.length > 0, "Must specify at least one claim topic");

        issuerClaimTopics[_issuer] = _claimTopics;

        emit ClaimTopicsUpdated(_issuer, _claimTopics);
    }

    /**
     * @dev Check if an issuer is trusted
     * @param _issuer Issuer address
     */
    function isTrustedIssuer(address _issuer) external view returns (bool) {
        return trustedIssuers[_issuer];
    }

    /**
     * @dev Get claim topics for an issuer
     * @param _issuer Issuer address
     */
    function getIssuerClaimTopics(address _issuer) external view returns (uint256[] memory) {
        return issuerClaimTopics[_issuer];
    }

    /**
     * @dev Check if an issuer can issue a specific claim topic
     * @param _issuer Issuer address
     * @param _claimTopic Claim topic
     */
    function hasClaimTopic(address _issuer, uint256 _claimTopic) external view returns (bool) {
        if (!trustedIssuers[_issuer]) {
            return false;
        }

        uint256[] memory topics = issuerClaimTopics[_issuer];
        for (uint256 i = 0; i < topics.length; i++) {
            if (topics[i] == _claimTopic) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Get all trusted issuers
     */
    function getTrustedIssuers() external view returns (address[] memory) {
        return trustedIssuersList;
    }

    /**
     * @dev Get number of trusted issuers
     */
    function getTrustedIssuersCount() external view returns (uint256) {
        return trustedIssuersList.length;
    }
}
