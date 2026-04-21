# 02 — The `.types` Surface

*Every Rust type feature, in aski.*

[← 01-surfaces](01-surfaces.md) · [03-traits →](03-traits.md)

---

# What `.types` contains

Pure shape. Five declaration kinds:

- **Enum** — one-of. `()` root delimiter.
- **Struct** — all-of. `{}` root delimiter.
- **Newtype** — wrapping. `(||)` root delimiter.
- **Const** — named compile-time value. `{||}` root delimiter.
- **Module header** — name and imports. The first item.

No methods. No bodies. No traits. No impls. No RFI.

---

# Module header

```aski
(ModuleName [shapes Quality Shape] [collections Vec Map])
```

`(Name [imports...])` — first item in every `.types` file. Each
import is `[SourceModule ImportedName...]`.

---

# Enums — the full Rust enum set

## Bare variants

```rust
enum Element { Fire, Earth, Air, Water }
```

```aski
@(Element Fire Earth Air Water)
```

Public via leading `@`. Default-private without.

## Data variants (one-payload)

```rust
enum Shape {
    Circle(f64),
    Triangle(f64),
}
```

```aski
@(Shape
  (Circle F64)
  (Triangle F64))
```

## Multi-field variants → struct variants (no tuples)

```rust
enum Shape {
    Rectangle(f64, f64),       // tuple variant — Rust only
}
```

```aski
@(Shape
  {Rectangle (Width F64) (Height F64)})
```

Struct variant with named fields. aski rejects tuple variants per
§No Tuples.

## Nested enum inside enum

```rust
enum Event {
    Tick,
    Network(NetworkEvent),
}

enum NetworkEvent { Connected, Disconnected, Message(String) }
```

```aski
@(Event
  Tick
  (| Network Connected Disconnected (Message String) |))
```

`(|…|)` is a nested enum inside `()` enum body. Access via
`Event:Network:Message("hi")`.

## Nested struct inside enum

```rust
enum Layer {
    Flat,
    Bounded { min: f64, max: f64 },
}
```

```aski
@(Layer
  Flat
  {Bounded (Min F64) (Max F64)})
```

`{…}` inside `()` = struct-variant with named fields. Match as
`Layer:Bounded` binding `Min` and `Height` via destructure.

(Distinct from `{|…|}` inside an enum, which is a *nested struct
definition* scoped to the enum's namespace — a type in Layer's
scope, not a variant of Layer.)

## Discriminant variants (pending U15 decision)

```rust
#[repr(u16)]
enum HttpStatus { Ok = 200, NotFound = 404, ServerError = 500 }
```

```aski
@(HttpStatus
  [Ok 200]
  [NotFound 404]
  [ServerError 500])
```

`[VariantName @Literal]` as a new variant shape using the `[...]`
delimiter (free at enum-body position). First-token decidable.

## Generic enums

```rust
enum Option<T> { Some(T), None }
enum Result<T, E> { Ok(T), Err(E) }
```

```aski
@(Option {$Value} (Some $Value) None)
@(Result {$Output $Failure} (Ok $Output) (Err $Failure))
```

Generic slot in `{}` after the enum name. Names are meaningful, no
single-letter placeholders.

## Bounded generic enums

```rust
enum Cached<T: Clone + Debug> { Empty, Loaded(T) }
```

```aski
@(Cached {$Value{Clone Debug}} Empty (Loaded $Value))
```

Bound set in `{}` after the param name.

## Enum with multi-arity generic constructors

```rust
enum Tree<T> {
    Leaf(T),
    Branch(Box<Tree<T>>, Box<Tree<T>>),
}
```

```aski
@(Tree {$Value}
  (Leaf $Value)
  {Branch (Left {Box {Tree $Value}}) (Right {Box {Tree $Value}})})
```

Branch uses a struct variant with two named boxed-tree fields.

---

# Structs — the full Rust struct set

## Named fields

```rust
struct Point { horizontal: f64, vertical: f64 }
```

```aski
@{Point (@Horizontal F64) (@Vertical F64)}
```

## Mixed visibility

```rust
pub struct Counter {
    pub count: u32,
    cache: u32,
}
```

```aski
@{Counter (@Count U32) (Cache U32)}
```

`(@FieldName Type)` public; `(FieldName Type)` private. Field names
are Pascal regardless of visibility — fields are compile-time
structural per design.md §PascalCase and camelCase.

## Self-typed fields (when field name IS the type name)

```rust
struct Drawing {
    shapes: Vec<Shape>,
    name: Name,
}
```

```aski
@{Drawing (@Shapes {Vec Shape}) @Name}
```

`@Name` as a bare word = self-typed public field. The field named
`Name` is of type `Name`. Pure win: less repetition.

## Tuple structs → not allowed

```rust
pub struct Pair(f64, f64);    // OUT per §No Tuples
```

Use a named struct:

```aski
@{Pair (@Left F64) (@Right F64)}
```

## The one tuple exception: single-tuple newtype = wrapped abstraction

```rust
pub struct UserId(u64);
pub struct Millimeters(f64);
```

```aski
@(| UserId @U64 |)
@(| Millimeters @F64 |)
```

This is **newtype**, not tuple. A newtype wrapping one type is a
legitimate abstraction — it creates a distinct type over a wrapped
value, preserves identity, forbids accidental substitution.

## Unit structs

```rust
pub struct Marker;
```

```aski
@{Marker}
```

Empty struct body. Instance is `Marker {}`.

## Struct with generic parameters

```rust
struct Pair<Left, Right> { left: Left, right: Right }
```

```aski
@{Pair {$Left $Right} (@Left $Left) (@Right $Right)}
```

## Struct with bounded generics

```rust
struct Container<T: Clone + Debug> { items: Vec<T>, count: u32 }
```

```aski
@{Container {$Value{Clone Debug}} (@Items {Vec $Value}) (@Count U32)}
```

## Nested struct inside struct

```rust
struct Drawing {
    shapes: Vec<Shape>,
    config: Config,
}

struct Config { timeout: u32, retries: u32 }
```

```aski
@{Drawing
  (@Shapes {Vec Shape})
  {| Config (@Timeout U32) (@Retries U32) |}}
```

`{|…|}` nests a Config struct inside Drawing's scope. Access via
`Drawing.Config` (scope-descent).

## Nested enum inside struct

```rust
struct Engine {
    state: State,
    stats: Stats,
}

enum State { Idle, Running, Halted }
```

```aski
@{Engine
  (@State State)
  (@Stats Stats)
  (| State Idle Running Halted |)}
```

The nested `(| … |)` adds State as an inner enum.

---

# Newtypes — the core of aski's type identity

## Transparent newtype (public wrapped value)

```rust
pub struct Counter(pub u32);
```

```aski
@(| Counter @U32 |)
```

`@U32` inside = wrapped value is public. Consumers can read the
underlying U32.

## Opaque newtype (invariant-protecting)

```rust
pub struct PositiveCount(u32);     // private wrapped value
```

```aski
@(| PositiveCount U32 |)
```

Wrapped value is private. Consumers must use methods to inspect /
construct.

## Generic newtype

```rust
pub struct Handle<T>(u32, PhantomData<T>);    // Rust needs PhantomData
```

```aski
@(| Handle {$Value} @U32 |)
```

No PhantomData needed — aski's type system tracks the `$Value`
parameter structurally. (If usage needs it later, aski-core could
carry a phantom marker but it's not forced on the user.)

## Newtype with bounded generic

```rust
pub struct Sorted<T: Ord>(Vec<T>);
```

```aski
@(| Sorted {$Value{Ord}} @{Vec $Value} |)
```

## Newtype as a unit for physical quantities

```rust
pub struct Seconds(pub f64);
pub struct Meters(pub f64);
pub struct Mass(pub f64);
```

```aski
@(| Seconds @F64 |)
@(| Meters  @F64 |)
@(| Mass    @F64 |)
```

aski's type-identity preservation makes `Seconds` and `Meters` truly
distinct. You cannot accidentally add Seconds to Meters without an
explicit conversion impl.

---

# Consts

## Literal const

```rust
const MAX_USERS: u32 = 100;
```

```aski
@{| MaxUsers U32 100 |}
```

## Expression const (pending S8)

```rust
const MAX_SESSIONS: u32 = MAX_USERS * 4;
```

```aski
@{| MaxSessions U32 MaxUsers * 4 |}
```

Requires S8 landing (Const.Value: Expr rather than Literal).

## Typed const with derived computation

```rust
const BUFFER_BITS: u32 = (MAX_USERS + MAX_SESSIONS) * 8;
```

```aski
@{| BufferBits U32 {(MaxUsers + MaxSessions) * 8} |}
```

`{}` used at expression position is StructConstruct normally; in
const RHS, veric const-evals the expression.

## Private const

```rust
const TUNING: f64 = 1.618;
```

```aski
{| Tuning F64 1.618 |}
```

No `@` = private to module.

---

# Primitives in `.types`

Aski's primitives carry by convention (not a grammar list):

```aski
U8 U16 U32 U64
I8 I16 I32 I64
F32 F64
Bool    Char    String
Vec     Option  Box    Result
```

Plus proposed additions:
- `Never` (for divergent functions) — `N2`
- `Array` (arity 2: `{Array T N}`) — `S11`
- `Char` as a nested enum (U16 landing direction)

---

# References, borrows, origins, views at type position

```rust
fn describe(&self) -> &str { … }
fn emit(&mut self, out: &mut Writer) { … }
fn leftmost<'a>(tree: &'a Tree) -> &'a str { … }
```

```aski
(describe &self String)
(emit ~&self ~&out Writer)
(leftmost &'Tree self String)
```

Borrow sigils, origin sigil `'Place`, view types `{| field… |}`
as shown in design.md.

---

# Type application — `{}` everywhere

```rust
Vec<u32>
Option<Vec<String>>
Result<u32, ConversionError>
HashMap<String, Vec<Token>>
```

```aski
{Vec U32}
{Option {Vec String}}
{Result U32 ConversionError}
{HashMap String {Vec Token}}
```

`{Constructor Arg1 Arg2 …}` uniformly. No angle brackets anywhere
in aski.

---

# Enum variant construction / access

```rust
Option::Some(42)
Result::Err(error)
Element::Fire
Tree::Branch(left, right)
```

```aski
Option:Some(42)
Result:Err(error)
Element:Fire
Tree:Branch(left right)
```

`:` is path. `Type:Variant(args)` for data variants, `Type:Variant`
for bare.

---

# Nested type access

```rust
Engine::State::Idle     // nested enum
Engine.State             // Rust doesn't allow this exact form; aski does
```

```aski
Engine:State:Idle        ;; chained : through nested enum scope
```

The chained-`:` path is consistent with U16's `Char:Upper:A`
direction.

---

# Slice and array types

Array (pending S11):
```aski
(buffer {Array U32 16} Array:init(16 0))
```

Slice (U5, open): to be decided — if accepted, plausible shape is
`{Slice T}` as a primitive with arity 1.

---

# Full enum-with-everything example

```rust
#[repr(u16)]
pub enum HttpError<T: Display + Debug> {
    NotFound = 404,
    Timeout(u64),
    Rejected { code: u32, reason: String, payload: Option<T> },
    Nested(Box<HttpError<T>>),
    Unhandled,
}
```

```aski
@(HttpError {$Context{Display Debug}}
  [NotFound 404]
  (Timeout U64)
  {Rejected (Code U32) (Reason String) (Payload {Option $Context})}
  (Nested {Box {HttpError $Context}})
  Unhandled)
```

Generic, bounded, mixed variant shapes, explicit discriminant, nested
boxed recursive. All in one enum. All in `.types`. No behavior
anywhere.

---

# What cannot appear in `.types`

- Any method definition
- Any trait declaration (`.traits`)
- Any trait implementation (`.impls`)
- Any block / body / statement
- Any local declaration with initialization logic
- Any expression requiring evaluation (beyond const-eval in consts)
- Any RFI call
- Any I/O

`.types` is shape and only shape. A `.types` file compiled in
isolation produces a typed domain-tree with zero executable content.

---

# Why this matters

A `.types` compile is fast. It's cacheable per file. It's shareable
as rkyv. Tooling can run on it alone — IDE autocomplete, doc
generation, schema export — without loading the rest of the program.

The `.core` files already prove this works. Scaling it to
user-written type libraries is straightforward.

---

# Next

The `.traits` surface. Interfaces without implementations.
[03-traits →](03-traits.md)
