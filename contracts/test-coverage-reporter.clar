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
(define-constant err-test-run-not-found (err u107))
(define-constant err-tag-already-exists (err u108))
(define-constant err-tag-not-found (err u109))
(define-constant err-max-tags-reached (err u110))

(define-constant err-gate-not-configured (err u111))
(define-constant err-invalid-threshold (err u112))

;; Data Variables
(define-data-var next-suite-id uint u1)
(define-data-var next-test-id uint u1)
(define-data-var next-run-id uint u1)

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

(define-map test-run-snapshots
    { run-id: uint }
    {
        suite-id: uint,
        run-name: (string-ascii 100),
        executor: principal,
        total-tests: uint,
        passed-tests: uint,
        failed-tests: uint,
        coverage-percentage: uint,
        quality-score: uint,
        execution-time: uint,
        gas-consumed: uint,
        snapshot-at: uint
    }
)

(define-map suite-tags
    { suite-id: uint, tag: (string-ascii 50) }
    { added-at: uint, added-by: principal }
)

(define-map tag-stats
    { tag: (string-ascii 50) }
    {
        total-suites: uint,
        total-quality-score: uint,
        average-quality: uint,
        suite-count: uint
    }
)

(define-map suite-tag-count
    { suite-id: uint }
    { tag-count: uint }
)

(define-map release-gates
    { suite-id: uint }
    {
        min-coverage: uint,
        min-quality: uint,
        max-failed: uint,
        last-evaluated: uint,
        latest-result: bool
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

(define-read-only (get-next-run-id)
    (var-get next-run-id)
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

(define-read-only (get-test-run-snapshot (run-id uint))
    (map-get? test-run-snapshots { run-id: run-id })
)

(define-read-only (compare-test-runs (run-id-1 uint) (run-id-2 uint))
    (match (map-get? test-run-snapshots { run-id: run-id-1 })
        run-1
            (match (map-get? test-run-snapshots { run-id: run-id-2 })
                run-2
                    (let
                        (
                            (quality-diff (if (> (get quality-score run-1) (get quality-score run-2))
                                            (- (get quality-score run-1) (get quality-score run-2))
                                            (- (get quality-score run-2) (get quality-score run-1))))
                            (coverage-diff (if (> (get coverage-percentage run-1) (get coverage-percentage run-2))
                                             (- (get coverage-percentage run-1) (get coverage-percentage run-2))
                                             (- (get coverage-percentage run-2) (get coverage-percentage run-1))))
                        )
                        (ok {
                            run-1-quality: (get quality-score run-1),
                            run-2-quality: (get quality-score run-2),
                            quality-change: quality-diff,
                            run-1-coverage: (get coverage-percentage run-1),
                            run-2-coverage: (get coverage-percentage run-2),
                            coverage-change: coverage-diff,
                            better-run: (if (> (get quality-score run-1) (get quality-score run-2)) run-id-1 run-id-2)
                        })
                    )
                err-test-run-not-found
            )
        err-test-run-not-found
    )
)

(define-read-only (get-quality-trend (suite-id uint))
    (let
        (
            (current-run-id (var-get next-run-id))
        )
        (if (> current-run-id u2)
            (match (map-get? test-run-snapshots { run-id: (- current-run-id u1) })
                latest-run
                    (match (map-get? test-run-snapshots { run-id: (- current-run-id u2) })
                        previous-run
                            (if (is-eq (get suite-id latest-run) suite-id)
                                (ok {
                                    trend: (if (> (get quality-score latest-run) (get quality-score previous-run)) "improving" "declining"),
                                    change: (if (> (get quality-score latest-run) (get quality-score previous-run))
                                              (- (get quality-score latest-run) (get quality-score previous-run))
                                              (- (get quality-score previous-run) (get quality-score latest-run))),
                                    latest-score: (get quality-score latest-run),
                                    previous-score: (get quality-score previous-run)
                                })
                                err-test-suite-not-found
                            )
                        err-test-run-not-found
                    )
                err-test-run-not-found
            )
            (ok { trend: "insufficient-data", change: u0, latest-score: u0, previous-score: u0 })
        )
    )
)

(define-read-only (get-suite-tags (suite-id uint))
    (map-get? suite-tag-count { suite-id: suite-id })
)

(define-read-only (has-tag (suite-id uint) (tag (string-ascii 50)))
    (is-some (map-get? suite-tags { suite-id: suite-id, tag: tag }))
)

(define-read-only (get-tag-stats (tag (string-ascii 50)))
    (map-get? tag-stats { tag: tag })
)

(define-read-only (get-suites-by-category (tag (string-ascii 50)) (min-quality uint))
    (match (map-get? tag-stats { tag: tag })
        stats
            (ok {
                tag: tag,
                suite-count: (get suite-count stats),
                average-quality: (get average-quality stats),
                meets-threshold: (>= (get average-quality stats) min-quality)
            })
        err-tag-not-found
    )
)

(define-read-only (compare-categories (tag-1 (string-ascii 50)) (tag-2 (string-ascii 50)))
    (match (map-get? tag-stats { tag: tag-1 })
        stats-1
            (match (map-get? tag-stats { tag: tag-2 })
                stats-2
                    (ok {
                        tag-1: tag-1,
                        tag-1-quality: (get average-quality stats-1),
                        tag-1-suites: (get suite-count stats-1),
                        tag-2: tag-2,
                        tag-2-quality: (get average-quality stats-2),
                        tag-2-suites: (get suite-count stats-2),
                        better-category: (if (> (get average-quality stats-1) (get average-quality stats-2)) tag-1 tag-2)
                    })
                err-tag-not-found
            )
        err-tag-not-found
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

(define-public (create-test-run-snapshot (suite-id uint) (run-name (string-ascii 100)) (execution-time uint) (gas-consumed uint))
    (begin
        (asserts! (can-modify-suite suite-id tx-sender) err-unauthorized)
        (match (map-get? test-suites { suite-id: suite-id })
            suite-data
                (let
                    (
                        (run-id (var-get next-run-id))
                    )
                    (begin
                        (map-set test-run-snapshots
                            { run-id: run-id }
                            {
                                suite-id: suite-id,
                                run-name: run-name,
                                executor: tx-sender,
                                total-tests: (get total-tests suite-data),
                                passed-tests: (get passed-tests suite-data),
                                failed-tests: (get failed-tests suite-data),
                                coverage-percentage: (get coverage-percentage suite-data),
                                quality-score: (get quality-score suite-data),
                                execution-time: execution-time,
                                gas-consumed: gas-consumed,
                                snapshot-at: stacks-block-height
                            }
                        )
                        (var-set next-run-id (+ run-id u1))
                        (ok run-id)
                    )
                )
            err-test-suite-not-found
        )
    )
)

(define-public (auto-snapshot-on-coverage-update (suite-id uint) (coverage-percentage uint))
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
                        (run-id (var-get next-run-id))
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
                        (map-set test-run-snapshots
                            { run-id: run-id }
                            {
                                suite-id: suite-id,
                                run-name: "coverage-update",
                                executor: tx-sender,
                                total-tests: total,
                                passed-tests: passed,
                                failed-tests: (get failed-tests suite-data),
                                coverage-percentage: coverage-percentage,
                                quality-score: new-quality-score,
                                execution-time: u0,
                                gas-consumed: u0,
                                snapshot-at: stacks-block-height
                            }
                        )
                        (var-set next-run-id (+ run-id u1))
                        (ok run-id)
                    )
                )
            err-test-suite-not-found
        )
    )
)

(define-public (add-suite-tag (suite-id uint) (tag (string-ascii 50)))
    (begin
        (asserts! (can-modify-suite suite-id tx-sender) err-unauthorized)
        (asserts! (is-none (map-get? suite-tags { suite-id: suite-id, tag: tag })) err-tag-already-exists)
        (match (map-get? test-suites { suite-id: suite-id })
            suite-data
                (let
                    (
                        (current-count (default-to { tag-count: u0 } (map-get? suite-tag-count { suite-id: suite-id })))
                        (new-count (+ (get tag-count current-count) u1))
                    )
                    (begin
                        (asserts! (<= new-count u10) err-max-tags-reached)
                        (map-set suite-tags
                            { suite-id: suite-id, tag: tag }
                            { added-at: stacks-block-height, added-by: tx-sender }
                        )
                        (map-set suite-tag-count
                            { suite-id: suite-id }
                            { tag-count: new-count }
                        )
                        (update-tag-statistics tag suite-id (get quality-score suite-data) true)
                        (ok true)
                    )
                )
            err-test-suite-not-found
        )
    )
)

(define-public (remove-suite-tag (suite-id uint) (tag (string-ascii 50)))
    (begin
        (asserts! (can-modify-suite suite-id tx-sender) err-unauthorized)
        (asserts! (is-some (map-get? suite-tags { suite-id: suite-id, tag: tag })) err-tag-not-found)
        (match (map-get? test-suites { suite-id: suite-id })
            suite-data
                (let
                    (
                        (current-count (default-to { tag-count: u0 } (map-get? suite-tag-count { suite-id: suite-id })))
                        (new-count (if (> (get tag-count current-count) u0) (- (get tag-count current-count) u1) u0))
                    )
                    (begin
                        (map-delete suite-tags { suite-id: suite-id, tag: tag })
                        (map-set suite-tag-count
                            { suite-id: suite-id }
                            { tag-count: new-count }
                        )
                        (update-tag-statistics tag suite-id (get quality-score suite-data) false)
                        (ok true)
                    )
                )
            err-test-suite-not-found
        )
    )
)

(define-public (bulk-tag-suite (suite-id uint) (tag-1 (string-ascii 50)) (tag-2 (string-ascii 50)))
    (begin
        (try! (add-suite-tag suite-id tag-1))
        (try! (add-suite-tag suite-id tag-2))
        (ok true)
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

(define-private (update-tag-statistics (tag (string-ascii 50)) (suite-id uint) (quality-score uint) (is-adding bool))
    (match (map-get? tag-stats { tag: tag })
        current-stats
            (let
                (
                    (current-count (get suite-count current-stats))
                    (current-total (get total-quality-score current-stats))
                    (new-count (if is-adding (+ current-count u1) (if (> current-count u0) (- current-count u1) u0)))
                    (new-total (if is-adding (+ current-total quality-score) (if (>= current-total quality-score) (- current-total quality-score) u0)))
                    (new-average (if (> new-count u0) (/ new-total new-count) u0))
                )
                (begin
                    (map-set tag-stats
                        { tag: tag }
                        {
                            total-suites: new-count,
                            total-quality-score: new-total,
                            average-quality: new-average,
                            suite-count: new-count
                        }
                    )
                    true
                )
            )
        (if is-adding
            (begin
                (map-set tag-stats
                    { tag: tag }
                    {
                        total-suites: u1,
                        total-quality-score: quality-score,
                        average-quality: quality-score,
                        suite-count: u1
                    }
                )
                true
            )
            false
        )
    )
)

(define-read-only (get-release-gate (suite-id uint))
    (map-get? release-gates { suite-id: suite-id })
)

(define-read-only (is-release-ready (suite-id uint))
    (match (map-get? release-gates { suite-id: suite-id })
        gate
            (match (map-get? test-suites { suite-id: suite-id })
                suite
                    (let
                        (
                            (coverage (get coverage-percentage suite))
                            (quality (get quality-score suite))
                            (failed (get failed-tests suite))
                            (ready (and (>= coverage (get min-coverage gate)) (>= quality (get min-quality gate)) (<= failed (get max-failed gate))))
                        )
                        (ok ready)
                    )
                err-test-suite-not-found
            )
        err-gate-not-configured
    )
)

(define-public (configure-release-gate (suite-id uint) (min-coverage uint) (min-quality uint) (max-failed uint))
    (begin
        (asserts! (can-modify-suite suite-id tx-sender) err-unauthorized)
        (asserts! (<= min-coverage u100) err-invalid-coverage)
        (asserts! (<= min-quality u100) err-invalid-threshold)
        (map-set release-gates
            { suite-id: suite-id }
            {
                min-coverage: min-coverage,
                min-quality: min-quality,
                max-failed: max-failed,
                last-evaluated: u0,
                latest-result: false
            }
        )
        (ok true)
    )
)

(define-public (evaluate-release-readiness (suite-id uint))
    (begin
        (asserts! (can-modify-suite suite-id tx-sender) err-unauthorized)
        (match (map-get? release-gates { suite-id: suite-id })
            gate
                (match (map-get? test-suites { suite-id: suite-id })
                    suite
                        (let
                            (
                                (coverage (get coverage-percentage suite))
                                (quality (get quality-score suite))
                                (failed (get failed-tests suite))
                                (ready (and (>= coverage (get min-coverage gate)) (>= quality (get min-quality gate)) (<= failed (get max-failed gate))))
                            )
                            (begin
                                (map-set release-gates { suite-id: suite-id } (merge gate { last-evaluated: stacks-block-height, latest-result: ready }))
                                (ok {
                                    ready: ready,
                                    coverage: coverage,
                                    quality: quality,
                                    failed: failed,
                                    min-coverage: (get min-coverage gate),
                                    min-quality: (get min-quality gate),
                                    max-failed: (get max-failed gate)
                                })
                            )
                        )
                    err-test-suite-not-found
                )
            err-gate-not-configured
        )
    )
)
