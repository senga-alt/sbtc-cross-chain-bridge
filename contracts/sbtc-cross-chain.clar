;; Title: Secure Bitcoin Bridge (sBTC)
;; Summary: A trustless cross-chain bridge for Bitcoin <-> Stacks transfers
;; Description: This contract enables secure and decentralized bridging of Bitcoin to Stacks blockchain
;; through sBTC, implementing deposit/withdrawal mechanisms with built-in security features,
;; fee management, and administrative controls. Supports SIP-010 fungible token standard.

;; Define SIP-010 Trait
(define-trait ft-trait
    (
        ;; Transfer from the caller to a new principal
        (transfer (uint principal principal (optional (buff 32))) (response bool uint))

        ;; Get the token balance of the passed principal
        (get-balance (principal) (response uint uint))

        ;; Get the total number of tokens
        (get-total-supply () (response uint uint))

        ;; Get the token name
        (get-name () (response (string-ascii 32) uint))

        ;; Get the token symbol
        (get-symbol () (response (string-ascii 32) uint))

        ;; Get the number of decimals
        (get-decimals () (response uint uint))

        ;; Get the URI containing token metadata
        (get-token-uri () (response (optional (string-utf8 256)) uint))
    )
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-BRIDGE-PAUSED (err u103))
(define-constant ERR-INVALID-RECIPIENT (err u104))
(define-constant ERR-ALREADY-PROCESSED (err u105))
(define-constant ERR-INVALID-TOKEN (err u106))

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MIN-DEPOSIT u100) ;; Minimum deposit amount in sats
(define-constant MAX-DEPOSIT u100000000) ;; Maximum deposit amount in sats

;; Data Variables
(define-data-var contract-paused bool false)
(define-data-var total-bridged-amount uint u0)
(define-data-var bridge-fee-percentage uint u1) ;; 0.1% default fee
(define-data-var token-contract principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sbtc-token)

;; Data Maps
(define-map bridged-amounts principal uint)
(define-map pending-withdrawals 
    {
        tx-hash: (buff 32),
        recipient: principal,
        amount: uint,
        timestamp: uint
    }
    bool
)

;; Read-only functions
(define-read-only (get-bridge-fee-percentage)
    (var-get bridge-fee-percentage)
)

(define-read-only (get-user-bridged-amount (user principal))
    (default-to u0 (map-get? bridged-amounts user))
)

(define-read-only (get-total-bridged-amount)
    (var-get total-bridged-amount)
)

(define-read-only (get-token-contract)
    (var-get token-contract)
)