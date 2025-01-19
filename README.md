# Secure Bitcoin Bridge (sBTC) Smart Contract

A trustless cross-chain bridge enabling secure Bitcoin to Stacks blockchain transfers through sBTC, implementing the SIP-010 fungible token standard.

## Overview

The sBTC Bridge smart contract provides a secure and decentralized mechanism for bridging Bitcoin to the Stacks blockchain. It implements robust security features, rate limiting, fee management, and administrative controls while maintaining compliance with the SIP-010 fungible token standard.

## Features

- **Secure Deposits & Withdrawals**: Fully validated transfer mechanisms with multiple security checks
- **Rate Limiting**: Prevents excessive transfers within time periods
- **Fee Management**: Configurable fee structure with secure upper bounds
- **Administrative Controls**: Protected contract management functions
- **SIP-010 Compliance**: Full implementation of the fungible token standard
- **Security Measures**: Comprehensive validation for amounts, recipients, and transactions

## Technical Specifications

### Constants

- **Minimum Deposit**: 100 satoshis
- **Maximum Deposit**: 1 BTC (100,000,000 satoshis)
- **Maximum Fee**: 5% (50 basis points)
- **Rate Limit Period**: ~1 day (144 blocks)
- **Maximum Amount Per Period**: 10 BTC

### Error Codes

| Code | Description          |
| ---- | -------------------- |
| 100  | Not Authorized       |
| 101  | Invalid Amount       |
| 102  | Insufficient Balance |
| 103  | Bridge Paused        |
| 104  | Invalid Recipient    |
| 105  | Already Processed    |
| 106  | Invalid Token        |
| 107  | Rate Limit Exceeded  |
| 108  | Arithmetic Overflow  |
| 109  | Invalid Fee          |

## Core Functions

### Public Functions

#### `deposit`

```clarity
(define-public (deposit (token <ft-trait>) (amount uint) (recipient principal)))
```

Deposits sBTC into the bridge.

- Validates amount and recipient
- Transfers tokens from user to contract
- Updates user balance and total bridged amount
- Emits deposit event

#### `withdraw`

```clarity
(define-public (withdraw (token <ft-trait>) (tx-hash (buff 32)) (amount uint)))
```

Withdraws sBTC from the bridge.

- Validates transaction hasn't been processed
- Calculates and deducts fees
- Transfers tokens to recipient
- Updates state and emits withdrawal event

### Administrative Functions

#### `set-bridge-fee`

```clarity
(define-public (set-bridge-fee (new-fee uint)))
```

Sets the bridge fee percentage (restricted to contract owner).

#### `set-token-contract`

```clarity
(define-public (set-token-contract (new-token-contract principal)))
```

Updates the sBTC token contract address (restricted to contract owner).

#### `toggle-contract-pause`

```clarity
(define-public (toggle-contract-pause))
```

Enables/disables bridge operations (restricted to contract owner).

#### `recover-funds`

```clarity
(define-public (recover-funds (token <ft-trait>) (amount uint)))
```

Emergency function to recover funds (restricted to contract owner).

## Security Features

1. **Amount Validation**

   - Minimum and maximum deposit limits
   - Overflow protection
   - Rate limiting per user

2. **Recipient Validation**

   - Zero address protection
   - Contract address protection
   - Owner address protection

3. **Token Contract Validation**

   - SIP-010 compliance verification
   - Zero address protection
   - Contract address protection

4. **Fee Management**
   - Maximum fee cap
   - Secure fee calculations
   - Protected fee updates

## Events

The contract emits the following events:

### Bridge Deposit

```typescript
{
    event: "bridge-deposit",
    amount: uint,
    sender: principal,
    recipient: principal,
    timestamp: uint
}
```

### Bridge Withdrawal

```typescript
{
    event: "bridge-withdrawal",
    tx-hash: (buff 32),
    amount: uint,
    fee: uint,
    recipient: principal,
    timestamp: uint
}
```

## Usage Examples

### Depositing sBTC

```clarity
(contract-call? .sbtc-bridge deposit .sbtc-token u1000000 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### Withdrawing sBTC

```clarity
(contract-call? .sbtc-bridge withdraw .sbtc-token 0x1234... u1000000)
```

## Security Considerations

1. **Rate Limiting**

   - Prevents excessive transfers
   - Mitigates potential abuse
   - Time-based restrictions

2. **Access Control**

   - Owner-only administrative functions
   - Protected critical operations
   - Validated token operations

3. **State Management**

   - Secure balance updates
   - Protected withdrawal tracking
   - Safe arithmetic operations

4. **Emergency Controls**
   - Contract pause mechanism
   - Fund recovery function
   - Protected state modifications

## Best Practices

1. Always verify transaction status before initiating transfers
2. Implement proper error handling for failed transactions
3. Monitor bridge events for transaction tracking
4. Respect rate limits and maximum transfer amounts
5. Verify fee calculations before transactions

## Support

For support and questions, please open an issue in the repository or contact the development team.
