// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ICompliance} from "../ICompliance.sol";

/**
 * @title MaxHoldersCompliance
 * @dev Compliance module that enforces maximum number of token holders
 * Implements rule #2: Maximum number of holders
 */
contract MaxHoldersCompliance is ICompliance, Ownable {
    // Maximum number of holders allowed
    uint256 public maxHolders;

    // Current number of holders
    uint256 public holderCount;

    // Token contract address
    address public tokenContract;

    // Mapping to track if address is a holder
    mapping(address => bool) private isHolder;
    
    // Mapping of authorized callers (for use with ComplianceAggregator)
    mapping(address => bool) public authorizedCallers;

    event MaxHoldersSet(uint256 maxHolders);
    event HolderAdded(address indexed holder);
    event HolderRemoved(address indexed holder);
    event AuthorizedCallerAdded(address indexed caller);
    event AuthorizedCallerRemoved(address indexed caller);

    modifier onlyTokenOrAuthorized() {
        require(
            msg.sender == tokenContract || authorizedCallers[msg.sender],
            "Only token contract or authorized caller"
        );
        _;
    }

    constructor(address initialOwner, uint256 _maxHolders) Ownable(initialOwner) {
        maxHolders = _maxHolders;
        emit MaxHoldersSet(_maxHolders);
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
     * @dev Set the maximum number of holders
     * @param _maxHolders New maximum holders
     */
    function setMaxHolders(uint256 _maxHolders) external onlyOwner {
        require(_maxHolders >= holderCount, "Cannot set below current holder count");
        maxHolders = _maxHolders;
        emit MaxHoldersSet(_maxHolders);
    }

    /**
     * @dev Add an authorized caller (e.g., ComplianceAggregator)
     * @param caller Address to authorize
     */
    function addAuthorizedCaller(address caller) external onlyOwner {
        require(caller != address(0), "Invalid caller address");
        authorizedCallers[caller] = true;
        emit AuthorizedCallerAdded(caller);
    }

    /**
     * @dev Remove an authorized caller
     * @param caller Address to deauthorize
     */
    function removeAuthorizedCaller(address caller) external onlyOwner {
        authorizedCallers[caller] = false;
        emit AuthorizedCallerRemoved(caller);
    }

    /**
     * @dev Check if a transfer would exceed max holders
     * @param to Recipient address
     */
    function canTransfer(address /* from */, address to, uint256 /* amount */) external view override returns (bool) {
        // If recipient is already a holder, transfer is allowed
        if (isHolder[to]) {
            return true;
        }

        // If adding a new holder would exceed max, reject
        if (holderCount >= maxHolders) {
            return false;
        }

        return true;
    }

    /**
     * @dev Called after transfer to update holder count
     * @param from Sender address
     * @param to Recipient address
     */
    function transferred(address from, address to, uint256 /* amount */) external override onlyTokenOrAuthorized {
        // Get balances from token contract
        (bool successFrom, bytes memory dataFrom) = tokenContract.staticcall(
            abi.encodeWithSignature("balanceOf(address)", from)
        );
        (bool successTo, bytes memory dataTo) = tokenContract.staticcall(
            abi.encodeWithSignature("balanceOf(address)", to)
        );

        if (successFrom && successTo) {
            uint256 fromBalance = abi.decode(dataFrom, (uint256));
            uint256 toBalance = abi.decode(dataTo, (uint256));

            // If sender now has 0 balance, remove as holder
            if (fromBalance == 0 && isHolder[from]) {
                isHolder[from] = false;
                holderCount--;
                emit HolderRemoved(from);
            }

            // If recipient now has balance and wasn't a holder, add as holder
            if (toBalance > 0 && !isHolder[to]) {
                isHolder[to] = true;
                holderCount++;
                emit HolderAdded(to);
            }
        }
    }

    /**
     * @dev Called after minting
     * @param to Recipient address
     * @param amount Mint amount
     */
    function created(address to, uint256 amount) external override onlyTokenOrAuthorized {
        if (!isHolder[to] && amount > 0) {
            isHolder[to] = true;
            holderCount++;
            emit HolderAdded(to);
        }
    }

    /**
     * @dev Called after burning
     * @param from Address from which tokens are burned
     */
    function destroyed(address from, uint256 /* amount */) external override onlyTokenOrAuthorized {
        // Get balance from token contract
        (bool success, bytes memory data) = tokenContract.staticcall(
            abi.encodeWithSignature("balanceOf(address)", from)
        );

        if (success) {
            uint256 balance = abi.decode(data, (uint256));

            // If balance is now 0, remove as holder
            if (balance == 0 && isHolder[from]) {
                isHolder[from] = false;
                holderCount--;
                emit HolderRemoved(from);
            }
        }
    }

    /**
     * @dev Check if address is a holder
     */
    function getIsHolder(address account) external view returns (bool) {
        return isHolder[account];
    }
}
