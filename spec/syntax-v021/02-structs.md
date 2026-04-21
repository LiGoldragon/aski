# Structs

Struct declarations live in `[_]Name.struct` files.

**Content grammar:** `?<GenericSlot> *<Field>`.

**Field forms:**

| Form | Meaning |
|---|---|
| `(FieldName Type)` | typed field, private |
| `(@FieldName Type)` | typed field, public |
| `FieldName` | self-typed, private (field name IS type) |
| `@FieldName` | self-typed, public |

Field names are Pascal. The `@` sigil marks a public field. Visibility lives inside the body because one struct can mix public and private fields — the path only carries the struct's own visibility.

## Public struct with public fields

```
Point.struct
```

```aski
(@Horizontal F64)
(@Vertical F64)
```

```rust
pub struct Point { pub horizontal: f64, pub vertical: f64 }
```

## Mixed-visibility fields

```
Counter.struct
```

```aski
(@Count U32)
(Cache U32)
```

```rust
pub struct Counter { pub count: u32, cache: u32 }
```

## Opaque struct (public struct, all-private fields)

```
SecretData.struct
```

```aski
(Key String)
(Nonce U64)
```

```rust
pub struct SecretData { key: String, nonce: u64 }
```

## Private struct

```
_InternalPoint.struct
```

```aski
(Horizontal F64)
(Vertical F64)
```

```rust
struct InternalPoint { horizontal: f64, vertical: f64 }
```

The leading `_` on the filename marks the struct itself as private. Per-field `@` still applies inside.

## Generic struct

```
Pair.struct
```

```aski
{$Left $Right}
(@LeftValue $Left)
(@RightValue $Right)
```

```rust
pub struct Pair<Left, Right> {
    pub left_value: Left,
    pub right_value: Right,
}
```

## Bounded generic struct

```
Container.struct
```

```aski
{$Value{Clone Debug}}
(@Items {Vec $Value})
(@Count U32)
```

```rust
pub struct Container<T: Clone + Debug> {
    pub items: Vec<T>,
    pub count: u32,
}
```

## Self-typed fields

```
Drawing.struct
```

```aski
(@Shapes {Vec Shape})
@Name
```

```rust
pub struct Drawing { pub shapes: Vec<Shape>, pub name: Name }
```

`@Name` — public self-typed field. The field named `Name` is of type `Name`.

## Unit struct (empty body)

```
Marker.struct
```

(file contains no non-comment tokens)

```rust
pub struct Marker;
```

## Struct with nested enum and nested struct

```
Page.struct
```

```aski
(@Content String)
(| Orientation Portrait Landscape |)
{| Margin (Top U32) (Bottom U32) (Left U32) (Right U32) |}
```

```rust
pub struct Page { pub content: String }
pub enum Page::Orientation { Portrait, Landscape }
pub struct Page::Margin { top: u32, bottom: u32, left: u32, right: u32 }
```

Nested types are scoped under `Page`. Access: `Page:Orientation:Portrait`, `Page:Margin`.

## Struct with origin-bearing fields

```
Borrowed.struct
```

```aski
{$Value}
(@Source &'self $Value)
(@Count U32)
```

```rust
pub struct Borrowed<'a, T> { pub source: &'a T, pub count: u32 }
```

The `'self` origin says "this borrow originates at the struct instance itself" — Polonius-style place annotation. See [08-body-basics §References, borrows, origins, views](08-body-basics.md#references-borrows-origins-views).
