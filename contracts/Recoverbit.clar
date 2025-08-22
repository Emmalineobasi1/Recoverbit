(define-fungible-token recoverbit)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INSUFFICIENT_BALANCE (err u403))
(define-constant ERR_INVALID_AMOUNT (err u400))
(define-constant ERR_ALREADY_CHECKED_IN (err u409))
(define-constant ERR_TOO_EARLY (err u410))
(define-constant ERR_NOT_VERIFIED (err u411))

(define-constant MIN_CHECK_IN_INTERVAL u144)
(define-constant BASE_REWARD u100)
(define-constant STREAK_MULTIPLIER u10)
(define-constant MAX_STREAK u30)

(define-data-var total-supply uint u0)
(define-data-var check-in-enabled bool true)

(define-map user-balances principal uint)
(define-map user-check-ins principal {
  last-check-in: uint,
  streak: uint,
  total-check-ins: uint,
  verified: bool
})

(define-map verifiers principal bool)
(define-map pending-verifications principal {
  user: principal,
  check-in-block: uint,
  submitted-at: uint
})

(define-public (initialize)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (try! (ft-mint? recoverbit u10000 CONTRACT_OWNER))
    (var-set total-supply u10000)
    (map-set user-balances CONTRACT_OWNER u10000)
    (ok true)))

(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set verifiers verifier true)
    (ok true)))

(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-delete verifiers verifier)
    (ok true)))

(define-public (toggle-check-in-system)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set check-in-enabled (not (var-get check-in-enabled)))
    (ok (var-get check-in-enabled))))

(define-public (check-in)
  (let ((current-block stacks-block-height)
        (user-info (default-to 
          {last-check-in: u0, streak: u0, total-check-ins: u0, verified: false}
          (map-get? user-check-ins tx-sender))))
    (begin
      (asserts! (var-get check-in-enabled) ERR_UNAUTHORIZED)
      (asserts! (>= current-block (+ (get last-check-in user-info) MIN_CHECK_IN_INTERVAL)) ERR_TOO_EARLY)
      (let ((new-streak (if (<= (- current-block (get last-check-in user-info)) (* MIN_CHECK_IN_INTERVAL u2))
                           (if (< (+ (get streak user-info) u1) MAX_STREAK)
                               (+ (get streak user-info) u1)
                               MAX_STREAK)
                           u1)))
        (map-set user-check-ins tx-sender {
          last-check-in: current-block,
          streak: new-streak,
          total-check-ins: (+ (get total-check-ins user-info) u1),
          verified: false
        })
        (ok new-streak)))))

(define-public (submit-for-verification (user principal))
  (let ((user-info (unwrap! (map-get? user-check-ins user) ERR_NOT_FOUND)))
    (begin
      (asserts! (default-to false (map-get? verifiers tx-sender)) ERR_UNAUTHORIZED)
      (asserts! (not (get verified user-info)) ERR_ALREADY_CHECKED_IN)
      (map-set pending-verifications user {
        user: user,
        check-in-block: (get last-check-in user-info),
        submitted-at: stacks-block-height
      })
      (ok true))))

(define-public (verify-check-in (user principal))
  (let ((verification (unwrap! (map-get? pending-verifications user) ERR_NOT_FOUND))
        (user-info (unwrap! (map-get? user-check-ins user) ERR_NOT_FOUND)))
    (begin
      (asserts! (default-to false (map-get? verifiers tx-sender)) ERR_UNAUTHORIZED)
      (asserts! (not (get verified user-info)) ERR_ALREADY_CHECKED_IN)
      (let ((reward-amount (calculate-reward (get streak user-info))))
        (try! (mint-tokens user reward-amount))
        (map-set user-check-ins user (merge user-info {verified: true}))
        (map-delete pending-verifications user)
        (ok reward-amount)))))

(define-public (reject-verification (user principal))
  (begin
    (asserts! (default-to false (map-get? verifiers tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? pending-verifications user)) ERR_NOT_FOUND)
    (map-delete pending-verifications user)
    (let ((user-info (unwrap! (map-get? user-check-ins user) ERR_NOT_FOUND)))
      (map-set user-check-ins user (merge user-info {
        streak: u0,
        total-check-ins: (- (get total-check-ins user-info) u1)
      }))
      (ok true))))

(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (let ((sender-balance (default-to u0 (map-get? user-balances sender))))
    (begin
      (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
      (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_BALANCE)
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (try! (ft-transfer? recoverbit amount sender recipient))
      (map-set user-balances sender (- sender-balance amount))
      (map-set user-balances recipient (+ (default-to u0 (map-get? user-balances recipient)) amount))
      (ok true))))

(define-public (burn (amount uint))
  (let ((user-balance (default-to u0 (map-get? user-balances tx-sender))))
    (begin
      (asserts! (>= user-balance amount) ERR_INSUFFICIENT_BALANCE)
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (try! (ft-burn? recoverbit amount tx-sender))
      (map-set user-balances tx-sender (- user-balance amount))
      (var-set total-supply (- (var-get total-supply) amount))
      (ok true))))

(define-public (emergency-mint (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (mint-tokens recipient amount))
    (ok true)))

(define-private (mint-tokens (recipient principal) (amount uint))
  (begin
    (try! (ft-mint? recoverbit amount recipient))
    (map-set user-balances recipient (+ (default-to u0 (map-get? user-balances recipient)) amount))
    (var-set total-supply (+ (var-get total-supply) amount))
    (ok true)))

(define-private (calculate-reward (streak uint))
  (+ BASE_REWARD (* streak STREAK_MULTIPLIER)))

(define-read-only (get-balance (user principal))
  (default-to u0 (map-get? user-balances user)))

(define-read-only (get-user-info (user principal))
  (map-get? user-check-ins user))

(define-read-only (get-verification-status (user principal))
  (map-get? pending-verifications user))

(define-read-only (is-verifier (user principal))
  (default-to false (map-get? verifiers user)))

(define-read-only (get-total-supply)
  (var-get total-supply))

(define-read-only (get-check-in-enabled)
  (var-get check-in-enabled))

(define-read-only (can-check-in (user principal))
  (let ((user-info (map-get? user-check-ins user)))
    (match user-info
      info (>= stacks-block-height (+ (get last-check-in info) MIN_CHECK_IN_INTERVAL))
      true)))

(define-read-only (get-next-reward (user principal))
  (let ((user-info (map-get? user-check-ins user)))
    (match user-info
      info (calculate-reward (+ (get streak info) u1))
      BASE_REWARD)))

(define-read-only (get-streak-progress (user principal))
  (let ((user-info (map-get? user-check-ins user)))
    (match user-info
      info {
        current-streak: (get streak info),
        total-check-ins: (get total-check-ins info),
        max-possible-streak: MAX_STREAK,
        blocks-until-next: (if (>= stacks-block-height (+ (get last-check-in info) MIN_CHECK_IN_INTERVAL))
                            u0
                            (- (+ (get last-check-in info) MIN_CHECK_IN_INTERVAL) stacks-block-height))
      }
      {current-streak: u0, total-check-ins: u0, max-possible-streak: MAX_STREAK, blocks-until-next: u0})))

(define-read-only (get-contract-info)
  {
    total-supply: (var-get total-supply),
    check-in-enabled: (var-get check-in-enabled),
    min-check-in-interval: MIN_CHECK_IN_INTERVAL,
    base-reward: BASE_REWARD,
    streak-multiplier: STREAK_MULTIPLIER,
    max-streak: MAX_STREAK,
    contract-owner: CONTRACT_OWNER
  })

