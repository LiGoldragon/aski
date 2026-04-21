# 00 — Vision

*Why split aski into many surfaces. The pitch.*

[← index](../multi-surface.md) · [01-surfaces →](01-surfaces.md)

---

# The premise

Every programming language commits to a layout. Rust puts types,
trait decls, and trait impls in the same file. Haskell puts data
decls and typeclass instances near each other. OCaml separates
signatures and implementations. Each layout encodes a philosophy.

**aski's philosophy is "types all the way down, trait-methods as the
only form of behavior."** Today that commitment is enforced mostly
by prose. The grammar forbids free functions; the spec rules out
tuples; the rest is author discipline.

The multi-surface proposal turns the philosophy into **architecture**.
A `.types` file physically cannot contain behavior. A `.impls` file
physically cannot declare a new type. A `.effects` file physically
cannot be compiled into a "pure library." Violation stops at the
file extension. Discipline becomes mechanical.

This is not documentation. This is the compiler saying no.

---

# The precedent — core was first

Aski already has a types-only surface. It's called `core`.

```
aski-core/core/domain.core
aski-core/core/trait.core
aski-core/core/expr.core
…
synth-core/core/dialect.core
veri-core/core/program.core
```

These `.core` files contain type definitions only. They cannot hold
methods. They cannot hold trait impls. corec reads them and emits
Rust with rkyv derives. Every downstream tool — askicc, askic, veric,
semac — consumes those types.

**The bootstrap works because the surface is narrow.** corec is
simple because it only has to handle types. The rkyv contracts are
stable because they express shape without behavior. The pipeline is
parallelizable because each stage sees a bounded surface.

The multi-surface design isn't a departure. It's **scaling up a
proven pattern**. If core works as a types-only surface, traits can
have their own surface. If traits work as a decl-only surface, impls
can have their own. If impls work as a behavior-attachment surface,
effects can have their own surface above that.

**Each layer is another `.core`-like bootstrap of the previous.**

---

# The four dimensions this unlocks

## 1. Paradigm enforcement at the file level

aski's commitment that "every method belongs to a trait" is currently
enforced by the aski-root grammar rule (no bare `fn`). With a
`.traits` + `.impls` split, the commitment becomes stronger: a method
exists only when a trait declares it AND an impl provides it. No
method can materialize in isolation. No behavior can orphan itself.

## 2. Coherence relaxed, but preserved

Rust's orphan rule exists because coherence can break if any crate
can impl any trait for any type. The rule is "you can only impl a
trait for a type if you own one of them."

With a dedicated `.impls` surface and veric as the coherence authority,
the rule flips: **any `.impls` file can impl anything, but veric
verifies that across the whole program, exactly one impl is active
for each (trait, target) pair in each scope.** Coherence is still
enforced at the program level — what's relaxed is the "must live in
the same crate as the trait or the type" rule that Rust uses as a
proxy for coherence. Aski enforces coherence directly (one active
impl per pair per scope) without needing crate-level ownership as a
proxy.

Library ecosystems flourish under this model. Extending foreign types
with foreign traits becomes natural, not a newtype workaround.

## 3. Impls as first-class artifacts

When impls have their own surface, they can have names:

```aski
;; fast.impls
@[FastIter Iterator TokenStream [
  (next ~&self {Option Token} [ ... tight-loop ... ])
]]

;; safe.impls
@[SafeIter Iterator TokenStream [
  (next ~&self {Option Token} [ ... bounds-checked ... ])
]]
```

Two impls of the same (Trait, Target) coexist. A call site selects
one:

```aski
(parseTokens ~&self [
  {FastIter}
  (tokens self.stream.iter)
  ;; self.stream.iter dispatches via FastIter inside this scope
])
```

This is **beyond Rust**. It's closer to Scala implicits with explicit
scope, or Haskell named dictionaries. It enables:

- Benchmarking without source change
- Mocking via test-impl swap at link time
- Progressive impl migration (v1 / v2 coexist, scopes pin which)
- Safety/performance tradeoffs per scope
- Platform-specific behavior by activating different impls

Rust cannot do this. aski can.

## 4. Effect tracking at the build level

Side effects — I/O, mutation of external state, clock reads — are
the hardest thing to reason about. Haskell tracks them in the type
system via monads. Rust uses the honor system.

With a `.effects` surface:

- Any impl that crosses the I/O boundary lives in a `.effects` file.
- A library that imports no `.effects` file is provably pure.
- veric computes the effect closure of every program from the import
  graph.
- Pure-by-default becomes the ecosystem norm.

No type annotations required. The proof lives in the link graph.

---

# What Rust has that aski covers through surfaces

All of these are covered by the multi-surface architecture plus the
paradigm commitment:

| Rust feature | aski surface expression |
|--------------|-------------------------|
| Types (enum / struct / newtype) | `.types` |
| Traits (decls with assoc types, consts, method signatures) | `.traits` |
| Trait impls (methods providing behavior) | `.impls` |
| Named impl selection | `.impls` (named), activation via scope or module header |
| Generic parameters, bounds, super-traits | carried in `.types` / `.traits` / `.impls` via `{$Value{Bound}}` syntax |
| Lifetimes | `'Place` origins in `.types` and `.impls` |
| References, views | `&` / `~&` + `{\|field\|}` view types |
| Arrays | Array primitive in `.types` (S11) |
| Option / Result | primitives in `.types` |
| Iterators | Iterator trait in `.traits`, impls in `.impls` |
| Closures | Callable trait + named-type impls (S4-A) or inline shape (S4-B/C) |
| dyn Trait | typed sigil in `.types` + coherence via `.impls` |
| impl Trait | existential pattern through `.traits` (to be designed) |
| Async | `.async-impls` surface analogous to `.effects` (future) |
| Error handling (Result, ?, panic) | primitives + `.traits` |
| Macros (#[derive]) | `.derivations` surface |
| cfg / conditional compilation | capability-surface swap at link time |
| Modules, visibility | module header + `@` visibility |
| unsafe | proposed `.unsafe-impls` surface — deliberate boundary |

What's left OUT by paradigm (and not by accident):

- Free functions (§No Free Functions)
- Native `loop {}` form (§No Native Infinite-Loop Form)
- Nameless tuples (§No Tuples)
- Higher-kinded types (§Generics)
- Dependent types (§Generics, "yet")
- Keywords in source (§Delimiter-First)
- Re-shadowing the same name (§Scopes Are a Tree)

Everything else fits somewhere.

---

# The compound effect

Each surface split does something small on its own. The power is
compounding:

- Types surface alone → paradigm enforcement, type-only tooling
- Add traits surface → clear interface/implementation boundary
- Add impls surface → orphan-rule relaxation, named impls, coherence
- Add effects surface → link-level purity
- Add derivations surface → first-class macros
- Add test-impls surface → link-time mocking
- Add platform surfaces → capability systems, multi-target builds
- Add async surface → effect-like async tracking

**Together, these turn aski from "a principled Rust-like" into "a
language whose architecture expresses its philosophy in every
compilation unit."**

And every surface is just another `.core`-scale bootstrap. The
pipeline is already built for this. askicc produces one rkyv with
all dialects across all surfaces. askic dispatches by
`(SurfaceKind, DialectKind)`. Adding surfaces is linear.

---

# What the series proves

The rest of this series walks every surface in detail, shows Rust's
feature set expressed through aski syntax, and demonstrates that the
paradigm commitments survive — and strengthen — when the surfaces
split out.

Read on.

[01-surfaces →](01-surfaces.md)
