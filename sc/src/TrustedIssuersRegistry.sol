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

    /// @dev H-20: indice 1-based de `_issuer` en `trustedIssuersList` (`0` = no presente) para
    /// borrado O(1) en lugar del escaneo lineal.
    mapping(address => uint256) private issuerIndex;

    /// @dev H-20: pertenencia `(issuer, topic)` en O(1). Sustituye el recorrido de
    /// `issuerClaimTopics` que hacia `hasClaimTopic` (llamada en bucle por `isVerified`).
    mapping(address => mapping(uint256 => bool)) private issuerHasTopic;

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
        for (uint256 i = 0; i < _claimTopics.length; i++) {
            issuerHasTopic[_issuer][_claimTopics[i]] = true;
        }
        trustedIssuersList.push(_issuer);
        issuerIndex[_issuer] = trustedIssuersList.length;

        emit TrustedIssuerAdded(_issuer, _claimTopics);
    }

    /**
     * @dev Remove a trusted issuer
     * @param _issuer Issuer address
     */
    function removeTrustedIssuer(address _issuer) external onlyOwner {
        require(trustedIssuers[_issuer], "Issuer not trusted");

        trustedIssuers[_issuer] = false;

        // H-20: limpia la pertenencia (issuer, topic) antes de borrar el array de topics.
        uint256[] storage oldTopics = issuerClaimTopics[_issuer];
        for (uint256 j = 0; j < oldTopics.length; j++) {
            issuerHasTopic[_issuer][oldTopics[j]] = false;
        }
        delete issuerClaimTopics[_issuer];

        // Remove from list en O(1) via `issuerIndex` (swap-and-pop)
        uint256 idx = issuerIndex[_issuer];
        require(idx != 0, "Issuer not in list");
        uint256 i = idx - 1;
        uint256 lastIndex = trustedIssuersList.length - 1;
        if (i != lastIndex) {
            address moved = trustedIssuersList[lastIndex];
            trustedIssuersList[i] = moved;
            issuerIndex[moved] = idx;
        }
        trustedIssuersList.pop();
        delete issuerIndex[_issuer];

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

        // H-20: mantiene sincronizada la pertenencia O(1) al reemplazar los topics.
        uint256[] storage oldTopics = issuerClaimTopics[_issuer];
        for (uint256 i = 0; i < oldTopics.length; i++) {
            issuerHasTopic[_issuer][oldTopics[i]] = false;
        }
        issuerClaimTopics[_issuer] = _claimTopics;
        for (uint256 i = 0; i < _claimTopics.length; i++) {
            issuerHasTopic[_issuer][_claimTopics[i]] = true;
        }

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
        // H-20: pertenencia O(1); antes se recorria `issuerClaimTopics` en cada consulta.
        return issuerHasTopic[_issuer][_claimTopic];
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

    /**
     * @dev H-20: vista paginada de `trustedIssuersList`. `offset >= length` o `limit == 0`
     * devuelve un array vacio.
     * @param offset Indice inicial (0-based)
     * @param limit Numero maximo de elementos
     */
    function getTrustedIssuersPaginated(uint256 offset, uint256 limit) external view returns (address[] memory page) {
        uint256 total = trustedIssuersList.length;
        if (offset >= total || limit == 0) {
            return new address[](0);
        }
        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        page = new address[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            page[i - offset] = trustedIssuersList[i];
        }
    }
}
