;; Energy Credit Token Contract
;; Handles the creation, transfer, and management of renewable energy credits

;; Error Codes
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-INVALID-GRID (err u104))
(define-constant ERR-PROVIDER-ALREADY-EXISTS (err u105))
(define-constant ERR-INVALID-RECIPIENT (err u106))
(define-constant ERR-INVALID-ENERGY-TYPE (err u107))
(define-constant ERR-TRANSFER-TO-SELF (err u108))
(define-constant ERR-ZERO-AMOUNT (err u109))

;; Data Maps and Variables
(define-data-var total-supply uint u0)
(define-map balances principal uint)
(define-map energy-providers 
    principal 
    {
        is-active: bool,
        grid-location: (string-ascii 50),
        registration-height: uint
    }
)

;; Energy Types
(define-map valid-energy-types (string-ascii 20) bool)

;; Energy Credit Structure
(define-map credits 
    uint 
    {
        producer: principal,
        amount: uint,
        timestamp: uint,
        grid-location: (string-ascii 50),
        energy-type: (string-ascii 20),
        status: (string-ascii 10)  ;; "active" or "consumed"
    }
)

;; Authorization Functions
(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-valid-provider (provider principal))
    (match (map-get? energy-providers provider)
        provider-data (get is-active provider-data)
        false
    )
)

(define-private (is-valid-energy-type (energy-type (string-ascii 20)))
    (default-to false (map-get? valid-energy-types energy-type))
)

(define-private (validate-grid-location (location (string-ascii 50)))
    (not (is-eq location ""))
)

;; Provider Management
(define-public (register-provider (provider principal) (grid-location (string-ascii 50)))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (validate-grid-location grid-location) ERR-INVALID-GRID)
        (asserts! (is-none (map-get? energy-providers provider)) ERR-PROVIDER-ALREADY-EXISTS)
        
        (ok (map-set energy-providers 
            provider 
            {
                is-active: true,
                grid-location: grid-location,
                registration-height: block-height
            }))
    )
)

;; Energy Type Management
(define-public (add-valid-energy-type (energy-type (string-ascii 20)))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (ok (map-set valid-energy-types energy-type true))
    )
)

;; Credit Management Functions
(define-public (mint-credits (amount uint) (energy-type (string-ascii 20)))
    (let 
        (
            (provider tx-sender)
            (current-total (var-get total-supply))
            (provider-data (unwrap! (map-get? energy-providers provider) ERR-NOT-AUTHORIZED))
        )
        ;; Assertions
        (asserts! (is-valid-provider provider) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-ZERO-AMOUNT)
        (asserts! (is-valid-energy-type energy-type) ERR-INVALID-ENERGY-TYPE)
        
        ;; Update total supply
        (var-set total-supply (+ current-total u1))
        
        ;; Update provider balance
        (map-set balances 
            provider 
            (+ (default-to u0 (map-get? balances provider)) amount)
        )
        
        ;; Store credit data
        (map-set credits current-total
            {
                producer: provider,
                amount: amount,
                timestamp: block-height,
                grid-location: (get grid-location provider-data),
                energy-type: energy-type,
                status: "active"
            }
        )
        
        (ok current-total)
    )
)

(define-public (transfer (recipient principal) (amount uint))
    (let
        (
            (sender tx-sender)
            (sender-balance (default-to u0 (map-get? balances sender)))
        )
        ;; Input validation
        (asserts! (not (is-eq sender recipient)) ERR-TRANSFER-TO-SELF)
        (asserts! (> amount u0) ERR-ZERO-AMOUNT)
        (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
        (asserts! (is-some (map-get? energy-providers recipient)) ERR-INVALID-RECIPIENT)
        
        ;; Update balances
        (try! (decrease-balance sender amount))
        (try! (increase-balance recipient amount))
        
        (ok true)
    )
)

;; Helper Functions for Balance Management
(define-private (decrease-balance (account principal) (amount uint))
    (let
        ((current-balance (default-to u0 (map-get? balances account))))
        (map-set balances account (- current-balance amount))
        (ok true)
    )
)

(define-private (increase-balance (account principal) (amount uint))
    (let
        ((current-balance (default-to u0 (map-get? balances account))))
        (map-set balances account (+ current-balance amount))
        (ok true)
    )
)

;; Getter Functions
(define-read-only (get-balance (account principal))
    (ok (default-to u0 (map-get? balances account)))
)

(define-read-only (get-total-supply)
    (ok (var-get total-supply))
)

(define-read-only (get-credit-info (credit-id uint))
    (ok (map-get? credits credit-id))
)

(define-read-only (get-provider-info (provider principal))
    (ok (map-get? energy-providers provider))
)

(define-read-only (is-energy-type-valid (energy-type (string-ascii 20)))
    (ok (is-valid-energy-type energy-type))
)
