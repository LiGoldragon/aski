# DSL-per-concern — exploratory research

*2026-04-20 · research, not a proposal — open space for Li to shape.*

The premise: aski's current "modules and libraries" surface hosts
types (enum/struct/newtype/const), trait declarations, and trait
implementations. Splitting those into separate surfaces is an
extreme restructure that could yield novel capabilities Rust and
its family can't express. This doc maps the venue.

# The idea

Three plausible splits of the current aski surface:

**Minimal — two surfaces.**
- `.types` — enums, structs, newtypes, consts, trait declarations (all "shape")
- `.impls` — trait implementations (all "behavior attachment")

**Canonical — three surfaces.**
- `.types` — enums, structs, newtypes, consts
- `.traits` — trait declarations only
- `.impls` — trait implementations

**Maximal — six-plus surfaces.**
- `.types` + `.traits` + `.impls` + `.derivations` + `.effects` + `.test-impls`

Combined with the existing `core` / `synth` / `exec` / `rfi` surfaces
and the implied growth (criome, possibly others), aski would host
somewhere between 6 and 11 surfaces depending on the split chosen.

---

# What it could enable (exhaustive inventory)

## 1. Types-all-the-way-down made structural

paradigm.md's commitment ("types all the way down, trait-methods as
the only form of behavior") is currently enforced by prose and by
method-only grammar. A surface split would enforce it *architecturally*:

- A `.types` file physically cannot contain a method body. No impls,
  no bodies, only shape.
- A `.impls` file physically cannot declare a new type. Only behavior
  attachment.

Violation becomes impossible, not merely discouraged.

## 2. Orphan-rule relaxation via global coherence

Rust's orphan rule: `impl ForeignTrait for ForeignType` is forbidden
to prevent coherence violations. Aski today inherits this because
impls live alongside types/traits in the same file — the "orphan"
case is moot because the impl has to live somewhere legal.

With a dedicated `.impls` surface:
- Any `.impls` file can impl any trait for any type from anywhere.
- Orphan rule dissolves — impls never live "in the type's module"
  because impls have their own universe of files.
- Coherence is enforced globally by veric: across all `.impls`
  files in the program, each (Trait, Type) pair can have at most
  one active impl. Conflicting impls are a link-time error.

Consequence: third-party modules can extend other modules' types
with any trait, with zero "newtype dance" overhead. **This is a
major ergonomic win over Rust for library ecosystems.**

## 3. Named impls with scope-based selection

The real unlock — if impls are separate artifacts, they can have
names:

```aski
;; fast.impls
[fastIter:Iterator TokenStream [ … tight-loop version … ]]

;; safe.impls
[safeIter:Iterator TokenStream [ … bounds-checked version … ]]
```

Multiple impls for the same (Trait, Target) pair coexist, disambiguated
by a named identifier. At the call site, you activate one:

```aski
(program [
  (use fastIter)            ;; select fast impl in this scope
  (tokens self.stream.iter)  ;; dispatches via fastIter
])
```

Different scopes activate different impls. **This is beyond Rust's
coherence model** — closer to Scala's implicit resolution (with
scope) or Haskell's named dictionaries.

Applications:
- **Benchmarking**: swap impls without source changes.
- **Progressive enhancement**: safe impl for dev, fast impl for prod.
- **Mocking for tests**: `testImpls.impls` replaces `real.impls`
  at link time, no conditional-compilation hacks.
- **Parallel implementation evolution**: `v1.impls` and `v2.impls`
  coexist during migration; modules pin which.
- **Feature toggling**: per-feature impl selection without
  preprocessing.

Coherence is still preserved — at any call site, exactly one impl
is statically resolvable. The difference is *which* impl is a
scope-controlled choice, not a global default.

## 4. Sema specialization by impl graph

sema is the bytes-are-the-type format. Today, the sema binary for a
program is determined by aski source + types. With a surface split
and named impls:

- The sema binary depends on the *impl graph* — which impls are
  linked, which are activated, in which scopes.
- The same aski source compiles to *different* sema binaries when
  linked with different impl sets.
- semac can produce platform-specific or mode-specific binaries
  (wasm-impls vs native-impls, release-impls vs debug-impls)
  without changing the source.

This is build-time monomorphization over impl choice — a
specialization axis that doesn't exist in Rust.

## 5. Effect surfaces (effect tracking at the build level)

Dedicate a surface (`.effects` or `.io-impls`) to impls that touch
the outside world:

- Reading files, network, stdout, clock access.
- Mutation of shared state.
- Anything impure.

A pure-aski program imports no `.effects` files. Veric tracks which
programs reach which effect surfaces transitively. This is:

- **Effect-tracking at the link level** rather than the type level.
- Lighter than Haskell's IO monad (no type annotations required).
- Composable: audit a program's side effects by listing its imported
  effect surfaces.
- Enables pure-by-default ecosystems — a library author advertises
  "no effects" by not importing any effect surface.

## 6. Derivation surface replacing `#[derive]`

Rust's `#[derive(Clone, Debug)]` generates impls from type shape at
compile time. With surfaces:

- `.derivations` files contain derivation *rules*: "for every Struct
  whose fields all impl Clone, generate Clone for the whole Struct."
- At link time, veric matches rules against types and synthesizes
  the corresponding impls.
- All impls — derived or hand-written — live in the impl graph. No
  distinction at sema level.
- Derivation rules are first-class, inspectable, overridable.

Replacement for attribute macros — grounded in the sema model rather
than tacked on.

## 7. Type-only intermediate representation

A `.types`-only compile produces a parse tree with no behavior. This
is useful for:

- **Schema sharing**: publish types without implementations.
- **IDE tooling**: autocomplete on types can run without loading
  impls. Faster, simpler.
- **Documentation generators**: render just the shape.
- **Cross-language interop**: a `.types` rkyv could be consumed by
  non-aski tooling (codegen for other languages that map to the
  same domain).

Today, aski-core carries everything; tooling has to load it all to
do anything. A split makes types-only analysis viable.

## 8. Incremental compilation sharpening

The dependency graph between surfaces is sharper when they're
physically separated:

- A `.impls` edit doesn't invalidate `.types` outputs.
- A `.types` edit invalidates only impls that use the changed types.
- veric's phase structure maps to surfaces: types first, traits next,
  impls last.

Nix-level caching keys per surface become precise. Rebuilds are
smaller.

## 9. Cleaner veric phase separation

Today veric has five verification tiers. With a surface split, each
tier maps to a surface:

- Types surface: name resolution within types, no trait/impl work.
- Traits surface: trait references into types, associated type bounds.
- Impls surface: trait-impl coherence, method signatures match decls,
  effect propagation.

Each phase has a narrower contract. Easier to reason about, easier
to parallelize.

## 10. Distributed domain modeling

Large systems often have clear team boundaries:

- `shared.types` — domain data (one team owns).
- `teamA.impls`, `teamB.impls` — each team owns behavior for their
  concerns.
- No conflicts, clean review boundaries.

**This is DDD (domain-driven design) enforced at the compilation
level**. Schema is canonical; behavior is federated; coherence is
verified.

## 11. Documentation as first-class split

Documentation tools today merge types and impls because source is
merged. With a split:

- Type docs list the shape. No "impls on this type" section in the
  type's doc.
- Impl docs list behavior. No "types this trait is implemented for"
  buried in trait docs.
- Cross-cut views are built by tooling rather than inferred from
  source layout.

Cleaner, more flexible documentation surfaces.

## 12. Testing as impl-surface swap

Unit testing:

```
src/
  shapes.types
  shapes.traits
  shapes.impls
  tests/
    mock-clock.impls       ;; test-only impl of Clock trait
    mock-storage.impls     ;; test-only impl of Storage trait
    test-harness.exec
```

The test build links `tests/mock-*.impls` in place of the real
impls. No `cfg(test)`, no feature flags. Just a different link graph.

## 13. Trait evolution (deprecation markers)

A `.traits` file can mark a trait as superseded:

```aski
@[| OldIter
  (superseded-by NewIter)     ;; hypothetical directive
  (next ~&self … )
|]
```

All impls of OldIter warn. A path exists to migrate. Trait evolution
becomes a first-class lifecycle event rather than a coordination
problem.

## 14. Capability systems (Elm ports, effect handlers)

Surface selection at build time becomes the capability system:

- `browser.impls` — impls for browser environment.
- `node.impls` — impls for Node.js environment.
- `native.impls` — impls for native desktop.

The same aski program ships to multiple platforms by linking
different impl surfaces. This is architecturally what Elm achieves
through ports, but structural rather than runtime.

## 15. Grammar simplification per surface

Surface-by-surface alternative counts at root dialect:

- Current aski root: 6 alternatives (Module, Enum, TraitDecl, TraitImpl,
  Struct, Newtype, Const) — 7 actually.
- `.types` root: 5 (Module, Enum, Struct, Newtype, Const).
- `.traits` root: 2 (Module, TraitDecl).
- `.impls` root: 2 (Module, TraitImpl).

Simpler root dialects → more delimiter budget available per surface
for future extensions. E.g., `.impls` root has `()` / `[]` / `{}` /
`{||}` / `(||)` / `[||]` all unused except `[]` for TraitImpl — 5
delimiters free for impl-specific features (named impls, conditional
impls, impl groups, …).

## 16. Community code-organization convention

Rust has no enforced "impl lives near type" rule; conventions vary.
aski could make surface-per-concern the enforced convention,
eliminating a class of layout decisions. Pros: consistency. Cons:
rigidity.

---

# Grammar impact

Under the canonical three-surface split (types / traits / impls):

## Types.synth (Root)

```synth
#Module#(@ModuleName <Module>)
// *?_@_#Enum#(@EnumName ?{ +<GenericParam> } <Enum>)
// *?_@_#Struct#{@StructName ?{ +<GenericParam> } <Struct>}
// *?_@_#Const#{| @ConstName <Type> @Literal |}
// *?_@_#Newtype#(| @NewtypeName ?{ +<GenericParam> } <Type> |)
```

5 alternatives — tight.

## Traits.synth (Root)

```synth
#Module#(@ModuleName <Module>)
// *?_@_#TraitDecl#[| @TraitName ?{ *<GenericParam> *:TraitName } +<TraitItem> |]
```

2 alternatives — trivially decidable.

## Impls.synth (Root)

```synth
#Module#(@ModuleName <Module>)
// *?_@_#TraitImpl#[@TraitName ?{ +<GenericParam> } <Type> [+<TraitImplItem>]]
;; with named impls:
// *?_@_#NamedImpl#[@implName _:_ @TraitName ?{ +<GenericParam> } <Type> [+<TraitImplItem>]]
```

2-3 alternatives. Room to grow.

## Cross-surface references

- Types surface: no external references (pure data).
- Traits surface: references Types (associated type bounds, method
  parameter types).
- Impls surface: references Types and Traits.

The existing `<:surface:Name>` mechanism handles this cleanly.

---

# Key open design questions

## Q1. Coherence model

If multiple impls for the same (Trait, Target) pair are allowed:

- How are conflicting active impls in the same scope rejected?
- Is selection by explicit `use fastIter` or by lexical precedence?
- Can a library re-export an impl under a different name?
- What happens at sema time if no impl is selected for a called trait method?

## Q2. File naming and count

Five-surface aski is already aggressive. Adding types / traits /
impls to get 7+ surfaces is noisy for small projects. Mitigations:

- Convention: colocate `shapes.types`, `shapes.traits`, `shapes.impls`
  in the same directory — directory is the "module."
- Auto-combine for tiny projects: one `.aski` file continues to accept
  everything for learning / throwaway code; larger projects split.
- Compile-time fusion: conceptually separate, physically one file
  for small scopes.

## Q3. Does `.traits` need its own surface?

Traits-only files might be low value if most trait decls live near
their primary implementing types. Collapsing to two surfaces (.types
holds traits too, .impls holds implementations) might be cleaner.

Counter-argument: traits are *interfaces*, structurally distinct from
types. A pure trait surface enables type-less interface libraries
(protocol definitions without reference impls).

## Q4. Imports model

Currently a module imports another module's names. With a surface
split:

- Does a `.impls` file import types by name or by module path?
- Can a `.impls` file add impls to types from *any* source, or only
  types in its direct dependency graph?
- Does impl scope follow module imports or is it global (all `.impls`
  in the program contribute unconditionally)?

## Q5. Small-program discipline

Does aski require the split even for a 50-line program? If yes, the
ceremony overhead is high. If no, the "convenience" combined file
erodes the paradigm commitment. Possible middle ground: the split
is *always* the logical model, but the surface syntax could accept
a combined file that internally routes its contents to the right
surfaces.

---

# Precedent

| Language | Split model | Notes |
|----------|-------------|-------|
| OCaml | `.mli` / `.ml` | Signature file vs implementation file. File pairs. |
| C / C++ | `.h` / `.c` or `.cpp` | Declarations vs definitions. Separate compilation units. |
| Haskell | Single file, export lists | Module-level interface control; no surface split. |
| Scala | Single file, `trait` / `class` / `implicit` | Separation is syntactic, not file-level. |
| TypeScript | `.d.ts` type declarations | Types-only files are a real artifact. |
| Protobuf / Thrift / gRPC | `.proto` / `.thrift` schemas | Schema-only; impls in target language. |
| Rust | Single file `.rs` | Convention only — no enforced split. |
| Nix | `.nix` | No split; same file holds types and behavior via language-level traits. |

None split at the granularity aski would — separate surfaces for
*types* vs *traits* vs *impls* is unprecedented in mainstream
languages. Haskell's typeclass model is the closest conceptual
analogue, but lives in one file.

---

# Risks and costs

## R1. Navigation cost

Finding "everything about `Circle`" now requires looking in:
- `shapes.types` (the type def)
- `shapes.traits` (traits mentioning Circle)
- Multiple `.impls` files (impls for Circle)

Mitigation: tooling that presents a unified view. IDE-level gather.

## R2. Small-program overhead

A toy program needs minimum 3 files instead of 1. Onboarding friction.

Mitigation: auto-fusion for small cases, or accept that aski programs
start at "module" not "script."

## R3. Parser pipeline complexity

askic handles 5 surfaces today. Going to 7-8 doesn't multiply
complexity — each surface is self-contained — but adds linear overhead.

## R4. Versioning skew across surfaces

Change `Circle` in `.types` → existing `.impls` files referencing the
old shape silently break until veric catches it.

Mitigation: strong versioning / verification at link time. Nothing
Rust doesn't already have.

## R5. Impl resolution complexity

Named impls with scope activation is a new rabbit hole:
- How does the programmer debug "which impl is active here"?
- Error messages for missing-impl vs conflicting-impl need clarity.
- The mental model shift from "impl is where the type is" to "impl
  is where its file is" takes adjustment.

## R6. Ecosystem fragmentation risk

If named impls are too flexible, the ecosystem could have "fast vs
safe vs other" variants of the same impl proliferate. Convention
and tooling discipline mitigate but don't prevent.

## R7. "Impls are code" — loss of locality

Reading source to understand what a type does requires opening
multiple files. Some programmers find this worse than one-file.

---

# Options summary

## Option A — minimal (two surfaces)
- `.aski` (or renamed `.types`): types + trait decls
- `.impls`: implementations only
- Smallest change. Biggest idea (separating behavior-attachment) lands.
- Doesn't unlock named-impl selection as cleanly because impls aren't
  named at their file.

## Option B — canonical (three surfaces)
- `.types`, `.traits`, `.impls`
- Clean ontological split.
- Opens most of the 16 possibilities above.
- Named impls, capability surfaces, derivation, testing by swap all
  fit naturally.

## Option C — maximal (six-plus surfaces)
- `.types`, `.traits`, `.impls`, `.derivations`, `.effects`, `.test-impls`
- Full vision. Every concern gets its own home.
- Highest overhead. Highest expressiveness.
- Strong opinion; aski becomes a language where file boundaries
  carry semantic weight throughout.

## Option D — surface-less convention
- Keep single `.aski` file, use conventions + tooling to enforce the
  split logically.
- Lowest cost, lowest enforcement.
- Doesn't capture most of the wins (coherence, impl selection,
  platform surfaces).

---

# Biggest question for Li

Is the goal:
- **(a)** A paradigm enforcement mechanism (split types from behavior
  because the paradigm says so)?
- **(b)** A novel-feature unlock (named impls, capability surfaces,
  effect tracking)?
- **(c)** Both?

(a) argues for a clean simple split (Option A or B). (b) argues for
deeper restructure with named impls and coherence rules (Option B or
C). (c) is probably Option B with room to grow into C.

The minimum viable piece that unlocks everything else is
**separating `.impls` from everything else**. Once impls are their own
surface with their own file identity, named-impl selection becomes
straightforward, capability surfaces are just "specialized impl
surfaces," and effect tracking is "effects are impls that touch the
world, in dedicated surfaces."

Recommendation for a next decision: pick a target scope (A / B / C)
and then design the coherence / impl-selection model around it.
Grammar and tooling follow from those two calls.
