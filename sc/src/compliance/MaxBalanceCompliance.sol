// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ICompliance} from "../ICompliance.sol";

/**
 * @title MaxBalanceCompliance
 * @dev Compliance module that enforces maximum balance per wallet
 * Implements rule #1: Maximum 1000 tokens per wallet
 */
contract MaxBalanceCompliance is ICompliance, ERC165, Ownable {
    // Maximum balance allowed per wallet
    uint256 public maxBalance;

    // Token contract address
    address public tokenContract;

    event MaxBalanceSet(uint256 maxBalance);

    constructor(address initialOwner, uint256 _maxBalance) Ownable(initialOwner) {
        maxBalance = _maxBalance;
        emit MaxBalanceSet(_maxBalance);
    }

    /**
     * @dev ERC-165 (RF-003): declara la conformidad con `ICompliance` y `IERC165`.
     * @param interfaceId Interface identifier to query
     * @return bool True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(ICompliance).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Set the token contract address
     * @param _token Token contract address
     */
    function setTokenContract(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token address");
        tokenContract = _token;
    }

    /**
     * @dev Set the maximum balance
     * @param _maxBalance New maximum balance
     */
    function setMaxBalance(uint256 _maxBalance) external onlyOwner {
        maxBalance = _maxBalance;
        emit MaxBalanceSet(_maxBalance);
    }

    /**
     * @dev Check if a transfer would exceed max balance
     * @param to Recipient address
     *
     * AF-01: lectura defensiva del saldo. Si `tokenContract` no esta configurado o no responde
     * (EOA, contrato sin `balanceOf`, retorno vacio o mal formado) el modulo **degrada a `false`**
     * (fail-closed) en vez de revertir con un `abi.decode` opaco que bloquearia el token entero.
     */
    function canTransfer(address, address to, uint256 amount) external view override returns (bool) {
        // Get recipient's current balance from token contract
        (bool success, bytes memory data) = tokenContract.staticcall(abi.encodeWithSignature("balanceOf(address)", to));

        if (!success || data.length < 32) {
            return false;
        }

        uint256 recipientBalance = abi.decode(data, (uint256));

        // Check if transfer would exceed max balance
        return (recipientBalance + amount) <= maxBalance;
    }

    /**
     * @dev Called after transfer - no action needed for this module
     */
    function transferred(address from, address to, uint256 amount) external override {
        // No state changes needed
    }

    /**
     * @dev Called after minting - no action needed for this module
     */
    function created(address to, uint256 amount) external override {
        // No state changes needed
    }

    /**
     * @dev Called after burning - no action needed for this module
     */
    function destroyed(address from, uint256 amount) external override {
        // No state changes needed
    }
}
