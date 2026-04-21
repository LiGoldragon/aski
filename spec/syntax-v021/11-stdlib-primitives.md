# Stdlib primitives

## Primitive types

Zero-arity primitives in the base type system:

| Type | Role |
|---|---|
| `U8`, `U16`, `U32`, `U64` | unsigned integers |
| `I8`, `I16`, `I32`, `I64` | signed integers |
| `F32`, `F64` | floats |
| `Bool` | boolean (see below) |
| `String` | UTF-8 string |
| `Unit` | zero-information |
| `Never` | divergent (see below) |

Arity-1 primitives: `Vec`, `Option`, `Box`.
Arity-2 primitives: `Result`, `Array`.

`Array` takes `{Array Element Size}` where `Size` is a const-eval U32 expression.

## Bool

`Bool` is a primitive with two literal tokens: `true` and `false`. They are literal tokens — same class as integer literals like `42` — not identifiers. The case rule (which dispatches on the first character of an *identifier*) does not apply: literals are their own token category.

```aski
(ready Bool true)
(failed Bool false)
```

```rust
let ready: bool = true;
let failed: bool = false;
```

In match arms:

```aski
(| self.ready
  (true)   self.run
  (false)  self.wait
|)
```

`Bool` has the standard boolean operators (`&&`, `||`, `!`) and comparison ops that produce it.

## Never

`Never` is a zero-arity primitive for functions that do not return normally. Mirrors Rust's `!`.

```aski
(panic &msg String Never)
(runForever ~&self Never [| [self.tick] |])
```

```rust
fn panic(msg: &str) -> ! { ... }
fn run_forever(&mut self) -> ! { loop { self.tick() } }
```

## 'Static and lifetime generics

Rust's lifetime generics (`<'a>`) map to aski's place-based origins. `'Static` is a conventional PlaceName for program-root scope.

```aski
(longest &'(left right) left String
         &'(left right) right String
         &'(left right) String [ ... ])

(findName &id U32 &'Static String [
  GlobalTable.lookup(id)
])
```

```rust
fn longest<'a>(left: &'a str, right: &'a str) -> &'a str { ... }
fn find_name(id: u32) -> &'static str { GLOBAL_TABLE.lookup(id) }
```

`'Static` is a place name by convention — no grammar change. Other lifetime-generic scenarios map to place-union origins (`&'(a b)` = union of two places).

## Char library

`Char` is an enum library where each character is a variant accessed by chained path. No character literal syntax — characters are a library, not a primitive literal form.

```
Char.enum
```

```aski
(| Upper A B C D E F G H I J K L M N O P Q R S T U V W X Y Z |)
(| Lower A B C D E F G H I J K L M N O P Q R S T U V W X Y Z |)
(| Digit Zero One Two Three Four Five Six Seven Eight Nine |)
(| Whitespace Space Tab Newline CarriageReturn FormFeed VerticalTab |)
(| Control Null Bell Backspace Escape ... |)
(| Punct Tilde Comma Period Question Exclamation Colon Semicolon Apostrophe QuotationMark Hyphen Underscore ... |)
(| Bracket LParen RParen LBracket RBracket LBrace RBrace LAngle RAngle |)
(Code (Codepoint U32))
```

Usage:

```aski
(c Char:Upper:A)                    # the letter A
(space Char:Whitespace:Space)
(sigma Char:Code(0x03C3))           # Greek small sigma (non-categorized)
```

Under II-L, the library can be split:

```
stdlib/
  Char.enum                         # head: variants by category
  Char/
    Upper.enum                      # A..Z as bare variants
    Lower.enum                      # a..z
    Digit.enum                      # Zero..Nine
    Whitespace.enum
    Control.enum
    Punct.enum
    Bracket.enum
```

The final category list is still provisional. See [16-open-questions §Char category list](16-open-questions.md#char-category-list).

## Arrays

```aski
(buffer {Array U32 16} Array:fill(16 0))
(table  {Array {Array U8 8} 8} Table:blank)

# BoardSize.const -> U32 8
(board {Array Cell BoardSize * BoardSize})
```

```rust
let buffer: [u32; 16] = ...;
let table:  [[u8; 8]; 8] = Table::blank();
let board:  [Cell; BOARD_SIZE * BOARD_SIZE];
```

Construction is via methods: `Array:fill(n, value)`, `Array:of(a, b, c)`. No delimiter-array literal form — see [16-open-questions §Array literals](16-open-questions.md#array-literals).

## Currently unspec'd primitives

These are not in v0.21 and not explicitly rejected — see [16-open-questions §Unspec'd primitives](16-open-questions.md#unspecd-primitives) for the list (U128/I128, Usize/Isize, &str, Rc/Arc, Cell/RefCell, Mutex/RwLock, HashMap/HashSet, slice `[T]`).
