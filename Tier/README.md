# MetaverseExplorers Alliance NFT Membership Contract

This Clarity smart contract implements a tiered NFT membership system for the MetaverseExplorers Alliance on the Stacks blockchain.

## Overview

The contract creates a membership NFT system with four tiers (Novice, Explorer, Pioneer, Guardian) that provide increasing governance power and privileges within the community. Members can upgrade their tier by depositing STX tokens and maintaining them for specified time periods.

## Key Features

- **Tiered Membership**: Four membership levels with increasing privileges
- **STX Staking**: Lock STX tokens to upgrade membership tier
- **Achievement System**: Earn badges by participating in community activities
- **Governance Weight**: Higher tiers receive more voting power
- **Transferable NFTs**: Membership tokens can be transferred between users

## Membership Tiers

| Tier | Deposit Requirement | Time Lock | Governance Weight |
|------|---------------------|-----------|------------------|
| Novice | 150 STX (mint fee) | None | 1x |
| Explorer | 1,500 STX | 3 months | 3x |
| Pioneer | 3,000 STX | 6 months | 5x |
| Guardian | 6,000 STX | 12 months | 10x |

## Achievement Badges

Members can earn special badges by participating in community activities:
- **Quest Master**: Complete at least 8 quests
- **Battle Champion**: Participate in at least 5 battles
- **Network Builder**: Invite at least 15 new members
- **Resource Provider**: Contribute at least 25 resources

## Usage

### For Members
1. Call `mint()` to create your Novice membership (costs 150 STX)
2. Deposit STX using `deposit(amount, duration)` to prepare for tier upgrades
3. After the time lock period, call `upgrade-tier(token-id)` to advance to the next tier
4. Record achievements with `record-achievement(token-id, achievement-type)`
5. Transfer your membership with `transfer(token-id, recipient)`

### For Developers
- Query membership status with `get-token-tier` and `get-token-badges`
- Determine governance weight with `get-governance-weight`
- Verify token ownership with `get-owner`

## Implementation Details

This contract adheres to semi-fungible token (SFT) principles with custom logic for tier upgrades based on STX deposits. The system uses Clarity maps to track ownership, tiers, deposits, and achievements.