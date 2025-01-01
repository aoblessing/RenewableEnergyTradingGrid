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
