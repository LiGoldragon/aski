# 03 — The `.traits` Surface

*Every Rust trait feature, as a declaration with no implementation.*

[← 02-types](02-types.md) · [04-impls →](04-impls.md)

---

# What `.traits` contains

Trait declarations only. Every trait gets a name, an optional
generics slot, optional super-trait constraints, optional associated
types and consts, and a list of method signatures (with optional
default bodies).

No implementations. No instantiation logic. No bodies that touch a
specific concrete type.

---

# Module header

```aski
(TraitsModule [shapes Shape Quality] [iteration Iterator])
```

Imports from `.types` files provide the types that appear in method
signatures.

---

# The atomic trait shape

```rust
trait Describe {
    fn describe(&self) -> Quality;
}
```

```aski
@[| Describe
  (describe &self Quality)
|]
```

`[|…|]` is the trait declaration delimiter. Inside: trait name, then
items. Items are associated types (bare Pascal), method signatures
(`(camelName …)`), or associated consts (`{| @Name Type ?Default |}`).

---

# Trait with default method

```rust
trait Greet {
    fn name(&self) -> String;
    fn greet(&self) -> String {
        format!("Hello, {}!", self.name())
    }
}
```

```aski
@[| Greet
  (name &self String)
  (greet &self String [
    StringFormat:concat("Hello, " self.name "!")
  ])
|]
```

The method body inside the signature = default implementation.
Missing body = required method that impls must provide.

---

# Trait with associated type

```rust
trait Iterator {
    type Item;
    fn next(&mut self) -> Option<Self::Item>;
}
```

```aski
@[| Iterator
  Item
  (next ~&self {Option self:Item})
|]
```

Bare Pascal `Item` inside trait body = associated type declaration.
`self:Item` in a method signature = "the Item associated with the
Self impl" — the `Type::SelfAssoc` variant.

---

# Trait with multiple associated types

```rust
trait Graph {
    type Node;
    type Edge;
    fn nodes(&self) -> Vec<Self::Node>;
    fn edges(&self, from: &Self::Node) -> Vec<Self::Edge>;
}
```

```aski
@[| Graph
  Node
  Edge
  (nodes &self {Vec self:Node})
  (edges &self &from self:Node {Vec self:Edge})
|]
```

---

# Trait with associated const (pending S9)

```rust
trait BoundedQueue {
    type Item;
    const CAPACITY: u32;
    const DEFAULT_TIMEOUT_MS: u64 = 30_000;
    fn push(&mut self, value: Self::Item);
}
```

```aski
@[| BoundedQueue
  Item
  {| Capacity         U32 |}
  {| DefaultTimeoutMs U64 30000 |}
  (push ~&self :value self:Item)
|]
```

`{| @Name Type |}` = associated const without default.
`{| @Name Type @Default |}` = associated const with default.

First-token dispatch at trait item position:
- `{|` → associated const
- `(` → method signature
- Pascal bare → associated type

Decidable at one token.

---

# Super-traits

```rust
trait Ord: PartialOrd + Eq {
    fn compare(&self, other: &Self) -> Ordering;
}
```

```aski
@[| Ord {PartialOrd Eq}
  (compare &self &other Self Ordering)
|]
```

The `{}` slot after the trait name carries both super-trait
references and generic parameters. Bare Pascal names inside = super
traits. Items prefixed with `$` = generic params.

---

# Generic trait

```rust
trait From<From> {
    fn from(value: From) -> Self;
}
```

```aski
@[| From {$Source}
  (from :value $Source Self)
|]
```

---

# Generic trait with bound on generic AND super-trait

```rust
trait OrderedContainer<T: Clone>: IntoIterator {
    fn sort(&mut self);
    fn dedup(&mut self);
}
```

```aski
@[| OrderedContainer {$Value{Clone} IntoIterator}
  (sort  ~&self)
  (dedup ~&self)
|]
```

---

# Trait with method-level generics

```rust
trait Apply {
    fn apply<U>(&self, f: impl Fn(Self::Item) -> U) -> U;
}
```

Assuming the Callable trait (S4 Position A — named-type path):

```aski
@[| Apply
  Item
  (apply ?{$Output} &self &transform {Callable self:Item $Output} $Output)
|]
```

Method-level generics in `?{…}` slot after method name.

---

# Trait with `Self` as associated bound

```rust
trait Clone {
    fn clone(&self) -> Self;
}
```

```aski
@[| Clone
  (clone &self Self)
|]
```

---

# Trait hierarchy with associated types flowing

```rust
trait Iterator {
    type Item;
    fn next(&mut self) -> Option<Self::Item>;
}

trait DoubleEndedIterator: Iterator {
    fn next_back(&mut self) -> Option<Self::Item>;
}
```

```aski
@[| Iterator
  Item
  (next ~&self {Option self:Item})
|]

@[| DoubleEndedIterator {Iterator}
  (nextBack ~&self {Option self:Item})
|]
```

The super-trait `Iterator` imports `Item` into scope; DoubleEndedIterator
refers to it via `self:Item` same way.

---

# Error trait with cause chain

```rust
trait Error: Display + Debug {
    fn source(&self) -> Option<&(dyn Error + 'static)>;
    fn description(&self) -> &str { "" }
}
```

```aski
@[| Error {Display Debug}
  (source &self {Option &'Static {?Error}})
  (description &self String [""])
|]
```

Default impl on `description` returns empty string. `{?Error}`
denotes dyn-Trait at type position (pending S6 sigil).

---

# Trait with deprecation marker (proposed)

```rust
#[deprecated(since = "0.5", note = "use IteratorV2")]
trait IteratorV1 { … }
```

```aski
@[| IteratorV1 {Superseded:By(IteratorV2)}
  (next ~&self {Option self:Item})
|]
```

A proposed metadata item in the super-trait bracket: `Superseded:By(…)`
is a first-class lifecycle attribute. veric emits warnings for impls
of superseded traits.

(This is sketch-level. Formal form pending.)

---

# Trait with associated lifetime constraints

```rust
trait Borrow<Borrowed: ?Sized> {
    fn borrow(&self) -> &Borrowed;
}
```

aski uses origins instead of lifetime generics:

```aski
@[| Borrow {$Borrowed}
  (borrow &self &'Self $Borrowed)
|]
```

`&'Self` borrows from the Self place. The origin carries forward
to callers.

---

# Trait that expresses an effect requirement

```rust
trait Stream {
    fn read(&mut self, buf: &mut [u8]) -> Result<usize, Error>;
}
```

In the `.traits` surface, this is a pure interface declaration:

```aski
@[| Stream
  (read ~&self ~&buffer {Slice U8} {Result U32 Error})
|]
```

The trait itself doesn't declare effects. Effect classification
happens at the `.impls` level — if an impl of Stream performs I/O,
that impl lives in `.effects`, not `.impls`.

---

# Trait families for overloading-via-dispatch

Rust's `Add` / `Sub` / `Mul` / `Div` operator traits:

```rust
trait Add<Rhs = Self> {
    type Output;
    fn add(self, rhs: Rhs) -> Self::Output;
}
```

```aski
@[| Add {$Right}
  Output
  (add self :right $Right self:Output)
|]
```

Note: aski doesn't overload `+` directly on types. Operator traits
land in `.traits` but bear-method-call style (`a.add(b)`) is what
the source uses, matching the methods-over-operators direction
(pending U17).

---

# Trait with zero-size marker

```rust
trait Send {}
trait Sync {}
```

```aski
@[| Send |]
@[| Sync |]
```

Empty body = marker trait. Impls have no methods to provide.

---

# Associated type bounds (existential)

```rust
trait IntoIterator {
    type Item;
    type IntoIter: Iterator<Item = Self::Item>;
    fn into_iter(self) -> Self::IntoIter;
}
```

```aski
@[| IntoIterator
  Item
  IntoIter {Iterator (Item self:Item)}
  (intoIter self self:IntoIter)
|]
```

Associated-type-with-bound uses `{TraitName (AssocName BoundType)}`
— trait bound with explicit associated-type projection.

---

# A full-featured trait

```rust
pub trait Service<'input, Request: Clone>
    where Self: Sync + Clone,
{
    type Response;
    type Error: Display + Debug;
    const DEFAULT_TIMEOUT: Duration = Duration::from_millis(30_000);
    
    fn call(&self, request: Request) -> Result<Self::Response, Self::Error>;
    fn timeout(&self) -> Duration { Self::DEFAULT_TIMEOUT }
}
```

```aski
@[| Service {$Request{Clone} Sync Clone}
  Response
  Error {Display Debug}
  {| DefaultTimeout Duration Duration:fromMillis(30000) |}
  (call    &self :request $Request {Result self:Response self:Error})
  (timeout &self Duration [Self:DefaultTimeout])
|]
```

Generic + bounds + super-traits, two associated types (one with
bound), associated const with default expression, method decl,
method with default body. All declarative. No implementation.

---

# What cannot appear in `.traits`

- Type declarations (those live in `.types`)
- Trait implementations (those live in `.impls`)
- Local declarations in method default bodies that reference impls
  (only self-referential or trait-accessible calls are legal)
- Effects in default bodies (if a default body would perform I/O, it
  has to live in an `.effects` file — but then the default is an
  effectful default, which is a discussion for 05-effects)

---

# Why `.traits` as its own surface

- Narrow grammar. 2-alternative root (Module, TraitDecl). Delimiter
  budget wide open for future trait features.
- Trait libraries can ship without impls — the stdlib trait-only
  part is a types+traits download. Impls are per-consumer.
- Protocol-first development: design the trait, circulate for review,
  then write impls. Each phase has a matching surface.
- Documentation of interfaces happens on traits alone.
- veric's job on `.traits` is clean: verify names resolve, assoc type
  bounds are satisfiable, super-traits form a DAG, method signatures
  type-check against imported `.types`. No impl-matching required.

---

# Trait compile output

A `.traits` file compiles to rkyv conforming to aski-core's
`TraitDecl` type. A `.traits`-only compile produces a trait library
rkyv consumable by:
- IDE tooling
- Documentation generators
- Protocol validators
- Downstream `.impls` files that target the traits

The output is tiny and cacheable.

---

# Next

Where the magic happens: `.impls` with named impls and global
coherence. [04-impls →](04-impls.md)
