# 08 — The `.core` Precursor and Self-Hosting

*Why the multi-surface model isn't speculation: it's already running.*

[← 07-sema-specialization](07-sema-specialization.md) · [09-rust-complete →](09-rust-complete.md)

---

# The existing precedent

Aski today has five surfaces. One of them is named `core`, and it
is **exactly the types-only surface the proposal calls `.types`**.

Today:
```
aski-core/core/primitive.core
aski-core/core/module.core
aski-core/core/domain.core
aski-core/core/trait.core
aski-core/core/type.core
aski-core/core/origin.core
aski-core/core/param.core
aski-core/core/expr.core
aski-core/core/statement.core
aski-core/core/pattern.core
aski-core/core/body.core
aski-core/core/program.core

synth-core/core/dialect.core

veri-core/source/program.core
```

Each `.core` file contains **only type definitions**. No methods. No
trait impls. No executable code. Just enum / struct / newtype / const
declarations, plus a module header.

corec reads these files. corec emits Rust with rkyv derives. The
output is consumed by:
- **askicc** (serializer of grammar rkyv)
- **askic** (parser producing aski-core rkyv)
- **veric** (consumer of aski-core, producer of veri-core rkyv)
- **semac** (consumer of veri-core, producer of sema)
- **domainc** (consumer of program rkyv, emitter of domain Rust)

**Every downstream tool in the pipeline consumes corec's output of a
types-only surface.** The entire system is bootstrapped on the
principle that shape alone is sufficient to define inter-tool
contracts.

---

# What the `.core` precedent proves

## 1. A types-only surface is viable

corec works. aski-core is stable. synth-core is stable. veri-core is
in flight. The types-only discipline has been enforced for the
entire v0.18 → v0.20 evolution, without anyone reaching for "but we
need methods in `.core`."

**If `.core` can be a types-only surface for bootstrap, `.types` can
be a types-only surface for user code.** The scale is larger, but
the mechanics are identical.

## 2. Separate surfaces compose cleanly

askicc produces a single rkyv containing dialects from five surfaces
(core, aski, synth, exec, rfi). askic dispatches by file extension.
The architecture for multiple surfaces feeding into one tool is
**in production**. Adding surfaces is linear.

## 3. Narrow grammar = maintainable grammar

The `.core` grammar is tiny. Root.synth for core is ~5 alternatives:
```
?#Module#(@ModuleName <Module>)
// *#Enum#( @EnumName <Enum> )
// *#Struct#{ @StructName <Struct> }
// *#Newtype#(| @NewtypeName <Type> |)
```

Because it's narrow, it's maintainable. corec is small. Refactoring
corec is tractable. The same narrow-grammar benefit extends to every
additional surface in the proposal.

## 4. The bootstrap chain works

```
core/*.core → corec → synth-core rkyv types
                    → aski-core rkyv types
                    → veri-core rkyv types
            
synth/*.synth → askicc (uses synth-core types) → dsls.rkyv
            
aski/*.core/*.aski/*.exec/*.rfi → askic (uses synth-core + aski-core)
                                → per-module rkyv
            
per-module rkyv → veric (uses aski-core + veri-core) → program.rkyv
            
program.rkyv → semac (uses veri-core + domain types) → .sema
            → domainc (uses program.rkyv)              → Rust
```

Every stage depends only on the previous. Every stage has a narrow
surface commitment. Every stage's output is rkyv. **This is the
multi-surface model already operating.**

The proposal extends the pattern from the bootstrap layer up to the
user-code layer. Same mechanics.

---

# Self-hosting by surface

At some point, aski compiles itself. The bootstrap currently uses
Rust:

- corec is Rust (reads `.core`, emits Rust).
- askicc is Rust (reads `.synth`, emits rkyv).
- askic will be Rust (reads user source, emits rkyv).
- etc.

Each of these tools has an input surface and an output surface.
**They are impls in the language sense** — behavior attached to a
specific trait (the tool's operation) for a specific type (the input
surface).

When aski grows to compile itself:

- corec's Rust implementation gets rewritten in aski.
  - Input: `.core` files.
  - Output: `.rs` files (via `.types` + an impl of `CodegenRust for
    CoreAstNode`).
  - The impl lives in a `corec.impls` file.
- askicc's Rust implementation gets rewritten in aski.
  - Input: `.synth` files.
  - Output: `dsls.rkyv` (via `.types` + an impl of
    `SerializeDsls for SynthFile`).

The **source layout of the compiler** is itself surface-structured:

```
corec-source/
  ast.types                 ;; the AST types
  codegen.traits            ;; the CodegenRust trait
  codegen.impls             ;; impl of CodegenRust for ast nodes
  main.exec                 ;; the entry point
  corec.rfi                 ;; RFI for file I/O, stdout
```

No free functions. No mixed-purpose files. The compiler demonstrates
the architecture it produces.

**Self-hosting is the ultimate proof of the model.** If aski compiles
itself cleanly under multi-surface discipline, the discipline is
sound.

---

# Precedent extension: `.traits` for the stdlib

Aski's stdlib will have trait declarations — `Clone`, `Debug`,
`Iterator`, `Display`, and so on. These are pure interfaces. They
belong in `.traits` files.

```
stdlib/
  traits/
    clone.traits
    debug.traits
    display.traits
    hash.traits
    eq.traits
    ord.traits
    iterator.traits
    ...
  impls/
    primitive-clone.impls     ;; Clone impls for U8/U16/U32/... (pure)
    primitive-debug.impls     ;; Debug impls for primitives
    collection-iter.impls     ;; Iterator impls for Vec / Option / ...
    ...
  derivations/
    derive-clone.derivations  ;; derivation rules for structs/enums
    derive-debug.derivations
    derive-eq.derivations
    ...
```

The stdlib becomes a browsable catalog:
- "Show me all traits" → list `stdlib/traits/`.
- "Show me all Clone impls" → grep `stdlib/impls/*.impls` for
  `Clone`.
- "How does struct-Debug derivation work?" → open
  `stdlib/derivations/derive-debug.derivations`.

This is the organizational shape of a principled standard library.
Rust's stdlib intermixes all of these.

---

# Precedent extension: crate structure

When aski has a package manager, crate layout follows surfaces:

```
my-crate/
  Cargo-equivalent.toml       ;; (lojix manifest)
  src/
    my-crate.types            ;; my types
    my-crate.traits           ;; my traits
    my-crate.impls            ;; my impls
    my-crate.effects          ;; my effects (if any)
    my-crate.derivations      ;; my derivations (if any)
  tests/
    my-crate-test.test-impls
    my-crate-test.exec
  bench/
    my-crate-bench.bench-impls
    my-crate-bench.exec
  platforms/
    native.impls
    browser.impls
    wasm.impls
```

A consumer of `my-crate` sees:
- Traits exported → the public interface
- Types exported → the public shape
- Impls → provided or missing (they depend on which impls are
  pub-exported)
- Effects → visible in the consumer's effect closure

Every dependency contributes surface-typed artifacts. The whole
ecosystem stays structured.

---

# The ecosystem aesthetic

A well-written aski library:

- Has a small `.types` file (shapes).
- Has a small `.traits` file (protocols it defines).
- Has a few `.impls` files (behaviors it provides, one per cohesive
  group).
- Has ≤1 `.effects` file (declarative about what world state it
  touches).
- Has a `.derivations` file if it offers structural-impl synthesis
  rules.
- Has `.test-impls` for its test fixtures.
- Has platform surfaces only if it's multi-platform.

Reading such a library is trivial. Types → what. Traits → how (by
contract). Impls → how (by provision). Effects → what world it
touches. Derivations → what it offers to other types.

**The filesystem becomes the table of contents.** This is the
aesthetic ideal.

---

# Concrete current-state mapping

Today's repos already structure themselves around surface-like
boundaries:

- `corec` — reads one surface, produces one artifact (the types-only
  bootstrap).
- `synth-core` — a types-only contract.
- `aski-core` — a types-only contract.
- `veri-core` — a types-only contract.
- `askicc` — a surface-crossing compiler (synth → rkyv).
- `askic` — a multi-surface frontend (any aski family surface → rkyv).
- `veric` — consumes one surface, emits another.
- `semac` — consumes one surface, emits sema.
- `rsc` — consumes sema, emits Rust.
- `askid` — consumes sema, emits aski.
- `domainc` — consumes one surface, emits Rust.

**Every tool in the pipeline is an impl, attached to a surface.**
The whole system is a multi-surface architecture that hasn't yet
formalized itself as one.

---

# The "we already did this" argument

The objection to multi-surface is "it's a big restructure." The
answer is: **the pipeline is the restructure.** We've built a chain
of surface-consuming, surface-producing tools from `.core` up. That
chain exists and works. Extending the model to user-facing code is
smaller than what's already been built.

This is not a leap. It's a generalization.

---

# From bootstrap to user-facing

The path from today to multi-surface user code:

1. **Rename** — `.aski` becomes `.types` for type-only content.
   `.aski` may be retained as a transitional combined surface (see
   [10-transition.md](10-transition.md)).
2. **Extract** — move trait decls into `.traits` files.
3. **Separate** — move impls into `.impls` files.
4. **Identify** — move effect-crossing impls into `.effects` files.
5. **Abstract** — extract derivation rules into `.derivations`.
6. **Test** — add `.test-impls` for test-only mocks.
7. **Platform** — if multi-platform, split impls by platform.

Each step is local. Each step preserves the behavior of the program.
Each step is verifiable by running the existing test suite against
each intermediate state.

---

# Closing thought on bootstrap

The reason this feels right is that **aski was born multi-surface**.
The pipeline is surfaces all the way down. The proposal isn't
introducing a new pattern — it's naming the pattern that's already
there and extending it to the layer above the bootstrap.

Rust discovered monomorphization by way of generics and then built
tooling around it. OCaml discovered signatures by way of abstract
types and then built a whole module system. aski discovers
multi-surface by way of bootstrap and then builds a language whose
grammar is already in five pieces, each doing one clean job.

**Extend the pattern. Climb the layer. Ship the language.**

---

# Next

The comprehensive proof: every Rust feature, translated into aski
through multi-surface. [09-rust-complete →](09-rust-complete.md)
