# Traits

Trait declarations live in `[_]Name.trait` files.

**Content grammar:** `?<GenericsAndSuperBounds> *<TraitItem>`.

The first token is `{` if the trait has a generic slot and/or super-trait bounds; otherwise the first token is a trait item. First-token decidable.

**TraitItem forms:**

| Form | Meaning |
|---|---|
| `Pascal` (bare name) | associated type declaration |
| `(camelName ...)` | method signature (with optional default body) |
| `{\| @Name Type ?Default \|}` | associated const declaration |

## Minimal trait

```
Describe.trait
```

```aski
(describe &self Quality)
```

```rust
pub trait Describe { fn describe(&self) -> Quality; }
```

## Trait with a default method body

```
Greeter.trait
```

```aski
(name &self String)
(greet &self String [
  StringFormat:combine("Hello, " self.name "!")
])
```

```rust
pub trait Greeter {
    fn name(&self) -> String;
    fn greet(&self) -> String {
        format!("Hello, {}!", self.name())
    }
}
```

## Associated types

```
Iterator.trait
```

```aski
Item
(next ~&self {Option self:Item})
```

```rust
pub trait Iterator {
    type Item;
    fn next(&mut self) -> Option<Self::Item>;
}
```

Associated types are declared by bare Pascal. Inside method signatures, reference them via `self:AssocName`.

## Multiple associated types with method-level generics

```
Graph.trait
```

```aski
Node
Edge
(nodes &self {Vec self:Node})
(edges &self &from self:Node {Vec self:Edge})
(apply ?{$Output} &self &transform {Callable self:Node $Output} {Vec $Output})
```

```rust
pub trait Graph {
    type Node;
    type Edge;
    fn nodes(&self) -> Vec<Self::Node>;
    fn edges(&self, from: &Self::Node) -> Vec<Self::Edge>;
    fn apply<U>(&self, transform: &dyn Fn(&Self::Node) -> U) -> Vec<U>;
}
```

Method-level generic slot `?{$Output}` comes after the method name, before its parameters.

## Associated constants

```
BoundedQueue.trait
```

```aski
Item
{| Capacity         U32 |}
{| DefaultTimeoutMs U64 30000 |}
(push ~&self :value self:Item)
```

```rust
pub trait BoundedQueue {
    type Item;
    const CAPACITY: u32;
    const DEFAULT_TIMEOUT_MS: u64 = 30_000;
    fn push(&mut self, value: Self::Item);
}
```

Assoc const forms:

- `{| @Name Type |}` — required, no default
- `{| @Name Type Default |}` — with default expression

First-token decidable at TraitItem position: `{|` = AssocConst, `(` = method, bare Pascal = AssocType.

## Super-traits

```
Ord.trait
```

```aski
{PartialOrd Eq}
(compare &self &other Self Ordering)
```

```rust
pub trait Ord: PartialOrd + Eq {
    fn compare(&self, other: &Self) -> Ordering;
}
```

First token is `{` — the super-trait/generic slot. Bare Pascal names inside are super-traits; `$`-prefixed names are generic parameters.

## Generics plus super-traits plus associated types

```
TotalOrd.trait
```

```aski
{$Value{PartialOrd Eq}}
Output
(cmp &self &other self:Output)
```

```rust
pub trait TotalOrd<T: PartialOrd + Eq> {
    type Output;
    fn cmp(&self, other: &Self) -> Self::Output;
}
```

## Generic trait (From)

```
From.trait
```

```aski
{$Source}
(from :value $Source Self)
```

```rust
pub trait From<Source> { fn from(value: Source) -> Self; }
```

## Method-level generic with bound

```
Serialize.trait
```

```aski
(toBytes &self &data $Value{Clone Debug} {Vec U8})
```

```rust
pub trait Serialize {
    fn to_bytes<T: Clone + Debug>(&self, data: &T) -> Vec<u8>;
}
```

## Marker trait (empty body)

```
Send.trait
```

(no tokens in body)

```rust
pub trait Send {}
```

## Trait with origin in signature

```
Borrow.trait
```

```aski
{$Borrowed}
(borrow &self &'self $Borrowed)
```

```rust
pub trait Borrow<Borrowed> {
    fn borrow<'a>(&'a self) -> &'a Borrowed;
}
```

## Associated-type projection

```
IntoIterator.trait
```

```aski
Item
IntoIter {Iterator (Item self:Item)}
(intoIter self self:IntoIter)
```

```rust
pub trait IntoIterator {
    type Item;
    type IntoIter: Iterator<Item = Self::Item>;
    fn into_iter(self) -> Self::IntoIter;
}
```

## Full-featured trait

```
Service.trait
```

```aski
{$Request{Clone} Sync Clone}
Response
Error {Display Debug}
{| DefaultTimeoutMs U64 30000 |}
(call    &self :request $Request {Result self:Response self:Error})
(timeout &self U64 [Self:DefaultTimeoutMs])
```

```rust
pub trait Service<Request: Clone>: Sync + Clone {
    type Response;
    type Error: Display + Debug;
    const DEFAULT_TIMEOUT_MS: u64 = 30_000;
    fn call(&self, request: Request) -> Result<Self::Response, Self::Error>;
    fn timeout(&self) -> u64 { Self::DEFAULT_TIMEOUT_MS }
}
```
