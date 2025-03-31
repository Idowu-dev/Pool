;; Tiered Community Membership NFT Contract
;; MetaverseExplorers Alliance Implementation

;; Constants for tiers
(define-constant NOVICE u1)
(define-constant EXPLORER u2)
(define-constant PIONEER u3)
(define-constant GUARDIAN u4)

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-TIER (err u101))
(define-constant ERR-INSUFFICIENT-FUNDS (err u102))
(define-constant ERR-ALREADY-MINTED (err u103))
(define-constant ERR-INSUFFICIENT-STAKE (err u104))
(define-constant ERR-LOCK-PERIOD-NOT-MET (err u105))
(define-constant ERR-INVALID-AMOUNT (err u106))
(define-constant ERR-INVALID-DURATION (err u107))
(define-constant ERR-INVALID-TOKEN-ID (err u108))

;; Data variables
(define-data-var contract-admin principal tx-sender)
(define-data-var nft-count uint u0)
(define-data-var metadata-base (string-ascii 256) "ipfs://QmAbc...")

;; Data maps
(define-map nft-tiers { token-id: uint } { tier: uint })
(define-map nft-owners { token-id: uint } { owner: principal })
(define-map deposits 
    { member: principal } 
    { amount: uint, start-block: uint, duration: uint })
(define-map achievements 
    { user: principal } 
    { quests: uint, battles: uint, invites: uint, resources: uint })
(define-map tier-thresholds 
    { tier: uint }
    { deposit-amount: uint, time-period: uint })
(define-map governance-weight
    { tier: uint }
    { power: uint })
(define-map badges
    { token-id: uint }
    { 
        quest-master: bool,
        battle-champion: bool,
        network-builder: bool,
        resource-provider: bool
    })

;; Initialize contract
(begin
    ;; Set tier thresholds
    (map-set tier-thresholds { tier: EXPLORER }
        { deposit-amount: u1500000000, time-period: u4320 }) ;; 1500 STX, 3 months
    (map-set tier-thresholds { tier: PIONEER }
        { deposit-amount: u3000000000, time-period: u8640 }) ;; 3000 STX, 6 months
    (map-set tier-thresholds { tier: GUARDIAN }
        { deposit-amount: u6000000000, time-period: u17280 }) ;; 6000 STX, 12 months
    
    ;; Set governance weight values
    (map-set governance-weight { tier: NOVICE } { power: u1 })
    (map-set governance-weight { tier: EXPLORER } { power: u3 })
    (map-set governance-weight { tier: PIONEER } { power: u5 })
    (map-set governance-weight { tier: GUARDIAN } { power: u10 })
)

;; SFT Mint function - Initial Novice membership
(define-public (mint)
    (let
        (
            (token-id (+ (var-get nft-count) u1))
            (caller tx-sender)
        )
        (asserts! (is-none (get owner (map-get? nft-owners { token-id: token-id }))) ERR-ALREADY-MINTED)
        (try! (stx-transfer? u150000000 caller (var-get contract-admin))) ;; 150 STX mint fee
        (map-set nft-owners { token-id: token-id } { owner: caller })
        (map-set nft-tiers { token-id: token-id } { tier: NOVICE })
        (map-set badges { token-id: token-id }
            { 
                quest-master: false,
                battle-champion: false,
                network-builder: false,
                resource-provider: false
            }
        )
        (var-set nft-count token-id)
        (ok token-id)
    )
)

;; Deposit STX for tier upgrade
(define-public (deposit (amount uint) (duration uint))
    (let
        (
            (caller tx-sender)
        )
        ;; Validate amount is greater than minimum deposit required for Explorer
        (asserts! (>= amount (get deposit-amount (unwrap! (map-get? tier-thresholds { tier: EXPLORER }) ERR-INVALID-TIER))) ERR-INVALID-AMOUNT)
        ;; Validate duration is at least minimum time period
        (asserts! (>= duration (get time-period (unwrap! (map-get? tier-thresholds { tier: EXPLORER }) ERR-INVALID-TIER))) ERR-INVALID-DURATION)
        
        (try! (stx-transfer? amount caller (as-contract tx-sender)))
        (map-set deposits { member: caller }
            { 
                amount: amount,
                start-block: block-height,
                duration: duration
            }
        )
        (ok true)
    )
)

;; Upgrade tier based on deposit and time
(define-public (upgrade-tier (token-id uint))
    (let
        (
            (caller tx-sender)
        )
        ;; Validate token exists
        (asserts! (<= token-id (var-get nft-count)) ERR-INVALID-TOKEN-ID)
        (let
            (
                (current-tier (unwrap! (get tier (map-get? nft-tiers { token-id: token-id })) ERR-INVALID-TIER))
                (deposit-info (unwrap! (map-get? deposits { member: caller }) ERR-INSUFFICIENT-STAKE))
                (next-tier (+ current-tier u1))
                (tier-req (unwrap! (map-get? tier-thresholds { tier: next-tier }) ERR-INVALID-TIER))
            )
            (asserts! (>= (get amount deposit-info) (get deposit-amount tier-req)) ERR-INSUFFICIENT-STAKE)
            (asserts! (>= (- block-height (get start-block deposit-info)) (get time-period tier-req)) ERR-LOCK-PERIOD-NOT-MET)
            (map-set nft-tiers { token-id: token-id } { tier: next-tier })
            (ok true)
        )
    )
)

;; Record alliance achievements
(define-public (record-achievement (token-id uint) (achievement-type (string-ascii 20)))
    (let
        (
            (caller tx-sender)
        )
        ;; Validate token exists
        (asserts! (<= token-id (var-get nft-count)) ERR-INVALID-TOKEN-ID)
        (let 
            (
                (current-achievements (default-to 
                    { quests: u0, battles: u0, invites: u0, resources: u0 }
                    (map-get? achievements { user: caller })))
            )
            (asserts! (is-eq caller (get owner (unwrap! (map-get? nft-owners { token-id: token-id }) ERR-UNAUTHORIZED))) ERR-UNAUTHORIZED)
            
            ;; Validate achievement type
            (asserts! (or 
                (is-eq achievement-type "quest")
                (is-eq achievement-type "battle")
                (is-eq achievement-type "invite")
                (is-eq achievement-type "resource")) 
                ERR-INVALID-TIER)

            ;; Update achievements based on type
            (if (is-eq achievement-type "quest")
                (map-set achievements { user: caller }
                    (merge current-achievements { quests: (+ (get quests current-achievements) u1) }))
                (if (is-eq achievement-type "battle")
                    (map-set achievements { user: caller }
                        (merge current-achievements { battles: (+ (get battles current-achievements) u1) }))
                    (if (is-eq achievement-type "invite")
                        (map-set achievements { user: caller }
                            (merge current-achievements { invites: (+ (get invites current-achievements) u1) }))
                        (map-set achievements { user: caller }
                            (merge current-achievements { resources: (+ (get resources current-achievements) u1) })))))
            
            (try! (check-and-update-badges token-id))
            (ok true)
        )
    )
)

;; Check and update badges based on achievements
(define-private (check-and-update-badges (token-id uint))
    (let
        (
            (caller tx-sender)
            (current-achievements (unwrap! (map-get? achievements { user: caller }) ERR-UNAUTHORIZED))
            (current-badges (unwrap! (map-get? badges { token-id: token-id }) ERR-UNAUTHORIZED))
        )
        (map-set badges { token-id: token-id }
            {
                quest-master: (or (get quest-master current-badges) (>= (get quests current-achievements) u8)),
                battle-champion: (or (get battle-champion current-badges) (>= (get battles current-achievements) u5)),
                network-builder: (or (get network-builder current-badges) (>= (get invites current-achievements) u15)),
                resource-provider: (or (get resource-provider current-badges) (>= (get resources current-achievements) u25))
            }
        )
        (ok true)
    )
)

;; Get governance weight for a token
(define-public (get-governance-weight (token-id uint))
    (let
        (
            (tier (unwrap! (get tier (map-get? nft-tiers { token-id: token-id })) ERR-INVALID-TIER))
            (weight (unwrap! (map-get? governance-weight { tier: tier }) ERR-INVALID-TIER))
        )
        (ok (get power weight))
    )
)

;; Transfer token
(define-public (transfer (token-id uint) (recipient principal))
    (let
        (
            (caller tx-sender)
        )
        ;; Validate token exists
        (asserts! (<= token-id (var-get nft-count)) ERR-INVALID-TOKEN-ID)
        ;; Validate recipient is not the zero address
        (asserts! (not (is-eq recipient (as-contract tx-sender))) ERR-UNAUTHORIZED)
        
        (let
            (
                (owner-data (unwrap! (map-get? nft-owners { token-id: token-id }) ERR-UNAUTHORIZED))
            )
            (asserts! (is-eq caller (get owner owner-data)) ERR-UNAUTHORIZED)
            (map-set nft-owners { token-id: token-id } { owner: recipient })
            (ok true)
        )
    )
)

;; Read-only functions
(define-read-only (get-token-tier (token-id uint))
    (get tier (map-get? nft-tiers { token-id: token-id }))
)

(define-read-only (get-token-badges (token-id uint))
    (map-get? badges { token-id: token-id })
)

(define-read-only (get-token-uri (token-id uint))
    (let
        (
            (id-string (concat 
                        (concat 
                            (concat
                                (concat
                                    (concat
                                        (concat
                                            (concat "" 
                                                (if (>= token-id u1000000000) (int-to-ascii (/ token-id u1000000000)) ""))
                                            (if (>= token-id u100000000) (int-to-ascii (/ (mod token-id u1000000000) u100000000)) ""))
                                        (if (>= token-id u10000000) (int-to-ascii (/ (mod token-id u100000000) u10000000)) ""))
                                    (if (>= token-id u1000000) (int-to-ascii (/ (mod token-id u10000000) u1000000)) ""))
                                (if (>= token-id u100000) (int-to-ascii (/ (mod token-id u1000000) u100000)) ""))
                            (if (>= token-id u10000) (int-to-ascii (/ (mod token-id u100000) u10000)) ""))
                        (if (>= token-id u1000) (int-to-ascii (/ (mod token-id u10000) u1000)) ""))
            )
        )
        (some (concat (concat (var-get metadata-base) id-string)
            (concat
                (concat
                    (if (>= token-id u100) (int-to-ascii (/ (mod token-id u1000) u100)) "")
                    (if (>= token-id u10) (int-to-ascii (/ (mod token-id u100) u10)) ""))
                (int-to-ascii (mod token-id u10))
            )
        ))
    )
)

(define-read-only (get-owner (token-id uint))
    (get owner (map-get? nft-owners { token-id: token-id }))
)