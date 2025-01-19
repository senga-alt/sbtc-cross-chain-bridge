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

(define-read-only (is-contract-paused)
    (var-get contract-paused)
)

(define-read-only (calculate-fee (amount uint))
    (/ (* amount (var-get bridge-fee-percentage)) u1000)
)

(define-read-only (is-withdrawal-processed (tx-hash (buff 32)))
    (match (map-get? pending-withdrawals 
        {
            tx-hash: tx-hash,
            recipient: contract-caller,
            amount: u0,
            timestamp: u0
        })
        processed processed
        false
    )
)

;; Private functions
(define-private (validate-amount (amount uint))
    (if (and 
            (>= amount MIN-DEPOSIT)
            (<= amount MAX-DEPOSIT)
        )
        (ok true)
        ERR-INVALID-AMOUNT
    )
)

(define-private (update-user-balance (user principal) (amount uint))
    (let ((current-amount (get-user-bridged-amount user)))
        (map-set bridged-amounts 
            user 
            (+ current-amount amount)
        )
    )
)

;; Public functions
(define-public (deposit (token <ft-trait>) (amount uint) (recipient principal))
    (begin
        (asserts! (not (var-get contract-paused)) ERR-BRIDGE-PAUSED)
        (asserts! (is-eq (contract-of token) (var-get token-contract)) ERR-INVALID-TOKEN)
        (try! (validate-amount amount))
        
        ;; Transfer sBTC from user to contract
        (try! (contract-call? token transfer 
            amount 
            tx-sender 
            (as-contract tx-sender)
            none  ;; No memo needed
        ))
        
        ;; Update state
        (update-user-balance recipient amount)
        (var-set total-bridged-amount (+ (var-get total-bridged-amount) amount))
        
        ;; Emit bridge deposit event
        (print {
            event: "bridge-deposit",
            amount: amount,
            sender: tx-sender,
            recipient: recipient,
            timestamp: block-height
        })
        
        (ok true)
    )
)

(define-public (withdraw (token <ft-trait>) (tx-hash (buff 32)) (amount uint))
    (begin
        (asserts! (not (var-get contract-paused)) ERR-BRIDGE-PAUSED)
        (asserts! (is-eq (contract-of token) (var-get token-contract)) ERR-INVALID-TOKEN)
        (asserts! (not (is-withdrawal-processed tx-hash)) ERR-ALREADY-PROCESSED)
        (try! (validate-amount amount))
        
        (let (
            (fee (calculate-fee amount))
            (net-amount (- amount fee))
        )
            ;; Check if user has sufficient balance
            (asserts! (>= (get-user-bridged-amount tx-sender) amount) ERR-INSUFFICIENT-BALANCE)
            
            ;; Transfer sBTC from contract to user
            (try! (as-contract (contract-call? token transfer
                net-amount
                tx-sender
                tx-sender
                none  ;; No memo needed
            )))
            
            ;; Update state
            (map-set pending-withdrawals 
                {
                    tx-hash: tx-hash,
                    recipient: tx-sender,
                    amount: amount,
                    timestamp: block-height
                }
                true
            )
            
            ;; Update user balance
            (map-set bridged-amounts 
                tx-sender 
                (- (get-user-bridged-amount tx-sender) amount)
            )
            
            ;; Emit withdrawal event
            (print {
                event: "bridge-withdrawal",
                tx-hash: tx-hash,
                amount: amount,
                fee: fee,
                recipient: tx-sender,
                timestamp: block-height
            })
            
            (ok true)
        )
    )
)

;; Admin functions
(define-public (set-bridge-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set bridge-fee-percentage new-fee)
        (ok true)
    )
)

(define-public (set-token-contract (new-token-contract principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set token-contract new-token-contract)
        (ok true)
    )
)

(define-public (toggle-contract-pause)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set contract-paused (not (var-get contract-paused)))
        (ok true)
    )
)

(define-public (recover-funds (token <ft-trait>) (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (contract-of token) (var-get token-contract)) ERR-INVALID-TOKEN)
        (try! (as-contract (contract-call? token transfer
            amount
            tx-sender
            CONTRACT-OWNER
            none  ;; No memo needed
        )))
        (ok true)
    )
)