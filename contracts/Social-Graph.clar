;; Social Graph Contract
;; Decentralized follow/unfollow system with follower/following lists
;; Author: your-name
;; SPDX-License-Identifier: MIT

(define-data-var total-follows uint u0)

;; Primary relation existence map (follower, followee) -> true
(define-map follows
  { follower: principal, followee: principal }
  bool
)

;; Per-user counts:
;; follower-counts: how many followers a user has
;; following-counts: how many accounts a user follows
(define-map follower-counts
  { user: principal }
  { count: uint }
)

(define-map following-counts
  { user: principal }
  { count: uint }
)

;; Dense storage for lists to allow indexing and O(1) remove by swapping with last:
;; followers-by-index: { user, index } -> { who: principal }  (index starts at 1)
(define-map followers-by-index
  { user: principal, index: uint }
  { who: principal }
)

;; followees-by-index: { user, index } -> { who: principal }  (who the user follows)
(define-map followees-by-index
  { user: principal, index: uint }
  { who: principal }
)

;; Index pointers to quickly find positions for O(1) delete:
;; follower-index: { follower, followee } -> { index: uint }  (position in followee's followers list)
(define-map follower-index
  { follower: principal, followee: principal }
  { index: uint }
)

;; followee-index: { follower, followee } -> { index: uint }  (position in follower's followees list)
(define-map followee-index
  { follower: principal, followee: principal }
  { index: uint }
)

;; Events (Clarity does not support custom event definitions; use 'print' for event emission)

;; -----------------------
;; Internal helpers
;; -----------------------

(define-private (get-follower-count (user principal))
  (match (map-get? follower-counts { user: user })
    c (get count c)
    u0
  )
)

(define-private (get-following-count-internal (user principal))
  (match (map-get? following-counts { user: user })
    c (get count c)
    u0
  )
)

(define-private (set-follower-count (user principal) (n uint))
  (map-set follower-counts { user: user } { count: n })
)

(define-private (set-following-count (user principal) (n uint))
  (map-set following-counts { user: user } { count: n })
)

;; -----------------------
;; Public: follow
;; -----------------------
(define-public (follow (user principal))
  (begin
    ;; disallow following yourself
    (if (is-eq tx-sender user)
        (err u100) ;; cannot follow yourself
        (if (is-some (map-get? follows { follower: tx-sender, followee: user }))
            (err u101) ;; already following
            (let (
              (old-fcount (get-follower-count user))
              (new-fcount (+ old-fcount u1))
              (old-following (get-following-count-internal tx-sender))
              (new-following (+ old-following u1))
            )
              (begin
                (map-set follows { follower: tx-sender, followee: user } true)
                (map-set followers-by-index { user: user, index: new-fcount } { who: tx-sender })
                (map-set follower-index { follower: tx-sender, followee: user } { index: new-fcount })
                (set-follower-count user new-fcount)
                (map-set followees-by-index { user: tx-sender, index: new-following } { who: user })
                (map-set followee-index { follower: tx-sender, followee: user } { index: new-following })
                (set-following-count tx-sender new-following)
                (var-set total-follows (+ (var-get total-follows) u1))
                (print (tuple (event "follow") (follower tx-sender) (followee user)))
                (ok true)
              )
            )
          )
        )
    )
)

;; -----------------------
;; Public: unfollow
;; -----------------------
(define-public (unfollow (user principal))
  (let (
    (f-index (get index (unwrap-panic (map-get? follower-index { follower: tx-sender, followee: user }))))
    (f-count (unwrap-panic (some (get-follower-count user))))
    (fe-index (get index (unwrap-panic (map-get? followee-index { follower: tx-sender, followee: user }))))
    (following-count (get-following-count-internal tx-sender))
  )
    (begin
      (if (is-eq f-index f-count)
          (map-delete followers-by-index { user: user, index: f-index })
          (let (
            (last-follower-obj (map-get? followers-by-index { user: user, index: f-count }))
          )
            (begin
              (asserts! (is-some last-follower-obj) (err u104))
              (let ((last-follower (get who (unwrap-panic last-follower-obj))))
                (map-set followers-by-index { user: user, index: f-index } { who: last-follower })
                (map-set follower-index { follower: last-follower, followee: user } { index: f-index })
                (map-delete followers-by-index { user: user, index: f-count })
              )
            )
          )
      )
      (map-delete follower-index { follower: tx-sender, followee: user })
      (set-follower-count user (- f-count u1))
      (if (is-eq fe-index following-count)
          (map-delete followees-by-index { user: tx-sender, index: fe-index })
          (let (
            (last-followee-obj (map-get? followees-by-index { user: tx-sender, index: following-count }))
          )
            (begin
              (asserts! (is-some last-followee-obj) (err u104))
              (let ((last-followee (get who (unwrap-panic last-followee-obj))))
                (map-set followees-by-index { user: tx-sender, index: fe-index } { who: last-followee })
                (map-set followee-index { follower: tx-sender, followee: last-followee } { index: fe-index })
                (map-delete followees-by-index { user: tx-sender, index: following-count })
              )
            )
          )
      )
      (map-delete followee-index { follower: tx-sender, followee: user })
      (set-following-count tx-sender (- following-count u1))
      (map-delete follows { follower: tx-sender, followee: user })
      (var-set total-follows (- (var-get total-follows) u1))
      (print (tuple (event "unfollow") (follower tx-sender) (followee user)))
      (ok true)
    )
  )
)

;; -----------------------
;; Read-only views
;; -----------------------

;; Check if follower follows followee
(define-read-only (is-following (follower principal) (followee principal))
  (default-to false (map-get? follows { follower: follower, followee: followee }))
)

;; Get number of followers for a user
(define-read-only (get-followers-count (user principal))
  (ok (get-follower-count user))
)

;; Get number of followees (how many accounts user follows)
(define-read-only (get-following-count (user principal))
  (ok (get-following-count-internal user))
)

;; Get follower principal by index (1-based). Returns (optional principal)
(define-read-only (get-follower-by-index (user principal) (index uint))
  (match (map-get? followers-by-index { user: user, index: index })
    o (ok (some (get who o)))
    (ok none)
  )
)

;; Get followee principal by index (1-based). Returns (optional principal)
(define-read-only (get-followee-by-index (user principal) (index uint))
  (match (map-get? followees-by-index { user: user, index: index })
    o (ok (some (get who o)))
    (ok none)
  )
)

;; Get global total follows (useful for analytics)
(define-read-only (get-total-follows)
  (ok (var-get total-follows))
)
