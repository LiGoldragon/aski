# 10 — Transition Plan

*From aski v0.20 to multi-surface.*

[← 09-rust-complete](09-rust-complete.md) · [index →](../multi-surface.md)

---

# Current state (v0.20, 2026-04-20)

Five surfaces: `core`, `aski`, `synth`, `exec`, `rfi`.

- `.core` — already types-only (the precursor).
- `.aski` — hosts types + traits + impls together.
- `.synth` — grammar definitions.
- `.exec` — executable programs.
- `.rfi` — foreign interface declarations.

Missing from the multi-surface target:
- `.types` (or rename `.aski`)
- `.traits`
- `.impls`
- `.effects`
- `.derivations`
- `.test-impls`
- `.bench-impls`
- platform-specific surfaces (`<platform>.impls`, `<platform>.effects`)
- `.async-impls` (future)
- `.unsafe-impls` (future)

---

# Transition strategy

Do it in **waves**, each one locally verifiable, each one reversible.

---

## Wave 1 — introduce `.impls`, keep `.aski` combined (smallest step)

The first win: pull impls out of `.aski`.

### Actions

1. Add `.impls` surface:
   - askicc gets `source/impls/` with `Root.synth` accepting
     `[@ImplName Trait Target [body]]` form (named impl grammar).
   - synth-core adds `SurfaceKind::Impls`.
   - aski-core needs no changes (TraitImpl type already exists).

2. `.aski` files continue to accept everything they do today
   (types + trait decls + impls), for backward compatibility.
   Mark `.aski` impls as deprecated in CLAUDE.md.

3. Named impl: the existing `TraitImpl` grammar gains a leading
   `@ImplName` slot in `.impls` surface's Root.synth (optional in
   v0.20, required in multi-surface).

4. Add scope-activation grammar: `{ImplName}` at statement
   position, a new Statement.synth alternative.

5. veric gains a pre-coherence phase: for each (Trait, Target) pair,
   collect impls, resolve activation, emit impl graph.

6. Migrate stdlib-tier impls first (the primitives, if and when
   they're written). Real user programs migrate later.

### Outcome

Impls can live in their own files. Named impls are available. Scope
activation works. No breaking changes to existing `.aski`.

---

## Wave 2 — introduce `.types` and `.traits`, retain `.aski` as legacy

### Actions

1. Add `.types` surface:
   - askicc gets `source/types/` with `Root.synth` accepting Enum /
     Struct / Newtype / Const / Module (no TraitDecl, no TraitImpl).
   - synth-core adds `SurfaceKind::Types`.
   - aski-core needs no changes.

2. Add `.traits` surface:
   - askicc gets `source/traits/` with `Root.synth` accepting
     TraitDecl + Module.
   - synth-core adds `SurfaceKind::Traits`.

3. `.aski` remains a combined surface, parseable but deprecated.

4. Provide a migration helper: a tool that splits a `.aski` file
   into `.types` / `.traits` / `.impls` companions based on content.

### Outcome

New projects can use the split surfaces from day one. Old `.aski`
code continues to work.

---

## Wave 3 — `.effects` surface

### Actions

1. Add `.effects` surface:
   - askicc gets `source/effects/` with `Root.synth` identical to
     `.impls` in shape.
   - synth-core adds `SurfaceKind::Effects`.

2. veric learns: an `.effects` impl is allowed to call into `.rfi`;
   a `.impls` impl is not. Produce an error if the rule is violated.

3. Compute effect closure: for each program, walk imports and report
   which `.effects` are in the closure. Emit metadata alongside the
   sema binary.

4. Migrate existing I/O-touching impls from `.impls` to `.effects`
   per project.

### Outcome

Programs can advertise purity. Effect auditing is trivial.

---

## Wave 4 — `.derivations`

### Actions

1. Add `.derivations` surface:
   - askicc gets `source/derivations/` with `Root.synth` accepting
     derivation rules.
   - synth-core adds `SurfaceKind::Derivations`, `TagKind::Derivation`,
     and type-pattern language primitives (`StructOf`, `EnumOf`,
     `AllFields`, etc.).
   - aski-core adds `Derivation` type.

2. Introduce type-pattern syntax: `{StructOf {$Struct} {AllFields
   Debug}}` at trait-bound position inside derivations.

3. veric's impl-graph phase is extended: for each type in the
   program, for each derivation rule whose pattern matches, synthesize
   the corresponding impl and add to the graph.

4. Start with rules for core traits: Clone, Debug, Eq, Hash. Rules
   apply globally to every matching type.

### Outcome

`#[derive]` equivalent, first-class. Derivations are inspectable.

---

## Wave 5 — `.test-impls` and `.bench-impls`

### Actions

1. Add `.test-impls` and `.bench-impls` surfaces:
   - askicc gets them with Root.synth matching `.impls`.
   - synth-core adds SurfaceKind variants.

2. Build system learns:
   - Test build: link `.impls` + `.test-impls`; for overlapping
     (Trait, Target), `.test-impls` wins via coherence precedence.
   - Bench build: link `.impls` + `.bench-impls`.

3. Migrate test mocks from ad-hoc patterns to `.test-impls`.

### Outcome

Testing without `cfg(test)`. Bench mocking without conditional code.

---

## Wave 6 — platform surfaces

### Actions

1. Introduce extension-based platform tagging: `foo.native.impls`,
   `foo.browser.impls`, `foo.native.effects`, `foo.browser.effects`.

2. askicc parses these into `SurfaceKind::{Platform}Impls` etc. The
   SurfaceKind enum grows a small number of platform tags; extensible.

3. Build system accepts a `--platform=…` flag. Links only the matching
   platform surfaces.

4. veric verifies: a program linked with `--platform=browser` uses
   only `browser.*` surfaces + shared surfaces. Cross-linking is
   caught.

### Outcome

One codebase, many platforms. Capability-at-build-time.

---

## Wave 7 — async, unsafe (future)

Reserved for when the language needs them. `.async-impls` and
`.unsafe-impls` follow the `.effects` pattern — same grammar as
`.impls`, different constraint at the surface level.

---

# The deprecation path for `.aski`

After waves 1–4, `.aski` is a combined surface that's fully
expressible via `.types` + `.traits` + `.impls`. Two options:

### Option A — retire `.aski`

Move all content to split surfaces. Deprecate `.aski`. Tooling flags
remaining `.aski` files. Eventually remove the surface.

### Option B — retain `.aski` as a "module shortcut"

Keep `.aski` for small projects and one-file learning. Internally,
the compiler routes `.aski` contents to virtual split surfaces.
User sees one file; pipeline sees the proper structure.

Recommendation: Option B during transition; Option A for mature
codebases. Small projects benefit from the one-file form; enterprise
projects benefit from the split. Either works with the architecture.

---

# Tooling changes

- **askicc** — adds surface parsers, one per new surface. Each is a
  narrow Root.synth plus whatever dialect files the surface needs
  (most share the existing Expr / Type / etc. from aski).
- **askic** — dispatches more extensions; routes each to the correct
  surface's Root.
- **veric** — gains the pre-coherence phase (impl graph), the effect
  closure computer, the derivation applier, the platform selector.
- **semac** — emits specialization traces; accepts the impl graph
  as an additional input.
- **domainc** — reads `.types` rkyv; no change to core function.
- **rsc / askid** — learn about named impls; generate per-impl Rust
  code (rsc) or multi-file aski (askid).

Each tool's changes are bounded and testable.

---

# Backward compatibility

Every wave preserves existing code. The migration is **opt-in**.
Projects move when they want, not when the language forces them.

The `.aski` surface continues to work throughout. Only when a project
actively splits its files does it adopt the new model.

---

# Performance expectations

- Compile time: no increase per file. More files means more parallel
  parsing opportunities. Large codebases compile faster.
- Binary size: named-impl specialization may reduce binary size (less
  monomorphization bloat).
- IDE experience: `.types`-only analysis is faster than loading whole
  programs for autocomplete. Expect snappier tooling.

---

# Estimated effort (rough)

- Wave 1 (impls surface): 2–3 weeks — mostly askicc + synth-core
  changes, veric coherence phase.
- Wave 2 (types + traits surfaces): 1–2 weeks — parser dispatch
  + migration helper.
- Wave 3 (effects): 1–2 weeks — mostly veric constraint logic.
- Wave 4 (derivations): 3–4 weeks — new grammar for patterns, new
  aski-core type, veric synthesis logic.
- Wave 5 (tests + benches): 1 week — build system + coherence
  precedence.
- Wave 6 (platforms): 1–2 weeks — extension parsing + build flag.
- Wave 7 (async / unsafe): deferred.

Total on the order of **2–3 months** of focused work to land waves
1–6. Achievable; each wave ships independently.

---

# Decisions that unblock each wave

## Wave 1 (impls)

- Commit to named impls with scope activation.
- Pick activation syntax (`{ImplName}` vs alternatives).
- Decide coherence-precedence rules (most-specific-wins, scope-inner-
  wins, file-declaration-order as tiebreaker).

## Wave 2 (types + traits)

- Decide whether `.aski` stays combined or gets renamed.
- Decide `.types` vs `.types-and-traits` (minimal split).

## Wave 3 (effects)

- Decide what counts as an effect. RFI is clearly effectful.
  Mutation-of-passed-in-args — is that effectful? (Probably not;
  it's in-scope mutation.)
- Fine-grained vs coarse-grained `.effects` files.

## Wave 4 (derivations)

- Commit to the type-pattern language (what can rules match on).
- Decide derivation resolution order (most-specific by pattern, tied
  by file-declaration order).

## Wave 5 (tests + benches)

- Build system architecture (currently nix; may need lojix integration).

## Wave 6 (platforms)

- Which platforms to target first (native, browser, wasm, node).
- Extension naming convention (`foo.native.impls` vs `native/foo.impls`).

---

# The shape of victory

A mature aski codebase, post-transition:

```
my-app/
  src/
    shapes.types
    shapes.traits
    shapes.impls
    storage.effects
    parse.impls
    parse.derivations
    main.exec
  tests/
    shapes-test.test-impls
    parse-test.test-impls
    test-runner.exec
  bench/
    parse-bench.bench-impls
    bench-runner.exec
  platforms/
    native.impls
    native.effects
    wasm.impls
    wasm.effects
  Cargo-equivalent.toml
```

Every file has exactly one job. Every file extension says what the
file is for. The structure is the architecture.

This is where we're going.

---

# The one sentence

Take the `.core` precursor pattern, extend it across every user-code
surface, and aski becomes a language where **the filesystem IS the
architecture** — a property no mainstream language has achieved.

---

# Links out

- [multi-surface index](../multi-surface.md)
- [dsl-per-concern.md](../dsl-per-concern.md) — original research
- [paradigm.md](../bridge/paradigm.md) — spec-status levels
- [design.md](../design.md) — core aski design
- [RESTART-CONTEXT.md (Mentci)](../../../Mentci/RESTART-CONTEXT.md) — session state

---

*End of series.*
