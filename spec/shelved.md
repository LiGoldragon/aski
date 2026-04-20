;; Shelved — TBD and unimportant for now
;; Date: 2026-04-20
;;
;; Items parked here are decisions that are not urgent, not blocking,
;; and not close to needing a call. They sit here to keep bridge-doc
;; prose focused on in-flight decisions. Move an item out of this file
;; when its time comes; revisit before any 1.0 claim.

# Contents

1. [U8. Doc comment sigil](#u8-doc-comment-sigil)

---

## U8. Doc comment sigil

**Origin:** bridge/clear.md §N7, gap-analysis.md §U8.

**Parked 2026-04-20** — doc comments aren't blocking any other
decision. No pipeline stage needs them yet (rsc doesn't exist; askid
doesn't exist). Deferring until documentation becomes a real concern.

**When revisited, open question:** pick a form.
- `;;;` (line-start triple-semicolon, extends `;;` line-comment)
- block-doc form (no precedent in aski)
- different leading marker

Until then, aski doesn't have doc comments. No grammar work. No
aski-core field. rsc won't emit `///` in Rust projections.
