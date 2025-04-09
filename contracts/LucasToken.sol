// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LucasToken
 * @dev Profit-sharing token contract with purchase and distribution mechanisms
 * Token holders can buy tokens, receive profit distributions, and claim their share
 */
contract LucasToken is ReentrancyGuard, Ownable {
    // Token Details
    string public name = "LucasToken"; // Token name
    string public symbol = "CAS"; // Token symbol
    uint8 public decimals = 18; // Decimal places for token
    uint256 public totalSupply = 1_000_000 * 10 ** 18; // Total supply: 1M tokens

    // Mappings
    mapping(address => uint256) public balanceOf; // Token balances per address
    mapping(uint256 => uint256) public profitPerToken; // Profit per token per round
    mapping(address => mapping(uint256 => bool)) public hasClaimed; // Claim status per user per round
    mapping(address => uint256) public lastTransferTime; // Last transfer timestamp per address
    mapping(address => mapping(address => uint256)) public allowance; // Allowance for spending

    // Purchase and Distribution Variables
    uint256 public tokenPrice = 1 ether / 1000; // Price: 1 ETH = 1000 tokens
    uint256 public currentRound = 0; // Current profit distribution round
    uint256 public distributionDelay = 1 days; // Delay period for distribution
    uint256 public announcedDistributionTime; // When distribution can occur
    bool public distributionAnnounced = false; // Distribution announcement status
    uint256 public minHoldingPeriod = 1 days; // Minimum holding time for profit claims

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event ProfitDistributed(uint256 totalProfit, uint256 timestamp);

    /**
     * @dev Constructor that allocates the initial supply to the owner
     * @param initialOwner Address that will receive the total token supply
     */
    constructor(address initialOwner) Ownable(initialOwner) {
        balanceOf[initialOwner] = totalSupply;
    }

    /**
     * @dev Allows users to purchase tokens with ETH
     * @param amount Number of tokens to purchase (in token units with decimals)
     * @notice Excess ETH will be refunded to the sender
     */
    function buyTokens(uint256 amount) external payable {
        require(balanceOf[owner()] >= amount, "Not enough tokens available");
        uint256 cost = (amount * tokenPrice) / 10 ** 18;
        require(msg.value >= cost, "Insufficient ETH sent");

        balanceOf[owner()] -= amount;
        balanceOf[msg.sender] += amount;
        lastTransferTime[msg.sender] = block.timestamp;
        emit Transfer(owner(), msg.sender, amount);

        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost); // Refund excess ETH
        }
    }

    /**
     * @dev Announces upcoming profit distribution, starting the timelock period
     * @notice Only owner can call this function
     */
    function announceDistribution() external onlyOwner {
        announcedDistributionTime = block.timestamp + distributionDelay;
        distributionAnnounced = true;
    }

    /**
     * @dev Distributes profits to token holders by calculating profit per token
     * @notice Only owner can call this function
     * @notice Distribution must be announced first and timelock delay must pass
     * @notice Sent ETH will be distributed proportionally to token holders
     */
    function distributeProfit() external payable onlyOwner {
        require(distributionAnnounced, "Must announce distribution first");
        require(
            block.timestamp >= announcedDistributionTime,
            "Timelock delay not met"
        );
        require(msg.value > 0, "Must send ETH to distribute");
        require(totalSupply > 0, "No tokens issued");

        profitPerToken[currentRound] = (msg.value * 10 ** 18) / totalSupply;
        emit ProfitDistributed(msg.value, block.timestamp);
        currentRound++;
        distributionAnnounced = false;
    }

    /**
     * @dev Allows users to claim profits for a specific distribution round
     * @param round The distribution round to claim profits from
     * @notice User must hold tokens for minimum holding period before claiming
     * @notice Each round can only be claimed once per address
     */
    function claimProfit(uint256 round) external nonReentrant {
        require(round < currentRound, "Invalid or future round");
        require(
            !hasClaimed[msg.sender][round],
            "Profit already claimed for this round"
        );
        require(
            block.timestamp >= lastTransferTime[msg.sender] + minHoldingPeriod,
            "Must hold tokens for minimum period"
        );

        uint256 userTokens = balanceOf[msg.sender];
        uint256 profit = (userTokens * profitPerToken[round]) / 10 ** 18;
        
        // Fix reentrancy vulnerability by updating state before external call
        hasClaimed[msg.sender][round] = true;
        
        // Perform external call after state changes
        (bool success, ) = payable(msg.sender).call{value: profit}("");
        require(success, "ETH transfer failed");
    }

    /**
     * @dev Transfers tokens to another address
     * @param to The recipient address
     * @param value The amount of tokens to transfer
     * @return success True if the transfer was successful
     * @notice Updates last transfer time for both sender and recipient
     */
    function transfer(address to, uint256 value) external returns (bool) {
        require(to != address(0), "Cannot transfer to zero address");
        require(balanceOf[msg.sender] >= value, "Insufficient balance");

        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        lastTransferTime[msg.sender] = block.timestamp;
        lastTransferTime[to] = block.timestamp;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Approves a spender to transfer tokens on behalf of the caller
     * @param spender The address authorized to spend tokens
     * @param value The spending allowance granted
     * @return success True if the approval was successful
     */
    function approve(address spender, uint256 value) external returns (bool) {
        require(spender != address(0), "Cannot approve zero address");
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Transfers tokens from one address to another using allowance
     * @param from The address to transfer tokens from
     * @param to The address to transfer tokens to
     * @param value The amount of tokens to transfer
     * @return success True if the transfer was successful
     * @notice Updates last transfer time for both sender and recipient
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {
        require(from != address(0), "Cannot transfer from zero address");
        require(to != address(0), "Cannot transfer to zero address");
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Insufficient allowance");

        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        lastTransferTime[from] = block.timestamp;
        lastTransferTime[to] = block.timestamp;
        emit Transfer(from, to, value);
        return true;
    }

    /**
     * @dev Allows owner to withdraw any excess ETH from the contract
     * @notice Only owner can call this function
     */
    function withdrawExcess() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}