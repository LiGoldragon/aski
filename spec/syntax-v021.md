syntax-v021.aski — index

Aski v0.21, Identity-is-Location. The canonical reference is split
across syntax-v021/ per section. This file is the entry index.

Dogfood note: a 2944-line monolith was counter to the II-L
principle this spec describes — "source files hold only what
belongs to their identity; structure lives in the filesystem."
The split honors the principle the spec itself argues for.

## READ IN ORDER (or by concern)

00-overview                         — II-L, filesystem layout, imports file
01-enums                            — Name.enum files, variants, discriminants
02-structs                          — Name.struct files, fields, generics
03-newtypes-consts                  — Name.newtype + Name.const (with const expressions)
04-traits                           — Name.trait files, assoc types, assoc consts, defaults
05-impls                            — Trait[Args]~Target.impl files, filename grammar, blankets
06-effects-derivations-tests        — .effect / .derivation / .test-impl surfaces
07-modules-visibility               — directory = module; _ prefix = private
08-body-basics                      — literals, local decls, references/borrows/origins, generics
09-control-flow                     — match / while / iter / early-return / try / or-pattern
10-self-mutation-cast-path          — self, ~mutation, cast via From/Into, path :
11-stdlib-primitives                — Never, 'Static origin, Char library (U16 nested enum)
12-expressions                      — type application, struct construction, operators,
                                       dyn sigil, closures, literal patterns, postfix, atoms
13-rfi-exec                         — .rfi and .exec surfaces
14-scorecard                        — Rust feature coverage table
15-closing                          — open questions, edge cases, precedent, v0.20 diff, end notes

## QUICK JUMPS BY CONCERN

Types  (shape)                      → 01, 02, 03, 11
Traits (interface)                  → 04
Impls  (behavior)                   → 05, 06
Layout (filesystem / modules)       → 00, 07
Body grammar                        → 08, 09, 10, 12
Special forms                       → 11, 12
Surfaces (other)                    → 13
Reference / audit                   → 14, 15

## ITEMS LANDED IN V0.21 (vs V0.20)

Accepted this cycle:
  C5 division /                     → 12
  C6 unary - !                      → 12
  U1 deref *                         → 12
  U16 Char library (Char:Upper:A)    → 11

Merged per survey 2026-04-21:
  C4 if/if-let/while-let idiom       → 09
  C7 borrow of path expression       → 08
  S2 ranges 0..10 / 0..=10           → 09 / 12
  S5 bitwise via stdlib              → 12
  S7 cast via stdlib                 → 10
  S8 const expressions               → 03
  S9 associated constants            → 04
  S11 arrays (integer-const)         → 02 / 14
  N1 'Static / lifetime generics     → 11
  N2 Never primitive                 → 11
  N3 assignment via stdlib           → 10
  N5 enum discriminants              → 01
  N8 literal lexer (hex/oct/bin/_/raw/escape) → 08
  N10 iteration binding              → 09

## OPEN (FLAGGED IN DOCS, NOT RESOLVED HERE)

Pick-and-merge — Li to confirm the specific shape:
  U11 struct destructuring A/B/C     → 12
  U13 break/continue sigil family    → 09
  U14 dyn sigil ?{Trait}             → 12
  U15 discriminant shape [Ok 200]    → 01
  U17 methods-over-operators rubric  → 12
  C3 LiteralPattern scope            → 12
  S4 closures Position A             → 12

Outliers (hard blocks or big design) — see outliers-v021.md:
  U3  true/false literal tokens
  U4  array literal syntax
  U5  slice types [T]
  U6  narrowing conversions shape
  U7  bare = / += as operators
  U10 / N4 finer visibility under II-L
  U12 closures positions B / C
  U19 infinite-loop form
  U20 HKT
  U21 dependent types
  S6  dyn semantics

## SPEC AUTHORITY

design.md                           — settled language principles
bridge/paradigm.md                  — spec-status levels (Landed/Proposed/Unspec'd/OUT)
decomposition.md                    — II-L research (foundational; supersedes retired multi-surface proposal)
gap-analysis.md                     — U1–U21 open items catalogue
outliers-v021.md                    — items that couldn't merge cleanly
syntax-v021/*                       — the split canonical reference (this index)

## NOTES ON THE SPLIT

Each file is self-contained for its section — read one without
the others and you get a working picture of that area.

Cross-references across files are by the section number prefix:
  "see 05-impls §Blanket impls"

Line counts, per file:
  00-overview                182
  01-enums                   188
  02-structs                 152
  03-newtypes-consts         148
  04-traits                  231
  05-impls                   331
  06-effects-derivations-tests  198
  07-modules-visibility       73
  08-body-basics             177
  09-control-flow            187
  10-self-mutation-cast-path 119
  11-stdlib-primitives       118
  12-expressions             297
  13-rfi-exec                 83
  14-scorecard               201
  15-closing                 259
  ----------------------------
  total                     2944  (identical to monolith)

No content was rewritten during the split. Every line from the
monolith is preserved in one of the sub-files.
