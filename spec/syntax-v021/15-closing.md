## OPEN QUESTIONS — flagged here, not resolved

Each open question is tracked in gap-analysis.md. This section
lists the open items that affect v0.21 source syntax directly.
Items MERGED in this pass are listed with their status; items
still open are grouped by where Li needs to decide.

MERGED 2026-04-21 (in this v0.21 pass) ----------------------
U1  Deref *x                               — ACCEPTED; stdlib Deref dispatch
C4  if / if let / while let                — idiom docs
C7  Borrow of place expression             — PlaceExpr grammar
S2  Range expressions                      — 0..n / a..=b
S5  Bitwise via stdlib                     — BitOps trait
S7  Cast via stdlib                        — From/Into/TryFrom
S8  Const expressions                      — Const RHS = Expr
S9  Associated consts                      — {| Name Type ?Default |}
S11 Array type                             — {Array T N}, size is const expr
N1  'Static / lifetime generics            — conventional PlaceName
N2  Never primitive                        — zero-arity addition
N3  Assignment via stdlib methods          — Counter trait; = / += still open
N5  Enum discriminants                     — [Variant Literal] form
N8  Literal lexer extensions               — hex/bin/oct/separators/raw-str
N10 Iteration binding clarification        — single camel binding note

PICK-AND-MERGE flagged in v0.21 (Li to confirm) --------------
U11 Struct destructuring                   — Option A/B/C
U13 break / continue sigil                 — 3 candidates
U14 dyn sigil `?{Trait}`                   — semantic S6 in outliers
U15 Enum discriminant shape                — confirm [Ok 200]
U17 Methods-over-operators rubric          — confirm as standing rule
C3  LiteralPattern scope                   — Int/Float/Str (no Bool/Char)
S4  Closures (Position A merged)           — B/C inline sugar in outliers

In outliers-v021.md (non-conforming) ------------------------
U3  true / false as literal tokens         — case-rule carve-out
U4  Array literal expression               — delimiter-budget blocker
U5  Slice types [T]                        — design decision needed
U6  Narrowing conversions                  — pick form (S7 currently (a))
U7  Bare = and compound +=                 — confirm method-only
U10 Finer-grained visibility               — II-L semantic question
U12 Closures Positions B/C                 — inline-sugar grammar
U19 Native infinite-loop form              — 5 candidates
U20 Higher-kinded types                    — open
U21 Dependent types                        — open
S6  dyn semantics                          — 4 positions
N4  Scoped visibility                      — see U10

Deferred / prior state ---------------------------------------
U2  Bool in LiteralPattern                 — see U3 in outliers
U9  Inherent impls                         — spec silent
U16 Char-as-nested-enum                    — SUPERSEDES char literal; category list open
S1  Type aliases                           — user preference OUT
S3  break / continue                       — see U13 PICK-AND-MERGE
N6  Attributes                             — replaced by .derivation
N7  Doc comments                           — shelved

See `gap-analysis.md` for the full analysis of each, and
`outliers-v021.md` for items that couldn't merge this pass.

## EDGE CASES FROM II-L DECOMPOSITION

The filename encoding is not claimed to be exhaustive. A few
cases need settling (these are distinct from the U/S/N list
above; they're II-L-specific and surface during v0.21 spec work):

E1. Impl filename with cross-module trait AND cross-module target:
    `Display@std~Shape@shapes.impl` works. But if the target
    itself has type arguments, we reach nested `[...]`:
    `Show[Token]~Parser[Token]@lib.impl`. Tokenization of
    filenames with multiple `[...]` is well-defined but dense.
    Recommendation: keep filenames flat when possible; push
    complex generics into the body's generic slot.

E2. Bounded blanket with trait argument:
    `From[Vec]~$(Clone).impl` — blanket target with bound,
    trait takes an arg. Parses under the filename grammar but
    reads heavy. Alternative: move the trait arg into the body.

E3. Multi-char operators in filenames — none present (aski
    names are ASCII Pascal / camel / alphanumeric), so no
    risk of `<=` or `=>` appearing.

E4. Case sensitivity — macOS default filesystems are
    case-insensitive. `Point.struct` and `point.struct` collide
    on macOS even though aski's case rule makes them different
    (Pascal vs camel). Since all top-level names are Pascal,
    this doesn't surface in practice — but stdlib-level
    conventions should enforce Pascal-only top-level filenames.

E5. Filename length — some filesystems cap at 255 bytes. An
    impl filename like
    `VeryLongTraitName[VeryLongArgumentType]~VeryLongTargetName@very_long_module.impl`
    can push this. Mitigation: such cases are structural hints
    that the trait/target names should be refactored. II-L
    naturally pressures toward shorter, clearer names.

E6. Colons in filenames — some filesystems disallow `:`. Aski
    paths internal to source use `:` (`Char:Upper:A`) but on
    disk this maps to directory hierarchy (`Char/Upper/A.enum`
    or equivalent). Filename-level paths never use `:`; they
    use `/` (directory) or `@` (module qualifier) or `~` (impl
    separator) or `[]` (args).

E7. The `_` prefix conflicts with some name choices — a type
    semantically named "Underscore" would need special handling.
    The `_` prefix is reserved for visibility; names starting
    with `_` followed by Pascal are private objects, not
    objects whose name legitimately starts with underscore.
    Unicode workaround not needed under ASCII-only filenames.

E8. Duplicate-stem collision — `Foo.enum` + `Foo.struct` in
    the same directory is a HARD ERROR (veric rejects). One
    name per directory regardless of kind. See
    `decomposition.md §7.9`.

E9. Derivation output — when derivations synthesize impls,
    where do those impls live? Proposed:
    `.build/derivations/*.impl` — filesystem-visible (not
    hidden in memory), build-managed (humans don't edit).
    See `decomposition.md §6.7`.

E10. Symlinks — veric's filesystem walk does NOT follow
     symlinks. A symlink following would produce two paths
     for one file (duplicate identity). See §7.10.

E11. Impl stem conflict when multiple bindings — if an impl
     has BOTH a trait arg in the stem AND an associated-type
     binding in the body, both forms encode the same info.
     Convention: prefer ONE encoding per impl, not both.
     Trait arg in stem when multiple impls want different
     args (e.g., From[String]~Token vs From[U32]~Token).
     Associated-type binding in body when the impl has ONE
     canonical args set.

E12. Name lookup performance — filesystem walks for every
     module lookup sound slow. Mitigation: veric builds a
     name-index on first walk, invalidates on file change.
     Standard incremental-build technique; not an II-L
     problem.

## PRECEDENT

II-L is not novel at every level. Its components appear in
many languages and systems; the completeness of the commitment
is what distinguishes v0.21.

  Java — one public class per file (filename = class name,
         filesystem enforces). Kind, visibility, imports still
         in source.
  Smalltalk — identity is location via a class browser, but
         locations live in a proprietary image; no filesystem
         exposure.
  OCaml — .mli / .ml pairing, two surfaces per module.
         Types, constructors, values share both files.
  Plan 9 — "everything is a file" for system resources; did
         not apply to source code.
  Unison — content-addressed definitions; names are tags
         on hashes. No standard filesystem representation.
  Hazel — structure editing in a custom editor; filesystem
         is secondary.
  Clojure — one namespace per file by convention.
  Elm — one module per file, enforced.

Each moved 1–2 metadata channels to the filesystem or to a
structural medium. v0.21 moves six: name, kind, visibility,
module, imports, and sub-structure. None of the predecessors
pushed all six onto the standard filesystem simultaneously.

The filesystem is the universal tree every tool already knows.
Moving six channels onto it means aski's identifier graph
gets native support from: every shell, every editor, every
version-control system, every code-search tool, every
incremental-build system, every LLM that reads files. No
custom tooling required.

## WHAT v0.20 HAD THAT v0.21 HAS ELSEWHERE OR DOESN'T NEED

Condensed inventory.

RETIRED FROM SOURCE (moved to filesystem):
  Module header `(Name [Imports])`
  Imports line inside module header
  Root visibility `@` prefix on Enum/Struct/Newtype/Const/Trait/Impl
  Root delimiters `(...)` / `{...}` / `(|...|)` / `{|...|}` / `[|...|]`
  Root name declaration inside delimiter
  Impl-name-at-position-0 inside `[...]`

MOVED TO FILENAME (new syntax on disk):
  Enum name           → StemName.enum
  Struct name         → StemName.struct
  Newtype name        → StemName.newtype
  Const name          → StemName.const
  Trait name          → StemName.trait
  Impl identity       → TraitName~TargetName.impl (with optional [Args], @Module, $, $(...))
  Visibility          → `_` prefix (private) / no prefix (public)
  Module              → directory name
  Imports             → per-directory `imports` file
  Kind                → file extension (.enum / .struct / ... / .impl / .effect / ...)
  Platform            → `.platform.impl` / `.platform.effect` middle segment
  Test mode           → `.test-impl` extension
  Bench mode          → `.bench-impl` extension
  Derivation          → `.derivation` extension

STAYED IN SOURCE (body-level):
  Field visibility `@` (inside .struct bodies)
  Newtype transparency `@Type` (inside .newtype body)
  Generic slot `{$Param ...}`
  Super-trait bounds `{Super1 Super2}`
  Method signatures and bodies
  Method-level generics `?{$Param}`
  Associated-type bindings `(AssocName Type)` in impls
  Match / loop / iteration / block / or-pattern / local decl
  Path syntax `Type:Variant:...:method(...)`
  Borrow / mutable / origin / view-type sigils
  Early return `^`, try-unwrap `?`
  Binary / unary / postfix operators
  Literals inside bodies
  Struct construction `{ :Type (:Field Expr) ... }`
  Char library access `Char:Upper:A` etc. (U16)

## END NOTES

This file is a reference by example. It is not the grammar —
the grammar lives in `.synth` files per surface. Each surface
gets a Root.synth describing its body content. The outer
identity (name, kind, visibility, module) is drawn from the
filesystem walk; per-surface grammar handles the body.

For architectural detail on the surfaces, see:
  decomposition.md    — II-L principle derivation (the foundational
                        research that led to v0.21; supersedes the
                        earlier per-concern multi-surface proposal
                        that was retired on 2026-04-21)

For open questions, see `gap-analysis.md`.
For settled decisions, see `design.md`.
For proposal status levels, see `bridge/paradigm.md`.

v0.21 = II-L applied. Every section above either replaces or
defers to the filesystem a channel that v0.20 carried in source.
The file is what it refers to. Nothing more.
