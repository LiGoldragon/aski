# Bridging Rust Gaps in Aski — Design Proposals (Index)

*Last updated: 2026-04-20 · Companion to [gap-analysis.md](gap-analysis.md).*

# Files

Bridge proposals are organised by **decision cost**, not severity.
Each file carries concrete Rust / aski / synth examples per item.

- **[bridge/paradigm.md](bridge/paradigm.md)** — ground truth on
  aski's relationship to Rust ("types all the way down, supports all
  of Rust through that lens"), spec-status levels (Landed / Proposed
  / Unspec'd / Confirmed OUT), and a full Rust feature audit. Read
  first. Other bridge docs should be consistent with this.
- **[bridge/clear.md](bridge/clear.md)** — items with clear
  resolution. Several "OUT" items here are actually spec-silent
  (pending design.md updates) — see per-item notes.
- **[bridge/small-decisions.md](bridge/small-decisions.md)** — items
  where a specific naming or sigil choice is the only remaining
  question. Shapes are proposed, not settled.
- **[bridge/big-decisions.md](bridge/big-decisions.md)** — items
  with genuinely open design. Each has alternatives with different
  character. Needs real discussion.

# Status snapshot (2026-04-20)

| Bucket | Items | Status |
|--------|-------|--------|
| **Landed** | C1 Wildcard `_` | ✅ shipped across synth-core, askicc, aski-core |
| **Accepted 2026-04-20** | C5 Division, C6 Unary `-` / `!` | pending grammar + aski-core landing |
| **Proposed shapes, awaiting approval** | C3, C4, C7, N2, N7, N8, S2, S4 (named-type), S5, S7, S8, S9, S11, N3 | each item carries open sub-questions; see clear.md |
| **Works already** | N1 (place-based origins), N9 (doc only) | Documentation task |
| **Proposed OUT — design.md doesn't yet reject** | C8, S1, S12, N4, N6 | not permanent until design.md gains prose |
| **Small open decisions** | S3 sigils, S6 `?{…}`, N5 lookahead, char delimiter | sigil/spelling calls, each with alternatives listed |
| **Big open decisions** | C2+S10+N10 destructuring, S6 semantics, S4 closures | open design space |
| **Unconsulted Claude decisions** | U1–U18 | see [gap-analysis.md §Unconsulted Claude decisions](gap-analysis.md#unconsulted-claude-decisions--now-open-gaps) |
| **Shelved** | U8 (doc-comment sigil, 2026-04-20) | see [shelved.md](shelved.md) |

# Rubric (carried forward — every proposal must respect)

1. **First-token decidable.** Every new alternative starts with a
   token whose kind/shape uniquely picks it within its dialect.
2. **All six delimiter pairs are allocated.** New constructs reuse
   an existing pair in a new position, or compose a sigil + existing
   pair.
3. **Names Are Meaningful.** No pointer names, no positional
   nameless grouping. The case rule (camelCase = actual instance of
   a type) applies structurally.
4. **Sigils have stable meaning.** `@`=public, `:`=path, `&`=borrow,
   `~`=mutable, `$`=type param, `'`=origin/place, `^`=early return
   (landed; "exit-family" extension proposed in bridge/small-decisions.md §S3),
   `?`=try-unwrap (landed, postfix) / dyn-dispatch prefix (proposed in §S6).
5. **Methods over operators — proposed direction, not settled.** For
   bit ops, casts, assignment, and similar, stdlib traits (not new
   operator syntax) is the proposed direction. This is the position
   behind §S5, §S7, §N3 — but the decisions themselves are still
   open (see [gap-analysis.md §U17](gap-analysis.md#u17-methods-over-operators-rubric)).
6. **Compile to Rust (bootstrap).** Features Rust can't express
   (HKT, dependent types) stay OUT per design.md §Generics. Features
   Rust has but sema's binary model doesn't yet have a design for
   (e.g., dyn dispatch) need the semantic design before syntax use
   lands. Aski is *intended* to eventually support all of Rust
   through types-and-traits, and to push further — see
   [bridge/paradigm.md](bridge/paradigm.md).

# Delimiter & sigil budget (still available at expr/stmt/type)

- `!` — only in `!=`. Available for unary-NOT.
- `|` — only in `||` and delimiter pairs.
- `=` — only in `==`, `!=`, `<=`, `>=`. Bare `=` is free (→ N5 discriminants).
- `` ` `` backtick — entirely unused (proposed for char literals).
- `..` / `..=` — entirely unused bigrams (→ S2 ranges).
- `<<` / `>>` — unused in aski source.

# Recommended landing order

### Wave A — blocker fixes (now)
C1 (done), C5, C6, C7, N2, N8 (char backtick decision first), C3/C4 (retractions documented).

### Wave B — expressiveness (after small decisions)
S2, S3 (after sigil nod), S8, S9, N5 (after lookahead nod), N7, C2 (after big decision).

### Wave C — ecosystem (after big decisions)
S6 (after semantic design), S11 (after S8), S4 (after philosophy choice),
S5, S7, N3, N1, N9.

# Original bridge proposals (historical)

The decision-organised files above supersede the prior severity-
organised structure (`bridge/critical.md`, `bridge/significant.md`,
`bridge/notable.md`). Content migrated 2026-04-20.
