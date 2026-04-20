# 01 — The Surface Inventory

*Every surface in the proposed multi-surface aski, with its purpose,
extension, dialect set, and what can and cannot live inside.*

[← 00-vision](00-vision.md) · [02-types →](02-types.md)

---

# The core insight

A **surface** is a grammar family for a specific file kind. Each file
of that kind is a contribution to the program. The compiler dispatches
by file extension to the surface's root dialect.

Today's five surfaces:

```
core    .core   pure type definitions                   corec
aski    .aski   modules, libraries (types+traits+impls) askic
synth   .synth  grammar self-description                askicc
exec    .exec   executable programs                     askic
rfi     .rfi    Rust foreign interface declarations     askic
```

The proposal: **decompose `aski` into surfaces by concern**, and add
a few more surfaces for capabilities the current design can't reach.

---

# The target surface inventory (maximal)

```
;; Bootstrap
core            .core           types for aski-core / synth-core / veri-core    corec

;; User-facing language surfaces (split from current aski)
types           .types          enums, structs, newtypes, consts                askic
traits          .traits         trait declarations only                         askic
impls           .impls          named trait implementations                     askic
effects         .effects        I/O-crossing impls (impure operations)          askic
derivations     .derivations    rules that synthesize impls from type shape    askic
test-impls      .test-impls     replacement impls for test builds               askic
bench-impls     .bench-impls    replacement impls for benchmark builds          askic

;; Grammar / meta
synth           .synth          grammar self-description                        askicc

;; Programs
exec            .exec           executable programs                             askic

;; Interop
rfi             .rfi            Rust foreign interface declarations             askic

;; Future (proposed, not yet)
async-impls     .async-impls    impls whose methods run under a scheduler      askic
unsafe-impls    .unsafe-impls   impls using capabilities outside sema invariant askic
platform-impls  .<platform>.impls   platform-specific impl variants             askic
```

**8 user-facing surfaces** plus core/synth/exec/rfi = 12 total.

---

# Why each surface exists

## types — pure shape, zero behavior

File extension: `.types` (or retain `.aski` for backward compat,
renamed)

What it contains:
- Enum declarations
- Struct declarations
- Newtype declarations
- Const declarations
- Module header (name + imports)

What it cannot contain:
- Method definitions
- Trait declarations
- Trait implementations
- RFI function signatures
- Executable statements

Why it's useful:
- Type-only compilation for tooling
- Schema sharing without behavior disclosure
- Sharp dependency graph (types change → impls recompile; impls
  change → types cached)
- Doc generation on shape alone
- The bootstrap precedent (`.core` files already do this)

## traits — interfaces, no implementations

File extension: `.traits`

What it contains:
- Trait declarations
- Associated types
- Associated constants (decl, optional default)
- Method signatures (decl, optional default body)
- Super-trait constraints
- Module header

What it cannot contain:
- Type declarations (those live in `.types`)
- Trait implementations (those live in `.impls`)

Why it's useful:
- Protocol-first design (define trait before impls exist)
- Clean cross-module trait libraries
- Docs split by role (interface docs separate from impl docs)
- Trait evolution via deprecation markers lives here

## impls — named behavior, coherence-verified

File extension: `.impls`

What it contains:
- Named trait implementations: `[@ImplName Trait Target [body]]`
- Method bodies (the only surface where method bodies live)
- Local declarations within method bodies
- Module header

What it cannot contain:
- Type declarations
- Trait declarations
- Direct effects (those live in `.effects`)

Why it's useful:
- Named impls with scope-based activation (§3 in 00-vision)
- Orphan-rule relaxation
- Coherence verified by veric across all `.impls` files
- Multiple impls per (Trait, Target) supported
- Linker-level impl selection

## effects — the impure boundary

File extension: `.effects`

What it contains:
- Impls whose methods cross the I/O boundary
- Impls that perform mutation visible outside method scope
- Impls that read clocks, random sources, environment
- Module header

What it cannot contain:
- Pure computations (those belong in `.impls`)

Why it's useful:
- Effect tracking at the link level
- Provably pure libraries (ones that don't import `.effects`)
- Composable effect auditing — grep the import graph
- Platform isolation (different `.effects` per platform)

The rule: **if a method can produce different results on the same
input across runs, it belongs in `.effects`.**

## derivations — first-class macros

File extension: `.derivations`

What it contains:
- Derivation rules matching type shapes to trait impls
- Rule metadata (which trait, which type pattern, how to synthesize)
- Module header

What it cannot contain:
- Direct impls (those live in `.impls`)
- Types or traits

Why it's useful:
- Replaces Rust's `#[derive]` with first-class rules
- Rules are inspectable, diffable, overridable
- Synthesis happens at link time, integrated with coherence
- No attribute sugar needed — derivation is structural

## test-impls — swap in during tests

File extension: `.test-impls`

What it contains:
- Named impls designed to replace real impls in test builds
- Mocks, fixtures, test doubles
- Module header

What it cannot contain:
- Anything that would run outside a test build
- Production behavior

Why it's useful:
- Test mocking at link time (not source-conditional)
- No `cfg(test)` gymnastics
- Clear separation of test infrastructure from production code
- Each test build links `.test-impls` in place of real impls

## bench-impls — swap in during benchmarks

File extension: `.bench-impls`

Similar to test-impls but targeted at benchmark builds. Lets you:
- Instrument methods (record call counts, timings)
- Pre-populate caches for fair timing
- Disable paths that skew benchmarks

## platform-impls — capability systems

File extension: `.browser.impls`, `.node.impls`, `.native.impls`,
`.wasm.impls`, `.ios.impls`, …

What it contains:
- Platform-specific impls of shared traits
- Trait-target pairs whose implementations vary by platform
- Module header

Why it's useful:
- One aski codebase, many platforms
- Build selects which platform surface to link
- No runtime capability check needed — it's all link-time
- Structural equivalent of Elm ports

## async-impls — proposed, future

File extension: `.async-impls`

Reserved for impls whose methods run asynchronously. Async could be
modeled as an effect-like surface — any code importing `.async-impls`
runs under a scheduler. Details TBD.

## unsafe-impls — proposed, future

File extension: `.unsafe-impls`

Reserved for impls that use capabilities the sema invariant doesn't
guarantee (raw memory access, FFI pointer manipulation, etc.). Every
such impl is visible in the import graph. Auditing for unsafe code
becomes mechanical.

---

# What dispatches where

Every source file is routed to a surface by its extension:

```
foo.types           → types surface Root.synth
bar.traits          → traits surface Root.synth
baz.impls           → impls surface Root.synth
boo.effects         → effects surface Root.synth
qux.derivations     → derivations surface Root.synth
my.test-impls       → test-impls surface Root.synth
my.browser.impls    → browser-platform-impls surface Root.synth
entry.exec          → exec surface Root.synth
native.rfi          → rfi surface Root.synth
Dialect.synth       → synth surface Root.synth
type.core           → core surface Root.synth
```

askicc handles all of them through the same dispatch table:
`HashMap<(SurfaceKind, DialectKind), Dialect>`. Adding a surface is
adding a row.

---

# The import model

Files import from other files. The cross-surface rules are what make
the architecture coherent:

- `.types` files can import ONLY from other `.types` files (and
  primitives).
- `.traits` files can import from `.types` files (for assoc type
  bounds, method signature types) and from other `.traits` files
  (for super-trait constraints).
- `.impls` files can import from `.types`, `.traits`, and other
  `.impls` (for impl-on-impl composition — e.g., a blanket impl
  referencing another impl's bound).
- `.effects` files can import everything `.impls` can plus other
  `.effects` files.
- `.derivations` files can import `.types` and `.traits`; they
  produce `.impls`-equivalent output.
- `.test-impls` / `.bench-impls` / platform-impls follow the same
  rules as `.impls`.
- `.exec` files can import everything — they are the program entry.
- `.rfi` files can import `.types` (for parameter and return types)
  and are imported by `.impls` / `.effects` that call external
  functions.

veric verifies these constraints.

---

# Size, discipline, and convenience

Concerns raised in the research doc about "too many files for small
programs" are real. Possible answers:

- **Learning curve**: one-file mode that accepts combined content for
  tiny examples. Compiler routes content to surfaces internally.
- **Directory convention**: `shapes/circle.types`,
  `shapes/circle.impls` — colocation maintains "everything about
  Circle is in shapes/circle.*".
- **Tooling**: IDE "gather by type" view reconstructs the one-file
  perspective without the source duplication.
- **Mature projects reward it**: enterprise codebases with 50+
  modules find the split load-lowering, not ceremony.

---

# What you'll see in the following docs

- [02-types.md](02-types.md) — every Rust type concept in `.types`
  surface
- [03-traits.md](03-traits.md) — every Rust trait concept in
  `.traits` surface
- [04-impls.md](04-impls.md) — `.impls` with the named-impl /
  coherence / scope-activation model
- [05-effects-and-platforms.md](05-effects-and-platforms.md) —
  `.effects` + platform-impls
- [06-derivations-and-testing.md](06-derivations-and-testing.md) —
  `.derivations` + `.test-impls`
- [07-sema-specialization.md](07-sema-specialization.md) — same
  source, different sema binary
- [08-bootstrap.md](08-bootstrap.md) — `.core` was first; self-hosting
- [09-rust-complete.md](09-rust-complete.md) — comprehensive Rust
  feature coverage
- [10-transition.md](10-transition.md) — how to get from v0.20 to
  here

[02-types →](02-types.md)
