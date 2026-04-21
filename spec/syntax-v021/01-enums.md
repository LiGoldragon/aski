# Enums

Enum declarations live in `[_]Name.enum` files. Filename = enum name (Pascal). Leading `_` = private.

**Content grammar:** `?<GenericSlot> *<Variant>` — an optional generic slot followed by zero or more variants.

## Bare variants

```
Element.enum
```

```aski
Fire
Earth
Air
Water
```

```rust
pub enum Element { Fire, Earth, Air, Water }
```

## Private enum

```
_InternalState.enum
```

```aski
Loading
Ready
Done
```

```rust
enum InternalState { Loading, Ready, Done }
```

## Data variants and struct variants

```
Shape.enum
```

```aski
(Circle F64)
{Rectangle (Width F64) (Height F64)}
(Triangle F64)
```

```rust
pub enum Shape {
    Circle(f64),
    Rectangle { width: f64, height: f64 },
    Triangle(f64),
}
```

- **Data variant:** `(VariantName Type)` — single positional payload.
- **Struct variant:** `{VariantName (Field Type) ...}` — named-field payload. Struct-variant fields are Pascal and inherit enum visibility (no `@` on them).

## Generic enum

```
Option.enum
```

```aski
{$Value}
(Some $Value)
None
```

```rust
pub enum Option<T> { Some(T), None }
```

First token is `{` — the generic slot. After the slot, variants follow.

```
Result.enum
```

```aski
{$Output $Failure}
(Ok $Output)
(Err $Failure)
```

```rust
pub enum Result<T, E> { Ok(T), Err(E) }
```

## Bounded generic enum

```
Cached.enum
```

```aski
{$Value{Clone Debug}}
Empty
(Loaded $Value)
```

```rust
pub enum Cached<T: Clone + Debug> { Empty, Loaded(T) }
```

## Nested enum and nested struct

```
Token.enum
```

```aski
(Ident String)
(Number I64)
(| Delimiter LParen RParen LBracket RBracket LBrace RBrace |)
Newline
```

```rust
pub enum Token {
    Ident(String),
    Number(i64),
    Delimiter(Delimiter),
    Newline,
}
pub enum Delimiter { LParen, RParen, LBracket, RBracket, LBrace, RBrace }
```

Access a nested variant via chained path: `Token:Delimiter:LParen`.

```
Event.enum
```

```aski
Ping
(Retry U32)
{| Config (Timeout U32) (MaxRetries U32) |}
```

```rust
pub enum Event { Ping, Retry(u32) }
pub struct Event::Config { timeout: u32, max_retries: u32 }
```

`{| Config ... |}` = nested struct scoped under `Event`. Access via `Event:Config`.

## Enum with discriminants

```
HttpStatus.enum
```

```aski
[Ok 200]
[NotFound 404]
[ServerError 500]
```

```rust
#[repr(u16)]
pub enum HttpStatus {
    Ok = 200,
    NotFound = 404,
    ServerError = 500,
}
```

`[VariantName Literal]` at enum-body position. `[` is the free first-token for the discriminant form — no other variant form uses it at that position.

## Nested split (optional)

When a nested variant grows large enough to deserve its own file, it can be split out. The parent file references it by bare Pascal; the engine resolves via sub-path.

```
Shape.enum               # outer
Shape/Rectangle.struct   # extracted struct variant
```

`Shape.enum`:

```aski
(Circle F64)
Rectangle
(Triangle F64)
```

`Shape/Rectangle.struct`:

```aski
(Width F64)
(Height F64)
```

Type identity `Shape:Rectangle` is unchanged. Splitting is a filesystem concern, not a grammar one.
