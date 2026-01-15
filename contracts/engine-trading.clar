;; Trading Engine Contract
;; Handles order matching and execution for energy credit trading

;; Error Codes
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u201))
(define-constant ERR-INVALID-PRICE (err u202))
(define-constant ERR-INVALID-AMOUNT (err u203))
(define-constant ERR-ORDER-NOT-FOUND (err u204))
(define-constant ERR-ORDER-ALREADY-FILLED (err u205))
(define-constant ERR-INSUFFICIENT-BALANCE (err u206))
(define-constant ERR-SAME-GRID-REQUIRED (err u207))
(define-constant ERR-INVALID-ORDER-STATUS (err u208))
(define-constant ERR-TRANSFER-FAILED (err u209))

;; Order Status Types
(define-constant STATUS-OPEN "open")
(define-constant STATUS-FILLED "filled")
(define-constant STATUS-CANCELLED "cancelled")

;; Order Types
(define-constant TYPE-BUY "buy")
(define-constant TYPE-SELL "sell")

;; Contract Variables
(define-data-var next-order-id uint u0)

;; Order Structure
(define-map orders
    uint
    {
        maker: principal,
        order-type: (string-ascii 4),
        amount: uint,
        price-per-unit: uint,
        grid-location: (string-ascii 50),
        status: (string-ascii 10),
        created-at: uint,
        filled-at: (optional uint)
    }
)

;; Grid Price Data
(define-map grid-prices
    (string-ascii 50)  ;; grid-location
    {
        last-price: uint,
        updated-at: uint
    }
)

;; Helper Functions
(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (get-next-order-id)
    (let
        ((current-id (var-get next-order-id)))
        (var-set next-order-id (+ current-id u1))
        current-id
    )
)

(define-private (update-order-status (order-id uint) (order-data { maker: principal, order-type: (string-ascii 4), amount: uint, price-per-unit: uint, grid-location: (string-ascii 50), status: (string-ascii 10), created-at: uint, filled-at: (optional uint) }))
    (begin
        (map-set orders order-id
            (merge order-data 
                {
                    status: STATUS-FILLED,
                    filled-at: (some block-height)
                }
            )
        )
        (map-set grid-prices (get grid-location order-data)
            {
                last-price: (get price-per-unit order-data),
                updated-at: block-height
            }
        )
        order-id
    )
)

;; Order Management
(define-public (create-sell-order (amount uint) (price-per-unit uint) (grid-location (string-ascii 50)))
    (let
        (
            (order-id (get-next-order-id))
        )
        ;; Validate order parameters
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (> price-per-unit u0) ERR-INVALID-PRICE)
        
        ;; Create the order
        (map-set orders order-id
            {
                maker: tx-sender,
                order-type: TYPE-SELL,
                amount: amount,
                price-per-unit: price-per-unit,
                grid-location: grid-location,
                status: STATUS-OPEN,
                created-at: block-height,
                filled-at: none
            }
        )
        
        ;; Return the order ID
        (ok order-id)
    )
)

(define-public (create-buy-order (amount uint) (price-per-unit uint) (grid-location (string-ascii 50)))
    (let
        (
            (order-id (get-next-order-id))
        )
        ;; Validate order parameters
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (> price-per-unit u0) ERR-INVALID-PRICE)
        
        ;; Create the order
        (map-set orders order-id
            {
                maker: tx-sender,
                order-type: TYPE-BUY,
                amount: amount,
                price-per-unit: price-per-unit,
                grid-location: grid-location,
                status: STATUS-OPEN,
                created-at: block-height,
                filled-at: none
            }
        )
        
        ;; Return the order ID
        (ok order-id)
    )
)

(define-public (cancel-order (order-id uint))
    (let
        (
            (order (unwrap! (map-get? orders order-id) ERR-ORDER-NOT-FOUND))
        )
        ;; Verify ownership and status
        (asserts! (is-eq (get maker order) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status order) STATUS-OPEN) ERR-INVALID-ORDER-STATUS)
        
        ;; Update order status
        (map-set orders order-id
            (merge order { status: STATUS-CANCELLED })
        )
        
        (ok order-id)
    )
)

(define-public (fill-order (order-id uint))
    (let
        (
            (order (unwrap! (map-get? orders order-id) ERR-ORDER-NOT-FOUND))
        )
        ;; Validate order status
        (asserts! (is-eq (get status order) STATUS-OPEN) ERR-INVALID-ORDER-STATUS)
        
        ;; Execute transfer based on order type
        (if (is-eq (get order-type order) TYPE-SELL)
            (begin
                (unwrap! (contract-call? .energy-credit transfer tx-sender (get amount order)) ERR-TRANSFER-FAILED)
                (ok (update-order-status order-id order))
            )
            (begin
                (unwrap! (contract-call? .energy-credit transfer (get maker order) (get amount order)) ERR-TRANSFER-FAILED)
                (ok (update-order-status order-id order))
            )
        )
    )
)
