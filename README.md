# Recoverbit

A blockchain-based rehabilitation support system that rewards users with tokens for verified check-ins to encourage consistent recovery habits and accountability.

## Overview

Recoverbit is a Clarity smart contract that implements a token-based incentive system for rehabilitation and recovery programs. Users earn tokens by maintaining check-in streaks, with rewards scaling based on consistency. A verification system ensures accountability through trusted verifiers.

## Features

- **Token Rewards**: Earn Recoverbit tokens for verified check-ins
- **Streak System**: Higher rewards for maintaining consecutive check-ins
- **Verification Process**: Trusted verifiers confirm legitimate check-ins
- **Flexible Administration**: Owner can manage verifiers and system settings
- **Balance Management**: Transfer and burn tokens as needed

## Token Economics

- **Base Reward**: 100 tokens per verified check-in
- **Streak Multiplier**: +10 tokens per day in current streak
- **Maximum Streak**: 30 days (maximum 400 tokens per check-in)
- **Check-in Interval**: Minimum 144 blocks between check-ins (~24 hours)

## Contract Functions

### User Functions

#### `check-in`
Records a new check-in for the calling user.
- Must wait minimum interval between check-ins
- Maintains or resets streak based on timing
- Check-in must be verified to earn rewards

#### `transfer (amount, sender, recipient)`
Transfers tokens between users.
- Requires sender authorization
- Validates sufficient balance

#### `burn (amount)`
Burns tokens from caller's balance, reducing total supply.

### Verifier Functions

#### `submit-for-verification (user)`
Submits a user's check-in for verification (verifier only).

#### `verify-check-in (user)`
Approves a check-in and mints reward tokens (verifier only).

#### `reject-verification (user)`
Rejects a check-in, resetting user's streak (verifier only).

### Owner Functions

#### `initialize`
Initializes contract with 10,000 tokens to owner. Must be called once.

#### `add-verifier (verifier)`
Adds a trusted verifier to the system.

#### `remove-verifier (verifier)`
Removes a verifier from the system.

#### `toggle-check-in-system`
Enables/disables the check-in system.

#### `emergency-mint (recipient, amount)`
Emergency function to mint tokens directly.

### Read-Only Functions

#### `get-balance (user)`
Returns token balance for a user.

#### `get-user-info (user)`
Returns check-in information for a user including streak and verification status.

#### `get-verification-status (user)`
Returns pending verification details for a user.

#### `is-verifier (user)`
Checks if a user is an authorized verifier.

#### `can-check-in (user)`
Checks if a user is eligible to check in.

#### `get-next-reward (user)`
Calculates the reward amount for the user's next verified check-in.

#### `get-streak-progress (user)`
Returns detailed streak information and timing.

#### `get-contract-info`
Returns overall contract settings and statistics.

## Usage Example

### For Users
1. Call `check-in` when completing recovery activities
2. Wait for verifier to process your check-in
3. Receive tokens automatically upon verification
4. Maintain streaks for higher rewards

### For Verifiers
1. Monitor pending verifications
2. Use `submit-for-verification` to queue check-ins
3. Use `verify-check-in` to approve legitimate check-ins
4. Use `reject-verification` for invalid submissions

### For Contract Owner
1. Deploy contract and call `initialize`
2. Add trusted verifiers with `add-verifier`
3. Monitor system health through read-only functions
4. Use emergency functions only when necessary

## Deployment

1. Deploy the contract to Stacks blockchain
2. Call `initialize` function once
3. Add initial verifiers using `add-verifier`
4. System is ready for user check-ins

## Error Codes

- `u400`: Invalid amount
- `u401`: Unauthorized access
- `u403`: Insufficient balance
- `u404`: Record not found
- `u409`: Already checked in/verified
- `u410`: Too early for next check-in
- `u411`: Not verified

## Security Considerations

- Only authorized verifiers can approve check-ins
- Owner has administrative control but cannot directly manipulate user balances
- Check-in intervals prevent spam and abuse
- All token operations include proper balance validation

## Contributing

To extend this contract:
1. Maintain existing error handling patterns
2. Use consistent naming conventions
3. Add comprehensive read-only functions for new features
4. Test all functions thoroughly before deployment
