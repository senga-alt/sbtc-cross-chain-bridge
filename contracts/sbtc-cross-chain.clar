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
(define-constant ERR-RATE-LIMIT (err u107))
(define-constant ERR-OVERFLOW (err u108))
(define-constant ERR-INVALID-FEE (err u109))

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MIN-DEPOSIT u100) ;; Minimum deposit amount in sats
(define-constant MAX-DEPOSIT u100000000) ;; Maximum deposit amount in sats
(define-constant MAX-FEE-PERCENTAGE u50) ;; 5%
(define-constant ZERO-ADDRESS 'SP000000000000000000002Q6VF78)
(define-constant RATE-LIMIT-PERIOD u144) ;; ~1 day in blocks
(define-constant MAX-AMOUNT-PER-PERIOD u1000000000) ;; 10 BTC


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

;; Rate limiting map
(define-map user-period-amounts
    { user: principal, period: uint }
    uint
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
(define-private (validate-amount-secure (amount uint))
    (begin
        ;; Check basic bounds
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (>= amount MIN-DEPOSIT) ERR-INVALID-AMOUNT)
        (asserts! (<= amount MAX-DEPOSIT) ERR-INVALID-AMOUNT)
        
        ;; Check for overflow in total amount
        (let (
            (new-total (try! (safe-add (var-get total-bridged-amount) amount)))
        )
            ;; Check rate limiting
            (let (
                (current-period (/ block-height RATE-LIMIT-PERIOD))
                (period-amount (default-to u0 (map-get? user-period-amounts { user: tx-sender, period: current-period })))
                (new-period-amount (try! (safe-add period-amount amount)))
            )
                (asserts! (<= new-period-amount MAX-AMOUNT-PER-PERIOD) ERR-RATE-LIMIT)
                (ok true)
            )
        )
    )
)

;; Enhanced recipient validation with additional checks
(define-private (validate-recipient-secure (recipient principal))
    (begin
        (asserts! (not (is-eq recipient ZERO-ADDRESS)) ERR-INVALID-RECIPIENT)
        (asserts! (not (is-eq recipient (as-contract tx-sender))) ERR-INVALID-RECIPIENT)
        (asserts! (not (is-eq recipient CONTRACT-OWNER)) ERR-INVALID-RECIPIENT)
        (ok true)
    )
)

;; Enhanced recipient validation
(define-private (validate-recipient (recipient principal))
    (begin
        (asserts! (not (is-eq recipient ZERO-ADDRESS)) ERR-INVALID-RECIPIENT)
        (asserts! (not (is-eq recipient (as-contract tx-sender))) ERR-INVALID-RECIPIENT)
        (ok true)
    )
)

;; Enhanced token contract validation
(define-private (validate-token-contract-secure (new-token principal))
    (begin
        (asserts! (not (is-eq new-token ZERO-ADDRESS)) ERR-INVALID-TOKEN)
        (asserts! (not (is-eq new-token (as-contract tx-sender))) ERR-INVALID-TOKEN)
        ;; Could add additional checks here for known token contract patterns
        (ok true)
    )
)

;; Enhanced fee validation
(define-private (validate-fee-secure (new-fee uint))
    (begin
        (asserts! (<= new-fee MAX-FEE-PERCENTAGE) ERR-INVALID-FEE)
        (asserts! (>= new-fee u0) ERR-INVALID-FEE)
        (ok true)
    )
)


;; Safe math for balance updates
(define-private (safe-add (a uint) (b uint))
    (let ((sum (+ a b)))
        (asserts! (>= sum a) ERR-OVERFLOW)
        (ok sum)
    )
)

;; Enhanced update balance function
(define-private (update-user-balance-secure (user principal) (amount uint))
    (let (
        (current-amount (get-user-bridged-amount user))
        (current-period (/ block-height RATE-LIMIT-PERIOD))
    )
        ;; Update rate limiting
        (map-set user-period-amounts
            { user: user, period: current-period }
            (+ (default-to u0 (map-get? user-period-amounts { user: user, period: current-period })) amount)
        )
        
        ;; Safe balance update
        (map-set bridged-amounts 
            user 
            (try! (safe-add current-amount amount))
        )
        (ok true)
    )
)

;; Enhanced admin parameter validation
(define-private (validate-fee-percentage (new-fee uint))
    (begin
        (asserts! (<= new-fee MAX-FEE-PERCENTAGE) ERR-INVALID-FEE)
        (ok true)
    )
)

;; Enhanced token contract validation
(define-private (validate-token-contract (new-token <ft-trait>))
    (begin
        ;; Try to get token metadata to verify it implements SIP-010
        (try! (contract-call? new-token get-name))
        (try! (contract-call? new-token get-symbol))
        (try! (contract-call? new-token get-decimals))
        
        ;; Additional checks could be added here
        ;; For example, verify decimals matches expected value
        (ok true)
    )
)

;; Public functions
(define-public (deposit (token <ft-trait>) (amount uint) (recipient principal))
    (begin
    
        (asserts! (not (var-get contract-paused)) ERR-BRIDGE-PAUSED)
        (asserts! (is-eq (contract-of token) (var-get token-contract)) ERR-INVALID-TOKEN)
        (try! (validate-amount-secure amount))  ;; Fixed function name here
        
        ;; Transfer sBTC from user to contract
        (try! (contract-call? token transfer 
            amount 
            tx-sender 
            (as-contract tx-sender)
            none  ;; No memo needed
        ))
        
        ;; Update state
        (try! (update-user-balance-secure recipient amount))  ;; Updated to use secure version
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
        (try! (validate-amount-secure amount))
        
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
        (try! (validate-fee-secure new-fee))
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