// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title IdentityCloneable
 * @dev Identity contract that can be cloned using EIP-1167 minimal proxy pattern
 * Uses Initializable pattern instead of constructor for clone compatibility
 */
contract IdentityCloneable is OwnableUpgradeable {
    // Mapping of claim topic => issuer => claim data
    mapping(uint256 => mapping(address => Claim)) private claims;
    
    // Mapping to track which issuers have claims for each topic
    mapping(uint256 => address[]) private topicIssuers;
    
    // Mapping to check if an issuer is in the array (to avoid duplicates)
    mapping(uint256 => mapping(address => bool)) private topicIssuerExists;

    struct Claim {
        uint256 topic;
        uint256 scheme;
        address issuer;
        bytes signature;
        bytes data;
        string uri;
    }

    event ClaimAdded(
        uint256 indexed topic,
        uint256 scheme,
        address indexed issuer,
        bytes signature,
        bytes data,
        string uri
    );

    event ClaimRemoved(uint256 indexed topic, address indexed issuer);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize the identity contract (replaces constructor for clones)
     * @param initialOwner The owner of this identity
     */
    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
    }

    /**
     * @dev Add a claim to the identity
     * @param _topic Claim topic (e.g., 1 for KYC)
     * @param _scheme Signature scheme (1 = ECDSA)
     * @param _issuer Address of the claim issuer
     * @param _signature Signature of the claim
     * @param _data Claim data
     * @param _uri URI for additional claim information
     */
    function addClaim(
        uint256 _topic,
        uint256 _scheme,
        address _issuer,
        bytes memory _signature,
        bytes memory _data,
        string memory _uri
    ) external onlyOwner returns (bytes32) {
        claims[_topic][_issuer] = Claim({
            topic: _topic,
            scheme: _scheme,
            issuer: _issuer,
            signature: _signature,
            data: _data,
            uri: _uri
        });
        
        // Track this issuer for this topic
        if (!topicIssuerExists[_topic][_issuer]) {
            topicIssuers[_topic].push(_issuer);
            topicIssuerExists[_topic][_issuer] = true;
        }

        emit ClaimAdded(_topic, _scheme, _issuer, _signature, _data, _uri);

        bytes32 claimId;
        assembly {
            // Store issuer at memory position 0x00
            mstore(0x00, _issuer)
            // Store topic at memory position 0x20
            mstore(0x20, _topic)
            // Hash 64 bytes (2 * 32 bytes)
            claimId := keccak256(0x00, 0x40)
        }
        return claimId;
    }

    /**
     * @dev Remove a claim from the identity
     * @param _topic Claim topic
     * @param _issuer Issuer address
     */
    function removeClaim(uint256 _topic, address _issuer) external onlyOwner returns (bool) {
        delete claims[_topic][_issuer];
        
        // Remove issuer from tracking array
        if (topicIssuerExists[_topic][_issuer]) {
            address[] storage issuers = topicIssuers[_topic];
            for (uint256 i = 0; i < issuers.length; i++) {
                if (issuers[i] == _issuer) {
                    issuers[i] = issuers[issuers.length - 1];
                    issuers.pop();
                    break;
                }
            }
            topicIssuerExists[_topic][_issuer] = false;
        }
        
        emit ClaimRemoved(_topic, _issuer);
        return true;
    }

    /**
     * @dev Get a claim
     * @param _topic Claim topic
     * @param _issuer Issuer address
     */
    function getClaim(uint256 _topic, address _issuer)
        external
        view
        returns (
            uint256 topic,
            uint256 scheme,
            address issuer,
            bytes memory signature,
            bytes memory data,
            string memory uri
        )
    {
        Claim memory claim = claims[_topic][_issuer];
        return (claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri);
    }

    /**
     * @dev Check if a claim exists
     * @param _topic Claim topic
     * @param _issuer Issuer address
     */
    function claimExists(uint256 _topic, address _issuer) external view returns (bool) {
        return claims[_topic][_issuer].issuer != address(0);
    }
    
    /**
     * @dev Get all issuers that have issued claims for a specific topic
     * @param _topic Claim topic
     * @return Array of issuer addresses
     */
    function getClaimIssuersForTopic(uint256 _topic) external view returns (address[] memory) {
        return topicIssuers[_topic];
    }
}
