# 06 — Derivation and Test-Impl Surfaces

*First-class macros and test mocking as dedicated surfaces.*

[← 05-effects-and-platforms](05-effects-and-platforms.md) · [07-sema-specialization →](07-sema-specialization.md)

---

# Part A: The `.derivations` surface

## What it replaces

Rust's `#[derive(Clone, Debug, PartialEq, Hash, ...)]` — attribute
macros that synthesize trait impls from a type's shape. Useful but
opaque: the expansion is hidden, the rules are hardcoded in the
compiler (built-in derives) or in proc-macro crates (custom
derives), and you can't introspect or override them.

aski's replacement: **derivation rules as first-class aski source**,
in a `.derivations` surface.

---

## The shape

A derivation is a rule that says: "for every type matching this
pattern, synthesize this impl."

Grammar sketch:

```synth
;; derivations Root
#Module#(@ModuleName <Module>)
// *?_@_#Derivation#[| @DerivationName :TraitName <TypePattern> [+<TraitImplItem>] |]
```

Each `[|…|]` entry is one derivation rule, using the same delimiter
as TraitDecl — aesthetically fitting because a derivation declares
"how to make an impl."

---

## Example — deriving Debug for structs

```rust
#[derive(Debug)]
struct Point { horizontal: f64, vertical: f64 }
```

Rust generates something like:
```rust
impl Debug for Point {
    fn fmt(&self, f: &mut Formatter) -> fmt::Result {
        write!(f, "Point {{ horizontal: {:?}, vertical: {:?} }}",
               self.horizontal, self.vertical)
    }
}
```

In aski, the derivation lives as a rule:

```aski
;; derive-common.derivations
@[| DebugStruct Debug {StructOf {$Struct} {AllFields Debug}}
  (debug &self String [
    (out :StructName:asString)
    ~out.append(" { ")
    {| self.Struct.field
      ~out.append(field.name)
      ~out.append(": ")
      ~out.append(field.value.debug)
      ~out.append(" ")
    |}
    ~out.append("}")
    out
  ])
|]
```

Reads: "For any `Struct` whose fields all implement Debug, synthesize
a Debug impl with this body." `StructOf` and `AllFields` are
pattern-matchers on type shape.

veric applies the rule at link time. For every Struct in the program
matching the pattern, it emits a Debug impl equivalent to hand-writing
one. The impl lives in the impl graph alongside hand-written impls.

---

## Example — deriving Clone for enums

```rust
#[derive(Clone)]
enum Shape { Circle(f64), Rectangle { width: f64, height: f64 } }
```

```aski
@[| CloneEnum Clone {EnumOf {$Enum} {AllVariants Clone}}
  (clone &self Self [
    (| self
      {| :EnumType.variant
        ;; for each variant, clone each payload field
        ( :variant :fields )  :variant(:fields.map(field.clone))
      |}
    |)
  ])
|]
```

More complex pattern-match on variant shape. Generates code that
reconstructs the enum by cloning each variant's payload.

---

## Derivation application — declarative at use site

A `.types` file opts into a derivation by marking the type:

```aski
;; shapes.types
{deriving [Debug Clone Eq Hash]}           ;; module-level default for this file
@{Point (@Horizontal F64) (@Vertical F64)}
```

Or per-type:

```aski
@{Point {deriving [Debug Clone]}
  (@Horizontal F64) (@Vertical F64)}
```

`{deriving […]}` is a directive inside the type's declaration. The
build system matches listed traits against available derivations and
synthesizes impls.

---

## Why this is better than Rust's `#[derive]`

### Derivations are first-class aski code

You can read them. You can edit them. You can override them. They
live in `.derivations` files just like your types live in `.types`.

### Derivations are inspectable

```
> aski-explain derive Debug Point
Derivation "DebugStruct" from derive-common.derivations applies:
  struct Point { horizontal: F64, vertical: F64 }
  all fields (F64) impl Debug
  
Generated impl:
  [@DerivedDebug Debug Point [
    (debug &self String [ ... expanded body ... ])
  ]]
```

Compare to Rust where proc-macro output is invisible without
`cargo-expand`.

### Derivations compose

A complex derivation can reference simpler ones:

```aski
@[| EqDerived Eq {StructOf {$Struct} {AllFields Eq}}
  (eq &self &other Self Bool [
    (| self.StructType == other.StructType
      ( False ) False
      ( True ) [
        {| self.Struct.field
          (otherField other.fieldByName(field.name))
          (| field.value == otherField
            ( False ) ^False
            ( True )  Unit
          |)
        |}
        True
      ]
    |)
  ])
|]
```

### Derivations can be opted out

```aski
@{Point {deriving [Debug Clone] {skipDeriving [Hash]}}
  (@Horizontal F64) (@Vertical F64)}
```

"Derive Debug and Clone, but don't derive Hash even if a derivation
exists." Explicit overrides.

### Derivations can be project-specific

Each project can ship its own `.derivations` files. Application-specific
derivations (JSON serialization, schema generation, ORM mapping)
become structured rules, not hand-rolled proc-macros.

### Derivations don't run compiler code

Rust's proc macros are arbitrary code executed by the compiler — a
dependency supply-chain concern. aski's derivations are structured
data (type pattern + trait + impl template) interpreted by veric.
No code execution, no supply-chain risk.

---

## Example — custom derivation for JSON

```aski
;; json.derivations
@[| JsonSerializeStruct JsonSerialize {StructOf {$Struct} {AllFields JsonSerialize}}
  (toJson &self Json [
    (obj Json:Object:empty)
    {| self.Struct.field
      ~obj.insert(field.name field.value.toJson)
    |}
    Json:Object(obj)
  ])
|]

@[| JsonSerializeEnum JsonSerialize {EnumOf {$Enum} {AllVariants JsonSerialize}}
  (toJson &self Json [
    ;; tag + payload
    (| self
      ( :variant ) Json:Object({"tag" Json:String(variant.name) "payload" Json:Null})
      ( :variant :payload ) Json:Object({"tag" Json:String(variant.name) "payload" payload.toJson})
    |)
  ])
|]
```

Serialize a whole domain to JSON by adding `{deriving [JsonSerialize]}`
to types. No `#[derive(Serialize)]`. No proc-macro compile time.
Just rules.

---

## Derivation priority

When multiple derivations could apply to a type, most-specific wins.
Rules can declare specificity:

```aski
@[| ClonePrimitive Clone {Primitive Bool} {priority 10}
  (clone &self Bool [*self])
|]

@[| CloneStruct Clone {StructOf {$Struct} {AllFields Clone}} {priority 5}
  ;; generic struct clone
]]
```

Bool gets the more specific impl. Custom priority per derivation.

---

## Derivation meta-traits

A derivation can require that the type-pattern satisfies other
traits:

```aski
@[| OrdLexicographic Ord {StructOf {$Struct} {FieldsInOrder Ord}}
  ;; lexicographic compare: first field, then second, ...
  (compare &self &other Self Ordering [
    ...
  ])
|]
```

---

## What cannot be derived

Derivation works on type **shape**. If a trait has behavior that
depends on data not visible in the type shape (e.g., "this trait
requires a hash salt injected at runtime"), you can't derive it.
Write an explicit impl instead.

---

## The composability win

With types in `.types`, traits in `.traits`, derivations in
`.derivations`, and impls in `.impls`:

- Types contribute shape.
- Traits contribute interfaces.
- Derivations contribute rule-based implementations.
- Impls contribute hand-written implementations.

At link time, veric unites all four. For each (Trait, Type) pair,
either a hand-written impl exists OR a derivation synthesizes one OR
neither (and the program uses the trait against the type → veric
error).

**Four surfaces, one coherent impl graph.**

---

# Part B: The `.test-impls` surface

## What it replaces

Rust's `#[cfg(test)]` and mocking crates (mockall, mockito, …).
Test-only code sprinkled through source with conditional compilation.
Mocks defined via proc-macros and imported via feature flags.

aski's replacement: **test-impl surfaces** that replace real impls at
test-build time.

---

## The shape

Same as `.impls`. Same grammar. The extension `.test-impls` signals:
"this file's impls only link in test builds."

```aski
;; app-test.test-impls
@[@Default Storage Db [
  (read &self &key String {Option String} [Option:Some("mocked-value")])
  (write ~&self &key String &value String [Unit])
]]

@[@Default Clock System [
  (now &self Time [Time:epoch])
]]
```

---

## Test build wiring

```
production build:   storage.effects + real-clock.effects + app.impls + app.exec
test build:         app-test.test-impls + app.impls + app.exec
```

The test build replaces the real `.effects` with `.test-impls`.
All impl references automatically route to the mocks.

No `#[cfg(test)]` in source. No conditional-compilation branches.
Just different link graphs.

---

## Example — testing a pure pipeline with mocked storage

Production:
```aski
;; app.exec
(App [storage LocalFs])                 ;; module header pins real impl

(App self [
  (users self.loadUsers)
  (filtered users.filter(self.active))
  filtered
])
```

```aski
;; app.impls
@[@Default UserLoader App [
  (loadUsers &self {Vec User} [
    (data Storage:read("users.json"))     ;; dispatches via LocalFs (real)
    User:parseAll(data)
  ])
]]
```

Test:
```aski
;; app-test.test-impls
@[@Default Storage Mock [
  (read &self &key String {Option String} [
    Option:Some(Fixture:usersJson)        ;; fixed fixture
  ])
]]

;; app-test.exec
(AppTest [storage Mock])                ;; test build pins Mock

(AppTest self [
  ;; same test as production, dispatches Storage:read to Mock
  (users self.loadUsers)
  ...
])
```

The test exercise runs production code against mocked impls. **No
test-specific production code.** The production `.impls` is unchanged.

---

## Test-impls can coexist with regular impls

Multiple test-impl surfaces for different test scenarios:

```
happy-path.test-impls    — all deps succeed
error-cases.test-impls   — deps return errors
slow-network.test-impls  — deps add latency
```

Each test build links a different `.test-impls` file. Same production
source. Different scenarios.

---

## Test-impls for traits without real impls yet

During TDD, you can declare a trait, write a test-impl, write the
test, then defer the real impl:

```
flow:
  1. traits/payment.traits  — declare Payment trait
  2. tests/payment.test-impls — stub the Payment impl
  3. tests/payment-test.exec  — write the test
  4. deferred: payment.impls  — real impl later
```

The test runs green without the real impl existing. When the real
impl lands, tests still run (against either impl depending on build).

---

## Test-impls + derivations

Derivations can apply in test builds too. If a derivation synthesizes
a `TestFixture` impl for any type tagged `#[deriving TestFixture]`,
test code gets auto-generated fixtures.

```aski
;; fixtures.derivations  (test-mode only)
@[| FixtureStruct TestFixture {StructOf {$Struct} {AllFields TestFixture}}
  (fixture Self [
    ;; auto-generate a fixture by sampling each field's fixture
    ...
  ])
|]
```

Structural fixture generation via rules — no quickcheck crate, no
proptest macros. Derivations do it.

---

## Bench-impls — the sibling surface

`.bench-impls` mirrors `.test-impls` but for benchmarks. Used to:

- Instrument methods (count calls, measure timing).
- Pre-populate caches for fair comparisons.
- Disable logging that would skew results.

Same swap mechanism, different extension, different build target.

---

# Why these two surfaces matter together

- **Derivations** turn the "rules about types" into first-class
  source.
- **Test-impls** turn "test-only behavior" into a link-graph concern
  instead of a source-conditional concern.

Both are examples of the multi-surface payoff: a concept that Rust
handles via ad-hoc mechanisms (attribute macros, `cfg(test)`) gets
its own dedicated home in aski, with cleaner semantics and richer
capabilities.

---

# The surface-count objection, revisited

Twelve surfaces sounds like a lot. But look at what each does:

| Surface | Concern |
|---------|---------|
| `.core` | Bootstrap contract types |
| `.synth` | Grammar itself |
| `.types` | User-facing type definitions |
| `.traits` | Interface declarations |
| `.impls` | Pure behavior attachments |
| `.effects` | Impure behavior attachments |
| `.derivations` | Rule-based behavior synthesis |
| `.test-impls` | Test-mode behavior swaps |
| `.bench-impls` | Bench-mode behavior swaps |
| `<platform>.impls` | Per-platform pure behavior |
| `<platform>.effects` | Per-platform impure behavior |
| `.exec` | Program entry points |
| `.rfi` | Foreign interface declarations |

Each one is a distinct concern. Each one has a distinct consumer or
constraint. None of them would be smaller or simpler if they were
merged with another.

**Twelve surfaces is the bill for architectural honesty.** The
alternative is twelve concerns tangled in one file.

---

# Next

Same source → different sema binaries: the specialization story.
[07-sema-specialization →](07-sema-specialization.md)
