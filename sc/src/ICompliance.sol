// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ICompliance
 * @dev Interface for compliance modules
 */
interface ICompliance {
    /**
     * @dev Check if a transfer is compliant
     * @param from Sender address
     * @param to Recipient address
     * @param amount Transfer amount
     * @return bool True if compliant
     */
    function canTransfer(address from, address to, uint256 amount) external view returns (bool);

    /**
     * @dev Called when a transfer occurs
     * @param from Sender address
     * @param to Recipient address
     * @param amount Transfer amount
     */
    function transferred(address from, address to, uint256 amount) external;

    /**
     * @dev Called when tokens are created
     * @param to Recipient address
     * @param amount Mint amount
     */
    function created(address to, uint256 amount) external;

    /**
     * @dev Called when tokens are destroyed
     * @param from Address from which tokens are burned
     * @param amount Burn amount
     */
    function destroyed(address from, uint256 amount) external;
}
