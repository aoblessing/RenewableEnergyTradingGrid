;; Energy Credit Token Contract
;; Handles the creation, transfer, and management of renewable energy credits

(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))

;; Data Variables
(define-data-var total-credits uint u0)
(define-map credit-balances principal uint)
(define-map energy-providers principal bool)

;; Energy Credit Properties
(define-map credit-metadata
    uint
    {
        producer: principal,
        energy-type: (string-ascii 20),
        timestamp: uint,
        amount: uint,
        grid-location: (string-ascii 50)
    }
)

;; Authorization Check
(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT-OWNER)
)

;; Energy Provider Management
(define-public (register-energy-provider (provider principal))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (ok (map-set energy-providers provider true))
    )
)

;; Credit Minting
(define-public (mint-credits (amount uint) (energy-type (string-ascii 20)) (grid-location (string-ascii 50)))
    (let 
        (
            (provider tx-sender)
            (current-total (var-get total-credits))
            (new-total (+ current-total amount))
        )
        (asserts! (map-get? energy-providers provider) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)

        ;; Update total supply
        (var-set total-credits new-total)

        ;; Update provider balance
        (map-set credit-balances 
            provider 
            (+ (default-to u0 (map-get? credit-balances provider)) amount)
        )

        ;; Store metadata
        (map-set credit-metadata current-total
            {
                producer: provider,
                energy-type: energy-type,
                timestamp: block-height,
                amount: amount,
                grid-location: grid-location
            }
        )

        (ok true)
    )
)

;; Credit Transfer
(define-public (transfer-credits (amount uint) (sender principal) (recipient principal))
    (let
        (
            (sender-balance (default-to u0 (map-get? credit-balances sender)))
        )
        (asserts! (or (is-eq tx-sender sender) (is-contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)

        ;; Update balances
        (map-set credit-balances
            sender
            (- sender-balance amount)
        )
        (map-set credit-balances
            recipient
            (+ (default-to u0 (map-get? credit-balances recipient)) amount)
        )

        (ok true)
    )
)

;; Getter Functions
(define-read-only (get-credit-balance (account principal))
    (ok (default-to u0 (map-get? credit-balances account)))
)

(define-read-only (get-credit-metadata (credit-id uint))
    (ok (map-get? credit-metadata credit-id))
)

(define-read-only (get-total-credits)
    (ok (var-get total-credits))
)

(define-read-only (is-energy-provider (provider principal))
    (ok (default-to false (map-get? energy-providers provider)))
)
