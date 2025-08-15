;; Test Coverage Reporter Contract
;; Tracks test suites, test cases, and coverage metrics

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-test-suite (err u101))
(define-constant err-invalid-test-case (err u102))
(define-constant err-test-suite-not-found (err u103))
(define-constant err-test-case-not-found (err u104))
(define-constant err-invalid-coverage (err u105))
(define-constant err-unauthorized (err u106))

;; Data Variables
(define-data-var next-suite-id uint u1)
(define-data-var next-test-id uint u1)

;; Data Maps
(define-map test-suites
    { suite-id: uint }
    {
        name: (string-ascii 100),
        description: (string-ascii 500),
        creator: principal,
        total-tests: uint,
        passed-tests: uint,
        failed-tests: uint,
        coverage-percentage: uint,
        quality-score: uint,
        created-at: uint,
        last-updated: uint,
        is-active: bool
    }
)

(define-map test-cases
    { test-id: uint }
    {
        suite-id: uint,
        name: (string-ascii 100),
        description: (string-ascii 300),
        status: (string-ascii 10),
        execution-time: uint,
        gas-used: uint,
        created-at: uint,
        updated-at: uint
    }
)

(define-map suite-permissions
    { suite-id: uint, user: principal }
    { can-modify: bool }
)

(define-map user-stats
    { user: principal }
    {
        total-suites: uint,
        total-tests: uint,
        total-passed: uint,
        total-failed: uint,
        average-coverage: uint
    }
)

;; Read-only functions
(define-read-only (get-contract-owner)
    contract-owner
)

(define-read-only (get-next-suite-id)
    (var-get next-suite-id)
)

(define-read-only (get-next-test-id)
    (var-get next-test-id)
)

(define-read-only (get-test-suite (suite-id uint))
    (map-get? test-suites { suite-id: suite-id })
)

(define-read-only (get-test-case (test-id uint))
    (map-get? test-cases { test-id: test-id })
)

(define-read-only (get-user-permissions (suite-id uint) (user principal))
    (map-get? suite-permissions { suite-id: suite-id, user: user })
)

(define-read-only (get-user-stats (user principal))
    (map-get? user-stats { user: user })
)

(define-read-only (can-modify-suite (suite-id uint) (user principal))
    (match (map-get? test-suites { suite-id: suite-id })
        suite-data 
            (or 
                (is-eq (get creator suite-data) user)
                (is-eq contract-owner user)
                (match (map-get? suite-permissions { suite-id: suite-id, user: user })
                    permission-data (get can-modify permission-data)
                    false
                )
            )
        false
    )
)

(define-read-only (calculate-quality-score (coverage-percentage uint) (passed-tests uint) (total-tests uint))
    (if (is-eq total-tests u0)
        u0
        (let
            (
                (pass-rate (/ (* passed-tests u100) total-tests))
                (weighted-coverage (/ (* coverage-percentage u60) u100))
                (weighted-pass-rate (/ (* pass-rate u40) u100))
            )
            (+ weighted-coverage weighted-pass-rate)
        )
    )
)

(define-read-only (get-suite-quality-score (suite-id uint))
    (match (map-get? test-suites { suite-id: suite-id })
        suite-data (ok (get quality-score suite-data))
        err-test-suite-not-found
    )
)

(define-read-only (compare-suite-quality (suite-id-1 uint) (suite-id-2 uint))
    (match (map-get? test-suites { suite-id: suite-id-1 })
        suite-1
            (match (map-get? test-suites { suite-id: suite-id-2 })
                suite-2
                    (let
                        (
                            (score-1 (get quality-score suite-1))
                            (score-2 (get quality-score suite-2))
                        )
                        (ok {
                            suite-1-score: score-1,
                            suite-2-score: score-2,
                            better-suite: (if (> score-1 score-2) suite-id-1 suite-id-2),
                            score-difference: (if (> score-1 score-2) (- score-1 score-2) (- score-2 score-1))
                        })
                    )
                err-test-suite-not-found
            )
        err-test-suite-not-found
    )
)

;; Public functions
(define-public (create-test-suite (name (string-ascii 100)) (description (string-ascii 500)))
    (let
        (
            (suite-id (var-get next-suite-id))
        )
        (begin
            (map-set test-suites
                { suite-id: suite-id }
                {
                    name: name,
                    description: description,
                    creator: tx-sender,
                    total-tests: u0,
                    passed-tests: u0,
                    failed-tests: u0,
                    coverage-percentage: u0,
                    quality-score: u0,
                    created-at: stacks-block-height,
                    last-updated: stacks-block-height,
                    is-active: true
                }
            )
            (var-set next-suite-id (+ suite-id u1))
            (update-user-stats tx-sender u1 u0 u0 u0)
            (ok suite-id)
        )
    )
)

(define-public (add-test-case (suite-id uint) (name (string-ascii 100)) (description (string-ascii 300)))
    (let
        (
            (test-id (var-get next-test-id))
        )
        (begin
            (asserts! (can-modify-suite suite-id tx-sender) err-unauthorized)
            (match (map-get? test-suites { suite-id: suite-id })
                suite-data
                    (begin
                        (map-set test-cases
                            { test-id: test-id }
                            {
                                suite-id: suite-id,
                                name: name,
                                description: description,
                                status: "pending",
                                execution-time: u0,
                                gas-used: u0,
                                created-at: stacks-block-height,
                                updated-at: stacks-block-height
                            }
                        )
                        (map-set test-suites
                            { suite-id: suite-id }
                            (merge suite-data { 
                                total-tests: (+ (get total-tests suite-data) u1),
                                last-updated: stacks-block-height
                            })
                        )
                        (var-set next-test-id (+ test-id u1))
                        (ok test-id)
                    )
                err-test-suite-not-found
            )
        )
    )
)

(define-public (update-test-result (test-id uint) (status (string-ascii 10)) (execution-time uint) (gas-used uint))
    (match (map-get? test-cases { test-id: test-id })
        test-data
            (let
                (
                    (suite-id (get suite-id test-data))
                    (old-status (get status test-data))
                )
                (begin
                    (asserts! (can-modify-suite suite-id tx-sender) err-unauthorized)
                    (map-set test-cases
                        { test-id: test-id }
                        (merge test-data {
                            status: status,
                            execution-time: execution-time,
                            gas-used: gas-used,
                            updated-at: stacks-block-height
                        })
                    )
                    (update-suite-stats suite-id old-status status)
                    (ok true)
                )
            )
        err-test-case-not-found
    )
)

(define-public (update-coverage (suite-id uint) (coverage-percentage uint))
    (begin
        (asserts! (can-modify-suite suite-id tx-sender) err-unauthorized)
        (asserts! (<= coverage-percentage u100) err-invalid-coverage)
        (match (map-get? test-suites { suite-id: suite-id })
            suite-data
                (let
                    (
                        (passed (get passed-tests suite-data))
                        (total (get total-tests suite-data))
                        (new-quality-score (calculate-quality-score coverage-percentage passed total))
                    )
                    (begin
                        (map-set test-suites
                            { suite-id: suite-id }
                            (merge suite-data {
                                coverage-percentage: coverage-percentage,
                                quality-score: new-quality-score,
                                last-updated: stacks-block-height
                            })
                        )
                        (ok true)
                    )
                )
            err-test-suite-not-found
        )
    )
)

(define-public (grant-suite-permission (suite-id uint) (user principal))
    (begin
        (asserts! (can-modify-suite suite-id tx-sender) err-unauthorized)
        (map-set suite-permissions
            { suite-id: suite-id, user: user }
            { can-modify: true }
        )
        (ok true)
    )
)

(define-public (revoke-suite-permission (suite-id uint) (user principal))
    (begin
        (asserts! (can-modify-suite suite-id tx-sender) err-unauthorized)
        (map-delete suite-permissions { suite-id: suite-id, user: user })
        (ok true)
    )
)

(define-public (deactivate-test-suite (suite-id uint))
    (begin
        (asserts! (can-modify-suite suite-id tx-sender) err-unauthorized)
        (match (map-get? test-suites { suite-id: suite-id })
            suite-data
                (begin
                    (map-set test-suites
                        { suite-id: suite-id }
                        (merge suite-data {
                            is-active: false,
                            last-updated: stacks-block-height
                        })
                    )
                    (ok true)
                )
            err-test-suite-not-found
        )
    )
)

(define-public (recalculate-quality-score (suite-id uint))
    (begin
        (asserts! (can-modify-suite suite-id tx-sender) err-unauthorized)
        (match (map-get? test-suites { suite-id: suite-id })
            suite-data
                (let
                    (
                        (coverage (get coverage-percentage suite-data))
                        (passed (get passed-tests suite-data))
                        (total (get total-tests suite-data))
                        (new-quality-score (calculate-quality-score coverage passed total))
                    )
                    (begin
                        (map-set test-suites
                            { suite-id: suite-id }
                            (merge suite-data {
                                quality-score: new-quality-score,
                                last-updated: stacks-block-height
                            })
                        )
                        (ok new-quality-score)
                    )
                )
            err-test-suite-not-found
        )
    )
)

;; Private functions
(define-private (update-suite-stats (suite-id uint) (old-status (string-ascii 10)) (new-status (string-ascii 10)))
    (match (map-get? test-suites { suite-id: suite-id })
        suite-data
            (let
                (
                    (current-passed (get passed-tests suite-data))
                    (current-failed (get failed-tests suite-data))
                    (total-tests (get total-tests suite-data))
                    (coverage (get coverage-percentage suite-data))
                    (new-passed 
                        (if (is-eq new-status "passed")
                            (if (is-eq old-status "passed") current-passed (+ current-passed u1))
                            (if (is-eq old-status "passed") (- current-passed u1) current-passed)
                        )
                    )
                    (new-failed
                        (if (is-eq new-status "failed")
                            (if (is-eq old-status "failed") current-failed (+ current-failed u1))
                            (if (is-eq old-status "failed") (- current-failed u1) current-failed)
                        )
                    )
                    (new-quality-score (calculate-quality-score coverage new-passed total-tests))
                )
                (begin
                    (map-set test-suites
                        { suite-id: suite-id }
                        (merge suite-data {
                            passed-tests: new-passed,
                            failed-tests: new-failed,
                            quality-score: new-quality-score,
                            last-updated: stacks-block-height
                        })
                    )
                    true
                )
            )
        false
    )
)

(define-private (update-user-stats (user principal) (suite-delta uint) (test-delta uint) (passed-delta uint) (failed-delta uint))
    (match (map-get? user-stats { user: user })
        current-stats
            (begin
                (map-set user-stats
                    { user: user }
                    {
                        total-suites: (+ (get total-suites current-stats) suite-delta),
                        total-tests: (+ (get total-tests current-stats) test-delta),
                        total-passed: (+ (get total-passed current-stats) passed-delta),
                        total-failed: (+ (get total-failed current-stats) failed-delta),
                        average-coverage: (get average-coverage current-stats)
                    }
                )
                true
            )
        (begin
            (map-set user-stats
                { user: user }
                {
                    total-suites: suite-delta,
                    total-tests: test-delta,
                    total-passed: passed-delta,
                    total-failed: failed-delta,
                    average-coverage: u0
                }
            )
            true
        )
    )
)
