;; Energy Credit Token Contract
;; Handles the creation, transfer, and management of renewable energy credits

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-INVALID-GRID (err u104))

;; Data Maps and Variables
(define-data-var total-supply uint u0)
(define-map balances principal uint)
(define-map energy-providers principal bool)
(define-map grid-locations principal (string-ascii 50))

;; Energy Credit Structure
(define-map credits 
    uint 
    {
        producer: principal,
        amount: uint,
        timestamp: uint,
        grid-location: (string-ascii 50),
        energy-type: (string-ascii 20)
    }
)

;; Authorization Functions
(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-valid-provider (provider principal))
    (default-to false (map-get? energy-providers provider))
)

;; Provider Management
(define-public (register-provider (provider principal) (grid-location (string-ascii 50)))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (map-set energy-providers provider true)
        (map-set grid-locations provider grid-location)
        (ok true)
    )
)

;; Credit Management Functions
(define-public (mint-credits (amount uint) (energy-type (string-ascii 20)))
    (let 
        (
            (provider tx-sender)
            (current-total (var-get total-supply))
            (grid-loc (default-to "" (map-get? grid-locations provider)))
        )
        ;; Assertions
        (asserts! (is-valid-provider provider) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (not (is-eq grid-loc "")) ERR-INVALID-GRID)

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
                grid-location: grid-loc,
                energy-type: energy-type
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
        ;; Assertions
        (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)

        ;; Update balances
        (map-set balances sender (- sender-balance amount))
        (map-set balances 
            recipient 
            (+ (default-to u0 (map-get? balances recipient)) amount)
        )

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

(define-read-only (get-provider-grid (provider principal))
    (ok (map-get? grid-locations provider))
)
