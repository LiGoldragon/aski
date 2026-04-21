# 09 — Every Rust Feature in Aski

*Proof by enumeration. Aski (minus the deliberate OUTs) covers all
of Rust through the multi-surface architecture.*

[← 08-bootstrap](08-bootstrap.md) · [10-transition →](10-transition.md)

---

# How this doc is organized

For each Rust feature category, we show:
1. Rust source
2. aski source, with the surface it lives in noted
3. Notes on what aski adds or subtracts

Anything marked **OUT** is deliberately excluded per paradigm.
Anything marked **via** uses a specific aski mechanism.

---

# 1. Primitives

## Integer / float / bool

```rust
let a: u32 = 100;
let b: i64 = -50;
let c: f64 = 3.14;
let d: bool = true;
```

```aski
;; in a method body in .impls
(a U32:new(100))
(b I64:new(-50))
(c F64:new(3.14))
(d True)           ;; True and False are variants of a Bool enum (C3/C4 open)
```

## Char

```rust
let ch: char = 'A';
let lf: char = '\n';
```

```aski
;; no char literal syntax — Char is a library of types (U16 direction)
(ch Char:Upper:A)
(lf Char:Whitespace:Newline)
```

## String / str

```rust
let s: String = String::from("hello");
let slice: &str = &s;
```

```aski
(s String:from("hello"))
(slice &s String)            ;; String type; borrow semantics via &
```

Note: aski's String is the primitive; `&str` distinction folds into
`&String` borrows. Per paradigm.md, the `str` slice type is
Unspec'd.

---

# 2. Compound types

## Struct — named fields

```rust
pub struct Point { pub horizontal: f64, pub vertical: f64 }
```

```aski
;; .types
@{Point (@Horizontal F64) (@Vertical F64)}
```

## Struct — private fields

```rust
pub struct Secret { key: String, nonce: u64 }
```

```aski
;; .types
@{Secret (key String) (nonce U64)}
```

## Tuple struct — OUT (except newtype)

```rust
pub struct Pair(f64, f64);    // OUT — use a named struct
pub struct UserId(u64);        // allowed — this is a newtype
```

```aski
;; .types — multi-field tuple rejected
@{Pair (@Left F64) (@Right F64)}

;; .types — single-field tuple → newtype
@(| UserId @U64 |)
```

## Unit struct

```rust
pub struct Marker;
```

```aski
;; .types
@{Marker}
```

## Enum — bare

```rust
pub enum Element { Fire, Earth, Air, Water }
```

```aski
;; .types
@(Element Fire Earth Air Water)
```

## Enum — data variants

```rust
pub enum Shape {
    Circle(f64),
    Rectangle { width: f64, height: f64 },
}
```

```aski
;; .types
@(Shape
  (Circle F64)
  {Rectangle (@Width F64) (@Height F64)})
```

## Enum — discriminants (U15 proposed)

```rust
#[repr(u16)]
pub enum HttpStatus { Ok = 200, NotFound = 404 }
```

```aski
;; .types
@(HttpStatus
  [Ok 200]
  [NotFound 404])
```

## Nested types

```rust
pub enum Event {
    Tick,
    Network(NetworkEvent),
}
pub enum NetworkEvent { Connected, Disconnected }
```

```aski
;; .types — nested enum inside enum
@(Event
  Tick
  (| Network Connected Disconnected |))
```

---

# 3. References and lifetimes

## Shared and mutable borrows

```rust
fn read(v: &Vec<u32>) -> u32 { … }
fn write(v: &mut Vec<u32>) { … }
```

```aski
;; .traits
@[| VectorOps
  (read  &target {Vec U32} U32)
  (write ~&target {Vec U32})
|]

;; or method style on the Vec:
;; .impls
@[Default VectorOps {Vec U32} [
  (read  &self U32 [ ... ])
  (write ~&self [ ... ])
]]
```

## Lifetimes → place-based origins

```rust
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str { … }
```

```aski
;; .impls
@[Longest Longest StringOps [
  (longest &'(left right) left String
           &'(left right) right String
           &'(left right) String
    [ ... ])
]]
```

`'(left right)` is the place-union origin — "the result borrows from
whichever of left or right lives longer."

## `'static`

```rust
fn find(id: u32) -> &'static str { … }
```

```aski
;; .impls
@[Find Finder Table [
  (find &self :id U32 &'Static String [ ... ])
]]
```

## Raw pointers — U (Unspec'd)

```rust
let p: *const u32 = &x;
```

Not currently in aski. Raw pointers are Unspec'd per paradigm.md.
If added, they'd live in `.unsafe-impls` (a future surface).

## View types

```rust
// Rust view-types RFC (hypothetical today)
fn tick(counter: &mut Counter { count }) { counter.count += 1; }
```

```aski
;; .impls
@[Tick Tick Counter [
  (tick ~&self {| Count |} [
    ~self.Count.addAssign(1)
  ])
]]
```

---

# 4. Generics

## Generic struct

```rust
pub struct Pair<L, R> { pub left: L, pub right: R }
```

```aski
;; .types
@{Pair {$Left $Right} (@Left $Left) (@Right $Right)}
```

## Bounded generics

```rust
pub struct Container<T: Clone + Debug> { items: Vec<T> }
```

```aski
;; .types
@{Container {$Value{Clone Debug}} (@Items {Vec $Value})}
```

## Multiple generic params

```rust
pub struct Graph<N, E> { nodes: Vec<N>, edges: Vec<E> }
```

```aski
;; .types
@{Graph {$Node $Edge}
  (@Nodes {Vec $Node})
  (@Edges {Vec $Edge})}
```

## Where clauses — U (Unspec'd)

```rust
fn process<T>(x: T) where T: Clone + Debug + Send { … }
```

```aski
;; inline bounds on the method-level generic
;; .impls
@[Process Processor Self [
  (process ?{$Value{Clone Debug Send}} :x $Value [ ... ])
]]
```

Where-clauses as a separate slot are Unspec'd; inline bounds cover
most cases.

## Lifetime generics → origins

```rust
fn first<'a, T>(xs: &'a [T]) -> Option<&'a T> { … }
```

```aski
;; .impls
@[First Extractor Self [
  (first ?{$Value} &'source xs {Slice $Value} {Option &'source $Value} [ ... ])
]]
```

Origins replace Rust's lifetime generics.

## HRTB — U (Unspec'd)

`for<'a>` bounds. Not in aski grammar today. Could be handled via
origin-quantification in a future extension.

## Const generics — U (Unspec'd)

Rust's `[T; N]` where `N: usize` is a const generic. aski's `{Array
T N}` with N as a const expression is the S11-proposed shape.

---

# 5. Traits

## Trait declaration

```rust
pub trait Describe {
    fn describe(&self) -> String;
}
```

```aski
;; .traits
@[| Describe
  (describe &self String)
|]
```

## Default method

```rust
pub trait Greet {
    fn name(&self) -> String;
    fn greet(&self) -> String {
        format!("Hello, {}!", self.name())
    }
}
```

```aski
;; .traits
@[| Greet
  (name &self String)
  (greet &self String [
    StringFormat:concat("Hello, " self.name "!")
  ])
|]
```

## Associated type

```rust
pub trait Iterator {
    type Item;
    fn next(&mut self) -> Option<Self::Item>;
}
```

```aski
;; .traits
@[| Iterator
  Item
  (next ~&self {Option self:Item})
|]
```

## Associated const (S9 proposed)

```rust
pub trait BoundedQueue {
    const CAPACITY: u32;
    const DEFAULT_TIMEOUT: u64 = 30_000;
}
```

```aski
;; .traits
@[| BoundedQueue
  {| Capacity        U32 |}
  {| DefaultTimeout  U64 30000 |}
|]
```

## Super-trait

```rust
pub trait Ord: PartialOrd + Eq { ... }
```

```aski
;; .traits
@[| Ord {PartialOrd Eq}
  (compare &self &other Self Ordering)
|]
```

## Trait impl

```rust
impl Describe for Element { … }
```

```aski
;; .impls
@[Default Describe Element [ ... ]]
```

## Generic impl

```rust
impl<T: Clone> Container<T> for RingBuffer<T> { … }
```

```aski
;; .impls
@[Default Container {$Value{Clone}} {RingBuffer $Value} [ ... ]]
```

## Blanket impl

```rust
impl<T: Debug> MyTrait for T { … }
```

```aski
;; .impls
@[Blanket MyTrait {$Value{Debug}} $Value [ ... ]]
```

## Inherent impl — OUT per paradigm

```rust
impl Counter { fn tick(&mut self) { … } }   // OUT
```

Replace with a single-method trait:

```aski
;; .traits
@[| Tick
  (tick ~&self)
|]

;; .impls
@[Default Tick Counter [
  (tick ~&self [ ... ])
]]
```

---

# 6. Trait objects (dyn Trait)

## dyn Trait (S6 proposed syntax)

```rust
fn emit(writer: &mut dyn Writer, msg: &str) { writer.write(msg); }
```

```aski
;; .traits (Writer)
@[| Writer (write ~&self :msg String) |]

;; .impls — takes a dyn Writer
@[Emit Emitter Log [
  (emit ~&writer {?Writer} :msg String [
    ~writer.write(msg)
  ])
]]
```

`{?Writer}` is the proposed dyn sigil. Semantic of dyn dispatch
open (see bridge/big-decisions §S6).

## impl Trait (existential) — U

```rust
fn make_iter() -> impl Iterator<Item = u32> { … }
```

Not yet spec'd. Could be expressed as "this returns a type that
satisfies Iterator, concrete type existentially quantified." Would
need a surface/semantic design.

---

# 7. Closures (S4 open)

## Named-type closure (Position A)

```rust
let items: Vec<u32> = nums.iter().map(|x| x + 1).collect();
```

```aski
;; .types
@{Increment (@Amount U32)}

;; .impls
@[Default Callable {U32} U32 Increment [
  (call &self &input U32 U32 [input + self.Amount])
]]

;; usage in another .impls method body:
(items self.nums.map(&Increment {Amount 1}))
```

## Inline closure sugar (Position B, speculative)

If aski eventually adopts inline-closure sugar, it'd be a grammar
addition. Named-type path (Position A) is the default; other
positions require design work (see bridge/big-decisions §S4).

---

# 8. Control flow

## if / else (C4 via match)

```rust
if condition { a } else { b }
```

```aski
;; in a method body
(| condition
  ( True )   a
  ( False )  b
|)
```

## match

```rust
match value {
    Foo => a,
    Bar(x) => f(x),
    _ => default,
}
```

```aski
(| value
  ( Foo )        a
  ( Bar x )      [self.f(x)]
  ( _ )          default
|)
```

## while

```rust
while condition { body; }
```

```aski
[| condition
  body
|]
```

## for / iteration

```rust
for item in collection { body(item); }
```

```aski
{| collection.item
  [self.body(item)]
|}
```

## loop (infinite)

```rust
loop { body; }
```

```aski
[| true
  body
|]
```

## break / continue / labels (U13 proposed, sigil family TBD)

```rust
'outer: loop {
    for x in items {
        if done { break 'outer; }
        if skip { continue; }
    }
}
```

Under one candidate sigil family (`^^` / `^~` / `^'Label`):

```aski
[| 'outerLoop true
  {| items.x
    (| done ( True ) ^^'outerLoop Unit ( False ) Unit |)
    (| skip ( True ) ^~            ( False ) Unit |)
  |}
|]
```

## return / ?

```rust
if !valid { return Err(Error::Invalid); }
let x = may_fail()?;
```

```aski
(| valid ( False ) ^Result:Err(Error:Invalid) ( True ) Unit |)
(x self.mayFail?)
```

---

# 9. Operators

## Arithmetic

```rust
a + b, a - b, a * b, a / b, a % b
```

```aski
a + b, a - b, a * b, a / b, a % b      ;; C5 accepted
```

## Unary (C6 accepted)

```rust
-x, !y
```

```aski
-x, !y
```

## Comparison

```rust
a == b, a != b, a < b, a > b, a <= b, a >= b
```

```aski
a == b, a != b, a < b, a > b, a <= b, a >= b
```

## Logical

```rust
a && b, a || b
```

```aski
a && b, a || b
```

## Bitwise (S5 via stdlib methods)

```rust
a | b, a & b, a ^ b, a << 2, a >> 2, !x
```

```aski
a.bitOr(b), a.bitAnd(b), a.bitXor(b), a.shiftLeft(2), a.shiftRight(2), a.bitNot
```

Defined via a `BitOps` trait in `.traits` and impls on each numeric
primitive.

## Deref (U1 open)

```rust
*x
```

Not yet defined. Pending U1 decision — possibly a `Deref` trait
dispatch via `*x` unary operator (or no unary `*` at all).

## Cast (S7 via stdlib)

```rust
let u = byte as u32;
let bytes = big as u8;
```

```aski
(u U32:from(byte))
(bytes U8:truncate(big))        ;; narrowing explicit
```

## Assignment (N3/U7 open)

```rust
x = value;
x += 1;
```

Under "method-only" answer:

```aski
~x.set(value)
~x.addAssign(1)
```

Under alternative-"accept `=`" answer (U7-b/c): `~x = value` or
similar TBD.

---

# 10. Error handling

## Result

```rust
fn compute() -> Result<u32, Error> { … }
```

```aski
;; .traits
@[| Compute
  (compute &self {Result U32 Error})
|]
```

## Option

```rust
fn find(key: &str) -> Option<Value> { … }
```

```aski
;; .traits
@[| Find
  (find &self &key String {Option Value})
|]
```

## ? operator

```rust
let x = may_fail()?;
```

```aski
(x self.mayFail?)
```

## panic! — U

```rust
if bad { panic!("unrecoverable"); }
```

Not in aski today. Options: define a `Panic` trait in stdlib with
an impl on the default context; or surface `panic!` as a built-in
expression. Pending.

---

# 11. Modules and visibility

## Module declaration

```rust
mod shapes;   // shapes.rs
```

In aski, each `.types` / `.traits` / `.impls` file is a module.
Import across modules via the module header.

## Use declarations

```rust
use shapes::{Circle, Rectangle};
```

```aski
;; module header in every surface file
(MyModule [shapes Circle Rectangle])
```

## Visibility

```rust
pub fn foo() { … }
pub(crate) fn bar() { … }
pub(super) fn baz() { … }
```

```aski
@(PublicEnum ... )                     ;; pub equivalent
(PrivateEnum ... )                     ;; default private
@(PublicStruct ...)
```

`pub(crate)` / `pub(super)` — U10 open. Proposal: `@(PlaceName)`
scoped visibility.

---

# 12. Attributes and derives

## #[derive(…)]

```rust
#[derive(Clone, Debug, PartialEq)]
pub struct Point { x: f64, y: f64 }
```

```aski
;; .types — the type has no directive
@{Point (@Horizontal F64) (@Vertical F64)}

;; .derivations — rules in scope synthesize impls automatically
;; (rules for Clone, Debug, Eq on Structs with all-Clone/Debug/Eq
;; fields are in a linked derivation file)
```

Global rules in `.derivations` files automatically apply to every
type whose shape matches. No per-type marker on the type declaration.
To override a derived impl for a specific type, write a hand-rolled
`.impls` entry — specificity wins.

## #[cfg(...)] — via platform surfaces

```rust
#[cfg(target_os = "windows")]
pub fn separator() -> char { '\\' }

#[cfg(not(target_os = "windows"))]
pub fn separator() -> char { '/' }
```

```aski
;; windows.impls
@[Default Path Native [
  (separator Char [Char:Punct:Backslash])
]]

;; unix.impls
@[Default Path Native [
  (separator Char [Char:Punct:Slash])
]]
```

Build selects the platform surface.

## #[inline], #[must_use], #[allow(…)] — U

Not spec'd. Could be modeled as metadata in `.impls`, but no
proposal yet.

---

# 13. Async / await

## Rust

```rust
async fn fetch(url: &str) -> Result<Body, Error> { … }
let body = fetch(url).await?;
```

## Aski — proposed `.async-impls` surface

```aski
;; .traits
@[| Fetch
  (fetch &self &url String {Result Body Error})
|]

;; .async-impls
@[Default Fetch HttpClient [
  (fetch &self &url String {Result Body Error} [
    ;; method body runs under a scheduler
    ... await points are method calls on awaitable values ...
    (response Rfi:Tokio:httpGet(url).await)
    response.body
  ])
]]
```

Async is a surface characteristic. A `.impls` method cannot call an
`.async-impls` method without being in an `.async-impls` file
itself. The await points are just method calls that return after
scheduler cooperation.

Details pending. The shape is there — the surface is the anchor.

---

# 14. Unsafe

## Rust

```rust
unsafe fn raw_access(p: *const u32) -> u32 { *p }
```

## Aski — proposed `.unsafe-impls` surface

```aski
;; .unsafe-impls
@[RawAccess Access Pointer [
  (rawAccess &self :p {RawPtr U32} U32 [
    ;; unchecked memory access — marked at surface level
    Rfi:Mem:read(p)
  ])
]]
```

Unsafe concerns localize to `.unsafe-impls`. Programs importing none
are provably memory-safe. Audit is by import graph.

---

# 15. Macros

## declarative macros (macro_rules!) — via derivation or code synthesis

Rust:
```rust
macro_rules! vec {
    ($($x:expr),*) => { /* construct Vec */ };
}
```

aski's parallel: a combination of:
- Primitive constructors (`Vec:from`, `Vec:of`)
- Derivation rules (for structural patterns)
- No source-level text rewriting

Macro-level pattern matching over token trees — not in aski. Every
pattern is structural, via types and derivations.

## procedural macros — replaced by `.derivations`

See [06-derivations-and-testing.md](06-derivations-and-testing.md).

---

# 16. Collections / stdlib

All stdlib types live in `.types`. All traits live in `.traits`.
All impls live in `.impls`. Concrete examples:

```aski
;; stdlib/types/vec.types
@{Vec {$Value}
  (items {Array $Value Capacity})
  (count U32)}

;; stdlib/traits/iterator.traits
@[| Iterator
  Item
  (next ~&self {Option self:Item})
|]

;; stdlib/impls/vec-iter.impls
@[Default Iterator {Vec $Value} [
  (Item $Value)
  (next ~&self {Option $Value} [ ... ])
]]

;; stdlib/impls/vec-index.impls
@[Default Index {Vec $Value} [
  (at &self :idx U32 {Option &$Value} [ ... ])
]]

;; stdlib/impls/vec-mutate.impls
@[Default Mutate {Vec $Value} [
  (push ~&self :value $Value [ ... ])
  (pop  ~&self {Option $Value} [ ... ])
]]
```

Every "method on Vec" is an impl on some trait. The stdlib is many
small trait-impl pairs.

---

# 17. Concurrency

## Threads / Send / Sync — U today

Proposed: a `.effects` surface with `.concurrent-effects` or similar.

```aski
;; concurrent.effects
@[Default Spawn Thread [
  (spawn ?{$Ret} :action {Callable $Ret} {Handle $Ret} [ ... ])
]]
```

## Send / Sync markers

```aski
;; .traits
@[| Send |]
@[| Sync |]

;; .impls — auto-derived for types whose fields all have the marker
```

Derivation rule: "A type is Send if all its fields are Send."

---

# 18. FFI (extern)

## Rust

```rust
extern "C" { fn getpid() -> u32; }
```

## Aski — `.rfi` surface (already spec'd)

```aski
;; posix.rfi
(Process
  (getPid U32))
```

Calling RFI:

```aski
;; native.effects
@[Default ProcessInfo System [
  (pid &self U32 [Rfi:Process:getPid])
]]
```

---

# 19. Type aliases — U (user-preference OUT)

```rust
type UserId = u64;    // identity-weak alias
```

Use newtype instead:

```aski
;; .types
@(| UserId @U64 |)    ;; distinct type, preserves identity
```

---

# 20. Arrays and slices

## Array (S11 proposed)

```rust
let buffer: [u32; 16] = [0; 16];
```

```aski
(buffer {Array U32 16} Array:fill(16 0))
```

## Slice (U5 open)

```rust
let s: &[u32] = &buffer[0..10];
```

Pending. Possible shapes: `{Slice U32}` primitive with arity 1, or
route through views on Vec.

---

# 21. Trait method call syntax

## Rust — ambiguity resolution

```rust
let x = <MyType as MyTrait>::method(arg);
```

## Aski — named-impl resolution

```aski
;; .impls
(x MyImpl:method(arg))        ;; when MyImpl is the activation name
```

Call through the named impl directly. No "fully qualified trait syntax"
because named impls make disambiguation automatic.

---

# 22. The complete coverage scorecard

| Rust feature | aski home | Notes |
|--------------|-----------|-------|
| Primitives (int/float/bool/char/str/String/Vec/Option/Box/Result) | `.types` | Char via nested enum |
| Struct named fields | `.types` | ✓ |
| Struct tuple fields | | **OUT** except single-tuple newtype |
| Enum bare / data / struct variants | `.types` | ✓ |
| Discriminants | `.types` | U15 `[Name Literal]` |
| Generic params | `.types` / `.traits` / `.impls` | ✓ |
| Generic bounds | `.types` / `.traits` / `.impls` | `{$T{Bound}}` |
| Super-traits | `.traits` | ✓ |
| Associated types | `.traits` | ✓ |
| Associated consts | `.traits` | S9 |
| Default methods | `.traits` | ✓ |
| Trait impl | `.impls` | named, scope-activated |
| Generic impl | `.impls` | ✓ |
| Blanket impl | `.impls` | ✓ |
| Inherent impl | | **OUT** — use single-method trait |
| `dyn Trait` | `.traits` usage | S6 syntax + semantics |
| `impl Trait` | | U (design) |
| Closures | `.impls` named-type (A) or inline (B/C) | S4 |
| References | method params | `&` / `~&` |
| Lifetimes | method params | `'Place` origins |
| View types | method params | `{|Field|}` |
| Raw pointers | | U — `.unsafe-impls` future |
| Match | method body | ✓ |
| if/else | method body | via match on Bool |
| while | method body | `[\| cond body \|]` |
| for | method body | `{\| src.binding body \|}` |
| loop (infinite) | method body | `[\| true body \|]` |
| break/continue/labels | method body | U13 `^^` / `^~` / `^'Label` |
| return / ? | method body | `^` / `?` |
| Arithmetic operators | method body | ✓ |
| Unary - / ! | method body | C6 accepted |
| Unary * (deref) | method body | U1 open |
| Bitwise | method body | via stdlib BitOps |
| Cast | method body | via stdlib From/Into/TryFrom |
| Assignment | method body | U7 — method-only today |
| Result / Option / ? | all | ✓ |
| panic! | all | U — proposed via stdlib |
| Modules / use | module header | ✓ |
| Visibility public/private | all | `@` |
| Scoped visibility | all | U10 |
| `#[derive]` | `.derivations` | ✓ |
| `#[cfg]` | platform surfaces | ✓ |
| `#[inline]` etc. | metadata | U |
| async/await | `.async-impls` | proposed |
| unsafe | `.unsafe-impls` | proposed |
| macro_rules / proc macro | | replaced by `.derivations` |
| Collections | `.types` + `.impls` | ✓ |
| Threads / Send / Sync | | U — `.concurrent-effects` future |
| FFI | `.rfi` + `.effects` | ✓ |
| Type aliases | | replaced by newtype |
| Arrays | `.types` | S11 |
| Slices | | U5 open |

**Coverage**: every Rust feature has a home in aski — either a
current surface, a proposed surface, or a deliberate OUT with an
idiom replacement.

---

# What aski adds that Rust doesn't have

- **Named impls** per (Trait, Target) with scope-based activation.
- **Orphan-rule relaxation** via global coherence.
- **Effect surfaces** providing link-level purity.
- **Platform surfaces** providing capability-at-build-time.
- **Derivation surfaces** as first-class alternatives to proc macros.
- **Test-impl / bench-impl surfaces** replacing `cfg(test)`.
- **Sema specialization** driven by the impl graph.
- **Self-describing architecture** via surfaces.

Some of these are fundamentally beyond what Rust can do without a
major redesign. Most become natural in multi-surface aski.

---

# Next

The transition plan: how aski v0.20 grows into this.
[10-transition →](10-transition.md)
