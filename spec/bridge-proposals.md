# Bridging Rust Gaps in Aski — Design Proposals (Index)

*Last updated: 2026-04-21 · Companion to [gap-analysis.md](gap-analysis.md).*

> **See [syntax-v021.md](syntax-v021.md) for current spec.** Many
> items in this bridge document landed in v0.21 on 2026-04-21. This
> document remains useful as the historical record of how each
> decision got from v0.20 to v0.21. Items still open are flagged
> below and in [outliers-v021.md](outliers-v021.md).

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

# Status snapshot (2026-04-21)

| Bucket | Items | Status |
|--------|-------|--------|
| **Landed pre-v0.21** | C1 Wildcard `_` | ✅ shipped across synth-core, askicc, aski-core |
| **Landed in v0.21 (2026-04-21)** | C4, C5, C6, C7, S2, S5, S7, S8, S9, S11, N1, N2, N3, N5, N8, N10, U1, U16, S4 Position A | see [syntax-v021.md](syntax-v021.md) |
| **Still proposed shapes / pick-and-merge in v0.21** | C3 (LiteralPattern scope), C8 (inherent impls), N7 (doc comments — SHELVED) | see clear.md |
| **Works already** | N9 (doc only) | Documentation task |
| **Proposed OUT — design.md doesn't yet reject** | C8, S1, S12, N4, N6 | not permanent until design.md gains prose |
| **Small open decisions** | S3 sigils, S6 `?{…}` sigil, U14 dyn sigil | see small-decisions.md |
| **Big open decisions** | C2+S10+N10 destructuring (U11), S6 semantics, S4 closures B/C (U12) | open design space — see outliers-v021.md |
| **Outliers (hard blocks in v0.21)** | U3 (Bool literal), U4 (array literal), U5 (slice types), U6 (narrowing shape), U7 (bare `=`), U10/N4 (finer visibility), U19 (infinite loop), U20 (HKT), U21 (dependent) | see [outliers-v021.md](outliers-v021.md) |
| **Unconsulted Claude decisions** | U1–U21 | see [gap-analysis.md §Unconsulted Claude decisions](gap-analysis.md#unconsulted-claude-decisions--now-open-gaps) |
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
6. **Compile to Rust (bootstrap).** HKT and dependent types are
   open questions (gap-analysis.md §U20, §U21), not settled OUT.
   Rust has limited versions of both (GATs, const generics); whether
   aski lifts these into first-class aski source (desugaring to Rust)
   is undecided. Features
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

# Landing order — historical record

### Wave A — blocker fixes
C1 (shipped 2026-04-19), C5, C6, C7, N2, N8, C4 — all LANDED in v0.21
(2026-04-21). U1 deref also LANDED.

### Wave B — expressiveness
S2, S8, S9, N5 — all LANDED in v0.21 (2026-04-21). S3
(break/continue sigils) remains open. N7 (doc comments) SHELVED.
C2 (destructuring) still open — outliers §U11.

### Wave C — ecosystem
S11 (type), S4 (Position A), S5, S7, N3, N1 — all LANDED in v0.21
(2026-04-21). S6 (dyn semantics) still blocked pending semantic
design — outliers §S6. S4 Positions B/C open — outliers §U12.

# Original bridge proposals (historical)

The decision-organised files above supersede the prior severity-
organised structure (`bridge/critical.md`, `bridge/significant.md`,
`bridge/notable.md`). Content migrated 2026-04-20. Many individual
items landed into v0.21 on 2026-04-21 — see
[syntax-v021.md](syntax-v021.md) for the current spec.
