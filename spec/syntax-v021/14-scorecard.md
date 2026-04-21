# Rust feature coverage scorecard

Every Rust feature mapped to its aski v0.21 expression.

**Legend:** L = landed · P = proposed (see §16) · U = unspec'd · OUT = explicitly out

## Primitives

| Feature | Status | Notes |
|---|---|---|
| `U8`–`U64`, `I8`–`I64`, `F32`, `F64` | L | |
| `Bool` | L | primitive with `true`/`false` literal tokens |
| `String` | L | |
| `Char` | L-alt | `Char` library (no char literal syntax) |
| `Unit` | L | |
| `Vec`, `Option`, `Box`, `Result` | L | |
| `Never` / `!` | L | zero-arity primitive |
| `Array` / `[T; N]` | L | `{Array T N}` |
| Unit literal `()` | P | Unit variant exists; literal form open |
| `U128`, `I128` | U | |
| `Usize`, `Isize` | U | |
| `&str` borrowed slice | U | aski has `String`; no `&str` distinction |
| Slice `[T]` | U | |
| `Rc`, `Arc`, `Cell`, `RefCell`, `Mutex`, `RwLock` | U | |
| `HashMap`, `BTreeMap`, `HashSet` | U | type applications would work |
| Union | U | |

## Compound types

| Feature | Status | Notes |
|---|---|---|
| Struct (named fields) | L | `Name.struct` |
| Struct (self-typed fields) | L | |
| Enum (bare / data / struct variants) | L | `Name.enum` |
| Newtype | L | `Name.newtype` |
| Nested enum / struct | L | `(\| \|)` / `{\| \|}` in body |
| Tuple | OUT | names required — no positional grouping |

## References and pointers

| Feature | Status | Notes |
|---|---|---|
| `&T` shared borrow | L | |
| `&mut T` | L | `~&T` |
| `'a` lifetime generics | L-alt | replaced by place-based origins |
| `'static` | L | `'Static` place name |
| Place-based origins | L | |
| View types | L | `{\| fields \|}` |
| Borrow of place expression | L | `&self.Field`, `&foo.Bar.Baz` |
| `*const T` / `*mut T` raw pointer | U | |

## Callable types

| Feature | Status | Notes |
|---|---|---|
| `fn` pointer `fn(A) -> B` | U | |
| `Fn` / `FnMut` / `FnOnce` | U | |
| Closure literal `\|x\| body` | P | inline sugar — see §16 |
| `Callable` trait | L | stdlib trait; zero grammar change |

## Type system

| Feature | Status | Notes |
|---|---|---|
| Generic type params | L | `{$Value}` |
| Trait bounds | L | `$Value{Clone Debug}` |
| Super-traits | L | |
| Associated types | L | |
| Associated consts | L | |
| Method-level generics | L | `?{$Param}` |
| Where clauses | U | |
| GATs | U | |
| HRTB `for<'a>` | U | |
| const generics | U | |
| `impl Trait` | U | |
| `dyn Trait` | L | `?{Trait}` — sema references types, cannot store instances |
| `PhantomData` | U | aski tracks params structurally |
| HKT | U | |
| Dependent types | U | |

## Control flow

| Feature | Status | Notes |
|---|---|---|
| `match` | L | |
| `if` / `else` (via match on Bool) | L | idiom |
| `if let` / `while let` | L | idiom |
| `while` | L | `[\| ? cond body \|]` |
| `loop` (infinite) | L | `[\| body \|]` |
| `for` | L | iteration `{\| src.binding body \|}` |
| `break` / `continue` / labels | P | see §16 |
| `return` | L | `^expr` |
| `?` try-unwrap | L | postfix |
| `async` / `await` | U | |

## Expressions

| Feature | Status | Notes |
|---|---|---|
| `+` `-` `*` `%` | L | |
| `/` | L | |
| `==` `!=` `<` `>` `<=` `>=` | L | |
| `&&` `\|\|` | L | |
| Bitwise `&` `\|` `^` `<<` `>>` | L-via-methods | `BitOps` trait |
| Unary `-` | L | |
| Unary `!` | L | |
| Unary `*` (deref) | L | via `Deref` trait |
| Assignment `=` | U | see §16 |
| Compound assignment `+=` | U | see §16 |
| Method call `.method(...)` | L | |
| Field access `.Field` | L | |
| Cast `as` | L-via-methods | `From`/`Into`/`TryFrom` |
| Range `..` `..=` | L | |
| Array literal `[x; n]` | U | see §16 |
| Tuple literal | OUT | |
| Struct literal | L | |
| Block as expression | L | InlineEval |
| Macro invocation `foo!()` | U | |

## Patterns

| Feature | Status | Notes |
|---|---|---|
| Wildcard `_` | L | |
| Variant match | L | |
| Variant bind | L | |
| Or-pattern `[A B]` (variants) | L | |
| String literal | L | |
| Numeric literal (int/float) | L | |
| Bool literal | L | `true`/`false` at pattern position |
| Struct destructuring | P | binding rule — see §16 |
| Tuple destructuring | OUT | |
| Reference pattern `&x` | U | |
| Binding `name @ pattern` | U | `@` is visibility |
| Range pattern `0..=9` | U | |
| Guard `if cond` | U | |
| Rest `..` | U | |
| General or-pattern `A \| B` (non-variant) | U | |

## Items

| Feature | Status | Notes |
|---|---|---|
| Struct / Enum / Newtype / Const | L | per-kind extensions |
| Trait / TraitImpl | L | `.trait` / `.impl` |
| Module header | OUT-in-source | directory = module |
| Free function | OUT | methods on types only |
| Inherent impl | U | |
| Type alias | U | |
| Static item | U | |
| Submodule `mod` | OUT-in-source | directory IS the submodule |
| `macro_rules!` | U | replaced by `.derivation` |
| Proc macros | U | replaced by `.derivation` |
| `extern` block | L-alt | `.rfi` surface |

## Visibility

| Feature | Status | Notes |
|---|---|---|
| `pub` | L | no filename prefix / `@` on fields |
| default private | L | `_` filename prefix / bare field |
| `pub(crate)` / `pub(super)` / `pub(in path)` | U | see §16 |

## Safety

| Feature | Status | Notes |
|---|---|---|
| `unsafe` | U | |
| `transmute` | U | |
| Raw pointer deref | U | |

## Error handling

| Feature | Status | Notes |
|---|---|---|
| `Result<T, E>` | L | |
| `Option<T>` | L | |
| `?` try-unwrap | L | |
| `panic!` | U | |
| `Error` trait | U | |

## Strings and literals

| Feature | Status | Notes |
|---|---|---|
| String literal `"..."` | L | |
| Escape sequences | L | |
| Raw string `r"..."` | L | triple-quote form |
| Byte string `b"..."` | U | |
| Char literal `'x'` | OUT-replaced | Char library |
| Byte literal `b'x'` | U | |
| Int literal (decimal) | L | |
| Int literal hex/oct/bin | L | |
| Numeric separators `1_000` | L | |
| Typed integer suffix `42u32` | P | see §16 |
| Float literal | L | |
| Bool literal `true` / `false` | L | primitive literal tokens |

## Stdlib traits

| Trait | Status | Notes |
|---|---|---|
| `From` / `Into` / `TryFrom` / `TryInto` | L-via-methods | |
| `Callable` | L-via-methods | |
| `Counter` (set/addAssign/…) | L-via-methods | |
| `BitOps` | L-via-methods | |
| `Deref` | L-via-methods | |
| `Clone`, `Copy`, `Debug`, `Display`, `PartialEq`, `Eq`, `Hash`, `PartialOrd`, `Ord`, `Default` | U | no stdlib spec yet |
| `AsRef`, `Borrow` | U | |
| `Iterator` | U | iteration syntax landed |
| `Fn` / `FnMut` / `FnOnce` | U | |
| `Index` / `IndexMut` | U | |
| `Add` / `Sub` / `Mul` / `Div` / `Rem` | U | operators bound, traits not |
| `Neg` / `Not` | P | operators landed |
| `Send` / `Sync` | U | |
| `Drop` | U | |

## Concurrency

All unspec'd.

## Attributes

| Feature | Status | Notes |
|---|---|---|
| `#[derive(...)]` | L-alt | `.derivation` surface |
| `#[cfg(...)]` | L-alt | platform-tagged impl files |
| Doc comments `///` | U | |

## Modules / namespacing

| Feature | Status | Notes |
|---|---|---|
| Directory = module | L | |
| `imports` per-directory file | L | |
| Inline `mod` blocks | OUT-in-source | |
| `pub use` re-exports | OUT | |

## FFI

| Feature | Status | Notes |
|---|---|---|
| `extern "Rust"` / `"C"` / … | L-alt | `.rfi` surface |

## Testing / benchmarking

| Feature | Status | Notes |
|---|---|---|
| `#[cfg(test)]` | L-alt | `.test-impl` surface |
| `#[bench]` | L-alt | `.bench-impl` surface |
| Test harness | U | build-time wiring |
