// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract SecureHT is ERC20, Ownable, Pausable, ERC20Permit, ERC20Burnable {
    mapping(address => bool) private _blacklist;
    mapping(address => uint256) private _dailyTransactionLimit;
    mapping(address => uint256) private _lastTransactionTimestamp;
    mapping(address => uint256) private _dailyTransactionAmount;

    bytes32 private _saltNonce;

    uint256 private constant DEFAULT_DAILY_LIMIT = 50000 * 10**18;
    uint256 private constant TRANSACTION_WINDOW = 1 days;

    event AddedToBlacklist(address indexed account);
    event RemovedFromBlacklist(address indexed account);
    event TransactionLimitUpdated(address indexed account, uint256 newLimit);

    constructor() 
        ERC20("Secure Hashi Token", "SHT")
        Ownable(msg.sender)  
        ERC20Permit("Secure Hashi Token") 
    {
        _saltNonce = keccak256(abi.encodePacked(block.timestamp, msg.sender));
        _mint(msg.sender, 10000000 * 10**decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function addToBlacklist(address account) external onlyOwner {
        _blacklist[account] = true;
        emit AddedToBlacklist(account);
    }

    function removeFromBlacklist(address account) external onlyOwner {
        _blacklist[account] = false;
        emit RemovedFromBlacklist(account);
    }

    function isBlacklisted(address account) public view returns (bool) {
        return _blacklist[account];
    }

    function setTransactionLimit(address account, uint256 limit) external onlyOwner {
        _dailyTransactionLimit[account] = limit;
        emit TransactionLimitUpdated(account, limit);
    }

    function _transfer(
        address sender, 
        address recipient, 
        uint256 amount
    ) internal override whenNotPaused {
        require(!_blacklist[sender], "Transfer from blacklisted address");
        require(!_blacklist[recipient], "Transfer to blacklisted address");

        uint256 dailyLimit = _dailyTransactionLimit[sender] > 0 
            ? _dailyTransactionLimit[sender] 
            : DEFAULT_DAILY_LIMIT;

        if (block.timestamp > _lastTransactionTimestamp[sender] + TRANSACTION_WINDOW) {
            _dailyTransactionAmount[sender] = 0;
            _lastTransactionTimestamp[sender] = block.timestamp;
        }

        require(
            _dailyTransactionAmount[sender] + amount <= dailyLimit, 
            "Daily transaction limit exceeded"
        );

        _dailyTransactionAmount[sender] += amount;

        bytes32 salt = keccak256(abi.encodePacked(_saltNonce, sender, recipient, amount));

        super._transfer(sender, recipient, amount);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function privateTransfer(
        address recipient, 
        uint256 amount, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) external {
        permit(msg.sender, address(this), amount, block.timestamp + 1 hours, v, r, s);
        _transfer(msg.sender, recipient, amount);
    }

    function getCurrentDailyLimit(address account) public view returns (uint256) {
        return _dailyTransactionLimit[account] > 0 
            ? _dailyTransactionLimit[account] 
            : DEFAULT_DAILY_LIMIT;
    }

    function updateSalt() external onlyOwner {
        _saltNonce = keccak256(abi.encodePacked(_saltNonce, block.timestamp));
    }
}
