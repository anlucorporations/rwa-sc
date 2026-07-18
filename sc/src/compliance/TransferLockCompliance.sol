// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ICompliance} from "../ICompliance.sol";

/**
 * @title TransferLockCompliance
 * @dev Compliance module that enforces transfer lock period
 * Implements rule #3: Lock-up period for selling tokens
 */
contract TransferLockCompliance is ICompliance, Ownable {
    // Lock period duration in seconds
    uint256 public lockPeriod;

    // Token contract address
    address public tokenContract;

    // Mapping from address to their lock end time
    mapping(address => uint256) private lockEndTime;
    
    // Mapping of authorized callers (for use with ComplianceAggregator)
    mapping(address => bool) public authorizedCallers;

    event LockPeriodSet(uint256 lockPeriod);
    event TransferLocked(address indexed account, uint256 lockEndTime);
    event AuthorizedCallerAdded(address indexed caller);
    event AuthorizedCallerRemoved(address indexed caller);

    modifier onlyTokenOrAuthorized() {
        require(
            msg.sender == tokenContract || authorizedCallers[msg.sender],
            "Only token contract or authorized caller"
        );
        _;
    }

    constructor(address initialOwner, uint256 _lockPeriod) Ownable(initialOwner) {
        lockPeriod = _lockPeriod;
        emit LockPeriodSet(_lockPeriod);
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
     * @dev Set the lock period
     * @param _lockPeriod New lock period in seconds
     */
    function setLockPeriod(uint256 _lockPeriod) external onlyOwner {
        lockPeriod = _lockPeriod;
        emit LockPeriodSet(_lockPeriod);
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
     * @dev Check if sender can transfer (lock period expired)
     * @param from Sender address
     */
    function canTransfer(address from, address /* to */, uint256 /* amount */) external view override returns (bool) {
        // Check if sender's lock period has expired
        return block.timestamp >= lockEndTime[from];
    }

    /**
     * @dev Called after transfer to set lock on recipient
     * @param to Recipient address
     */
    function transferred(address /* from */, address to, uint256 /* amount */) external override onlyTokenOrAuthorized {
        // Set lock period for recipient
        uint256 newLockEndTime = block.timestamp + lockPeriod;
        lockEndTime[to] = newLockEndTime;
        emit TransferLocked(to, newLockEndTime);
    }

    /**
     * @dev Called after minting to set lock on recipient
     * @param to Recipient address
     */
    function created(address to, uint256 /* amount */) external override onlyTokenOrAuthorized {
        // Set lock period for new token holder
        uint256 newLockEndTime = block.timestamp + lockPeriod;
        lockEndTime[to] = newLockEndTime;
        emit TransferLocked(to, newLockEndTime);
    }

    /**
     * @dev Called after burning - no action needed for this module
     */
    function destroyed(address /* from */, uint256 /* amount */) external override onlyTokenOrAuthorized {
        // No state changes needed
    }

    /**
     * @dev Get the lock end time for an address
     * @param account Address to check
     */
    function getLockEndTime(address account) external view returns (uint256) {
        return lockEndTime[account];
    }

    /**
     * @dev Check if an address is currently locked
     * @param account Address to check
     */
    function isLocked(address account) external view returns (bool) {
        return block.timestamp < lockEndTime[account];
    }

    /**
     * @dev Get remaining lock time for an address
     * @param account Address to check
     */
    function getRemainingLockTime(address account) external view returns (uint256) {
        if (block.timestamp >= lockEndTime[account]) {
            return 0;
        }
        return lockEndTime[account] - block.timestamp;
    }
}
