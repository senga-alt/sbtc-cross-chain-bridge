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