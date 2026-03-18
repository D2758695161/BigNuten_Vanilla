// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ─────────────────────────────────────────────────────────────────────────────
// BigNutens ($BNUT) — Governance & Rewards Token
// ─────────────────────────────────────────────────────────────────────────────
//
// Standard:   ERC-20 + ERC-20Votes + ERC-20Permit + AccessControl
// Supply:     Starts at 0. Minted on demand up to MAX_SUPPLY (1 billion).
// Network:    Optimism Mainnet
// Uses:       Governance voting, data-sharing rewards, bounty payouts,
//             competition prizes, subscription discounts, DNFT purchases.
//
// Roles:
//   DEFAULT_ADMIN_ROLE — TheJollyLaMa wallet (full control)
//   MINTER_ROLE        — DataSharing contract, BountyBot, Admin
//   PAUSER_ROLE        — Admin (emergency stop)
//
// Supply Allocation (advisory — enforced off-chain by admin):
//   400,000,000  (40%)  Community Rewards  — workouts, data sharing, prizes
//   200,000,000  (20%)  Dev Bounties       — GitHub contributors
//   200,000,000  (20%)  Treasury / DAO     — governance-controlled
//   100,000,000  (10%)  Founding Team      — TheJollyLaMa
//   100,000,000  (10%)  Early Supporters   — DNFT holders, airdrop
// ─────────────────────────────────────────────────────────────────────────────

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract BigNutens is
    ERC20,
    ERC20Burnable,
    ERC20Pausable,
    ERC20Permit,
    ERC20Votes,
    AccessControl
{
    // ── Roles ────────────────────────────────────────────────────────────────
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ── Supply Cap ───────────────────────────────────────────────────────────
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18; // 1 billion

    // ── Events ───────────────────────────────────────────────────────────────
    event TokensMinted(address indexed to, uint256 amount, string reason);
    event TokensBurned(address indexed from, uint256 amount);

    // ── Constructor ──────────────────────────────────────────────────────────
    constructor(address admin)
        ERC20("BigNutens", "BNUT")
        ERC20Permit("BigNutens")
    {
        // Grant all roles to the deployer/admin wallet
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        // Note: totalSupply starts at 0. Mint via mintReward() as needed.
    }

    // ── Minting ──────────────────────────────────────────────────────────────

    /**
     * @notice Mint $BNUT to a recipient. Only MINTER_ROLE.
     * @param to      Recipient address.
     * @param amount  Amount in wei (multiply by 10**18 for whole tokens).
     * @param reason  Human-readable reason: "workout_reward", "bounty", "prize", etc.
     */
    function mintReward(
        address to,
        uint256 amount,
        string calldata reason
    ) external onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= MAX_SUPPLY, "BNUT: exceeds max supply");
        _mint(to, amount);
        emit TokensMinted(to, amount, reason);
    }

    /**
     * @notice Batch mint $BNUT to multiple recipients in one tx.
     *         Useful for monthly prize distributions, airdrops, bounty payouts.
     * @param recipients  Array of recipient addresses.
     * @param amounts     Array of amounts (must match recipients length).
     * @param reason      Shared reason string for all mints in this batch.
     */
    function batchMintReward(
        address[] calldata recipients,
        uint256[] calldata amounts,
        string calldata reason
    ) external onlyRole(MINTER_ROLE) {
        require(recipients.length == amounts.length, "BNUT: length mismatch");
        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        require(totalSupply() + total <= MAX_SUPPLY, "BNUT: exceeds max supply");
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
            emit TokensMinted(recipients[i], amounts[i], reason);
        }
    }

    // ── Pause ────────────────────────────────────────────────────────────────

    /// @notice Pause all transfers. Emergency use only.
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Unpause transfers.
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ── View Helpers ─────────────────────────────────────────────────────────

    /// @notice Remaining mintable supply.
    function remainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }

    // ── Required Overrides ───────────────────────────────────────────────────
    // OpenZeppelin requires these when inheriting multiple extensions.

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}