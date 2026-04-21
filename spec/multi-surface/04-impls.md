# 04 — The `.impls` Surface

*Named trait implementations, globally coherent, scope-activated.
Beyond Rust.*

[← 03-traits](03-traits.md) · [05-effects-and-platforms →](05-effects-and-platforms.md)

---

# What `.impls` contains

Implementations. Each impl attaches a specific behavior to a specific
type via a specific trait. The grammar form:

```aski
@[ImplName TraitName Target [ *<TraitImplItem> ]]
```

- `@` prefix = public (impl is importable and activatable from other
  scopes).
- `ImplName` = impl name. Pascal. Bare Pascal token at position 0
  inside `[]`. **Every impl has a name.**
- `TraitName` = the trait being implemented.
- `Target` = the type receiving the behavior.
- `[ *<TraitImplItem> ]` = impl body. Method bodies, associated type
  bindings, associated const bindings.

**No type declarations. No trait declarations.** Just impls.

---

# The simplest impl

```rust
impl Describe for Element {
    fn describe(&self) -> Quality {
        match self {
            Element::Fire | Element::Air => Quality::Active,
            Element::Earth | Element::Water => Quality::Receptive,
        }
    }
}
```

```aski
@[Default Describe Element [
  (describe &self Quality (|
    ([Fire Air])      Active
    ([Earth Water])   Receptive
  |))
]]
```

`@Default` is the impl name. Every impl has a name. Unnamed would
collapse the named-impl model.

For (Trait, Target) pairs that only need one impl, convention is to
name it `Default` or something descriptive. The name becomes the
activation identifier.

---

# Why naming matters

Rust allows exactly one `impl Trait for Type` per crate. Coherence
enforces this globally.

aski allows **multiple named impls** of the same (Trait, Target)
pair to coexist in the codebase. Coherence is enforced per-scope:
at each call site, exactly one impl is resolvable. Which one is a
named, scoped choice.

```aski
;; fast.impls
@[FastIter Iterator TokenStream [
  (next ~&self {Option Token} [
    ;; unchecked index, cached state — raw speed
    ... tight-loop version ...
  ])
]]

;; safe.impls
@[SafeIter Iterator TokenStream [
  (next ~&self {Option Token} [
    ;; bounds-checked, invariants asserted
    ... defensive version ...
  ])
]]
```

Both impls land in the program's impl graph. Neither is "the" impl
by default.

---

# Impl activation (scope-based)

A call site activates a named impl before invoking trait methods on
the target type:

```aski
;; parser.impls
@[Default Parser Lexer [
  (parse ~&self Ast [
    {FastIter}                  ;; activate FastIter for Iterator Bytes in this scope
    (tokens self.bytes.iter)        ;; dispatches via FastIter
    (ast   self.build(tokens))
    ast
  ])
]]
```

`{ImplName}` is a scope-local activation directive. Inside the
enclosing `[body]`, every trait method on `Bytes` that matches a
`(Iterator, Bytes)` impl dispatches via `FastIter`. If the scope
exits without a nested `{…}`, the parent scope's activation
resumes.

The `{ImplName}` form uses `{…}` at statement position. `{}` at
statement is otherwise unused today — free for this delimiter-only
directive. **No keyword** — just the impl name(s) inside braces.
Multi-activation in one statement: `{FastIter SafeHash FastBytes}`
activates three impls together.

---

# Scope activation hierarchy

```aski
@[Default Engine App [
  (run ~&self [
    {SafeIter}                  ;; activate safe iter for this method
    (stream self.input.iter)         ;; safe
    
    (fastSection [
      {FastIter}                ;; override — fast within this block
      (chunk self.input.iter)        ;; fast
    ])
    
    (rest self.input.iter)           ;; back to safe
  ])
]]
```

Nested scopes layer activations. Inner wins. Exit restores outer.
Like lexical scoping of values, but for impl selection.

---

# Module-level default activation

A module can declare defaults for its whole scope. Module header
gains an activation block via `{}`:

```aski
;; app.impls
(App
  [iter-lib   Iterator]                 ;; import (as before)
  [parse-lib  Parser]                   ;; import
  {SafeIter DefaultParser})             ;; activations — delimiter-only, no keyword

@[Default Engine App [
  (run ~&self [
    (stream self.input.iter)            ;; SafeIter by default (module-level)
  ])
]]
```

`{…}` at module-header position (currently unused) = activation list.
Pascal names inside = impls to activate for the whole module. Scope-
level `{…}` overrides module-level activation.

Module-header activation lets whole files commit to a set of impls
without repeating `{…}` in every method. Per-scope overrides still
work.

---

# Default impl resolution

If a trait has only one impl named for a (Trait, Target), that one
is "the" default without explicit activation. If multiple exist,
the program must activate one — either in the file's module header
or in the immediate scope.

veric errors:
- **Unresolved**: two or more impls of (Trait, Target) visible with
  no activation → "ambiguous impl; activate one via `{…}`."
- **Unavailable**: a trait method is called but no impl for that
  (Trait, Target) is visible in scope → "no impl; import or link
  one."
- **Conflicting**: same activation declared twice in nested scopes
  with different impls → resolved by lexical precedence (inner wins).

---

# Anatomy of an impl item

Inside the impl body, three kinds of items:

## Method implementation

```aski
(describe &self Quality (|
  ([Fire Air])    Active
  ([Earth Water]) Receptive
|))
```

`(methodName params returnType body)` — standard signature + body.

## Associated type binding

```aski
(Item Token)
```

`(AssocName Type)` — the Pascal-first signal routes to associated
type binding. Inside the impl, this binds the trait's associated
type to a concrete target type.

## Associated const binding

```aski
{| Capacity U32 256 |}
```

`{| @AssocName Type @Value |}` — binds the trait's associated const
to an explicit value in this impl. Pascal-first inside `{|…|}` at
impl-item position.

First-token decidable at impl-item dispatch:
- `{|` → associated const binding
- `(` first-inner-pascal → associated type binding
- `(` first-inner-camel → method implementation

---

# Full impl with all item kinds

```rust
impl Iterator for TokenReader {
    type Item = Token;
    const BATCH_SIZE: u32 = 256;
    
    fn next(&mut self) -> Option<Token> {
        if self.cursor >= self.buffer.len() { None }
        else {
            let token = self.buffer[self.cursor].clone();
            self.cursor += 1;
            Some(token)
        }
    }
}
```

```aski
@[Default Iterator TokenReader [
  (Item Token)
  {| BatchSize U32 256 |}
  (next ~&self {Option Token} [
    (| self.cursor.geq(self.buffer.len)
      ( True )  Option:None
      ( False ) [
        (token self.buffer.at(self.cursor).clone)
        ~self.cursor.addAssign(1)
        Option:Some(token)
      ]
    |)
  ])
]]
```

All three item kinds. All in `.impls`. No type decl, no trait decl.

---

# Generic impl

```rust
impl<T: Clone> Container<T> for RingBuffer<T> {
    fn push(&mut self, value: T) { … }
}
```

```aski
@[Default Container {$Value{Clone}} {RingBuffer $Value} [
  (push ~&self :value $Value [ ... ])
]]
```

Generic slot after the trait name, before the target. Consistent
with TraitDecl structure.

---

# Blanket impl

```rust
impl<T: Debug> Describe for T { … }
```

```aski
@[BlanketDebug Describe {$Any{Debug}} $Any [
  (describe &self Quality [ ... ])
]]
```

The impl target is a generic parameter, making this a blanket impl.
veric must ensure no conflict with other (Describe, Concrete) impls
— that's part of coherence.

---

# Orphan-rule dissolution

Rust forbids:
```rust
// ForeignTrait and ForeignType both owned elsewhere — rejected
impl ForeignTrait for ForeignType { … }
```

aski allows it:
```aski
@[MyExtension ForeignTrait ForeignType [
  (method &self Output [ ... ])
]]
```

The impl lives in YOUR `.impls` file. It's visible only where
imported. Activation is still required if multiple impls exist
(someone else's library might also impl ForeignTrait for
ForeignType — you'd activate which one).

**This is a major ergonomic win over Rust.** No newtype dance for
adding common behavior to external types.

---

# Impl dependency on other impls

An impl can reference other impls explicitly:

```aski
@[ChainedDebug Debug {$Value} [
  (debug &self String [
    {PrettyPrint}
    self.prettyPrint
  ])
]]
```

`{PrettyPrint}` inside a method body activates PrettyPrint's
methods on self. If PrettyPrint is a trait with an impl for `$Value`,
the chain works.

---

# Impl with associated-type binding cascading

```rust
impl Iterator for TokenReader {
    type Item = Token;
    ...
}

impl DoubleEndedIterator for TokenReader {
    // inherits Item = Token via super-trait
    fn next_back(&mut self) -> Option<Self::Item> { ... }
}
```

```aski
@[Default Iterator TokenReader [
  (Item Token)
  (next ~&self {Option Token} [ ... ])
]]

@[Default DoubleEndedIterator TokenReader [
  (nextBack ~&self {Option Token} [ ... ])
]]
```

The super-trait's `Item` binding flows via the DoubleEndedIterator
bound. veric verifies consistency (both impls on TokenReader must
use the same Token for Item).

---

# Coherence enforcement at the program level

For each (Trait, TargetType) pair that appears in the program:

1. **Global inventory**: veric collects every impl from every
   `.impls` file.
2. **Per-scope resolution**: at each call site, veric walks
   active `{…}` directives from innermost to outermost.
3. **Conflict check**: if a scope lacks explicit activation and
   multiple impls exist, veric errors.
4. **Coverage check**: if a trait method is called and no impl is
   active, veric errors.

Coherence is **scope-aware**, not global. Two different scopes can
use different impls without conflict.

---

# Blanket-impl coherence

Blanket impls interact with concrete impls via ordering:

```aski
@[BlanketDescribe Describe {$T{Debug}} $T [ ... ])

@[SpecificDescribe Describe Element [ ... ])
```

For `Element` (which has `Debug`), both match. Rule: **most specific
wins**. `SpecificDescribe` takes precedence over `BlanketDescribe`
without explicit activation.

For ambiguity (two equally-specific impls), explicit activation is
required.

---

# Impl versioning via named impls

```aski
;; iter-v1.impls
@[V1 Iterator TokenStream [ ... old semantics ... ]]

;; iter-v2.impls
@[V2 Iterator TokenStream [ ... new semantics ... ]]
```

During migration, old code keeps `{V1}` in its scopes. New code
uses `{V2}`. When ready to retire V1, remove the file and update
any remaining scopes. No flag days, no big-bang switches.

---

# Impl as first-class data

A consequence of named impls: an impl has an identity. An aski
program can reference it:

```aski
{| DefaultParserImpl {ImplHandle DefaultParser} |}
```

Stretch: an `ImplHandle` primitive that carries a reference to a
specific impl. Runtime dispatch could route through an
`ImplHandle`-typed value. This reaches toward first-class modules /
first-class impls, which is a frontier most languages can't touch.

(Not proposed for immediate landing. Noted as a possibility opened
by the named-impl architecture.)

---

# Test-impls as a special case

```aski
;; my.test-impls
@[Mock Storage Database [
  (read &self &key String {Option String} [Option:Some("mocked")])
  (write ~&self &key String &value String [Unit])
]]

;; my.exec (test build)
(Test
  [storage-lib Storage]        ;; import
  {Mock})                       ;; activate the mock impl for the whole test
```

Same mechanism. Different file extension signals "test-only."

---

# What `.impls` cannot contain

- Type declarations (`.types`)
- Trait declarations (`.traits`)
- RFI function declarations (`.rfi`)
- Direct effects — if a method body performs I/O (reads a file,
  opens a socket, prints to stdout), the impl lives in `.effects`.

The paradigm: `.impls` is **pure computation attached to types via
traits.** Effects are separate.

---

# The full impl grammar (sketch)

```synth
;; Impls root
#Module#(@ModuleName <Module>)
// *?_@_#NamedImpl#[ @ImplName :TraitName ?{ +<GenericParam> } <Type> [+<TraitImplItem>] ]

;; TraitImplItem (as currently)
// #AssociatedTypeImpl#( @AssociatedName <Type> )
// #AssociatedConstImpl#{| @AssociatedName <Type> <Expr> |}
// ( @methodName <Method> )

;; Activation directive (new, at statement position)
// #ImplActivate#{ :ImplName }
```

The `{ :ImplName }` form for activation uses `{…}` at statement
position — free today. Subject to bikeshed during grammar landing.

---

# What veric gets sharper

With `.impls` as a distinct surface, veric's impl-matching tier
becomes a separate phase with well-defined inputs:

- All `.types` rkyv (types)
- All `.traits` rkyv (trait decls)
- All `.impls` rkyv (impls)
- Module-header activations + scope-level `{…}` directives

Outputs:
- Impl graph (Trait × Target → Vec<NamedImpl>)
- Per-scope active-impl map (Scope → (Trait, Target) → NamedImpl)
- Conflict / missing / ambiguous diagnostics

This is clean. This is testable. This is the payoff.

---

# Next

The impure boundary: `.effects` and platform surfaces.
[05-effects-and-platforms →](05-effects-and-platforms.md)
