;; Aski Paradigm — types all the way down
;; Date: 2026-04-20
;;
;; This document is the ground truth for how to frame aski's
;; relationship to Rust. If another bridge doc claims something
;; inconsistent with this, that other doc is wrong.

# The claim

Aski aims to support **all of Rust**, expressed through a stricter
paradigm: **types all the way down, trait-methods as the only form
of behavior.**

Aski is not a restricted Rust. It is a more-principled cousin that
happens to compile to Rust today (bootstrap runtime) and will
outgrow Rust semantically as it matures. Rust is the rocket we're
riding off the launchpad. Aski is the ship.

# How aski re-reads Rust's constructs

Rust has features that aski's paradigm considers **under-specified**:

| Rust construct | Aski's reading |
|----------------|----------------|
| Named variable `let x = 5` | Local type declaration — creates a local type whose singleton instance is named `x`. The relationship between `x` and its type is explicit. |
| Free function `fn foo(…) { … }` | Trait method — every callable belongs to a trait that describes its capability, on a type that carries it. |
| Tuple `(A, B)` | Struct — positional nameless grouping is under-specified; aski requires the roles to be named. |
| Type alias `type X = Y` | Newtype — aliases weaken type identity; aski preserves identity strictly. |
| Anonymous closure `|x| body` | Named type impl of a Callable trait (or TBD — see bridge/big-decisions.md §S4). |
| Inherent impl `impl Foo { fn bar }` | Trait impl — every method belongs to a named trait. (Spec status: grammar currently lacks inherent impl; design.md doesn't explicitly reject it. See §C8 in bridge docs.) |

These are aski's **paradigm commitments**. Rust code written in these
forms maps to aski by making the implicit type structure explicit.

# What the spec actually settles

design.md explicitly rejects, in prose:

1. **Tuples** — §No Tuples. Use structs with named fields.
2. **Free functions** — §No Free Functions (with `main` exception).
3. **Native infinite-loop form** — §No Native Infinite-Loop Form.
   Use `while true`.
4. **Higher-kinded types** — §Generics ("No higher-kinded types").
5. **Dependent types** — §Generics ("No dependent types (yet)").
6. **Keywords in source** — §Delimiter-First ("There are no keywords").
7. **Re-shadowing the same name in one scope** — §Scopes Are a Tree.

Everything else is either **spec'd and present** in the grammar, or
**spec-silent** — the spec neither requires nor forbids it.

# Spec status levels

When discussing any Rust feature or aski construct, use one of four
statuses:

| Status | Meaning |
|--------|---------|
| **Landed** | Present in the current grammar (`.synth`), aski-core `.core`, and spec (`syntax-v020.aski`). Parses and produces typed output today. |
| **Proposed** | Exists only in bridge proposals. Not parseable by askicc yet. Do not assume behavior. |
| **Unspec'd** | Neither landed nor explicitly rejected. The spec is silent. **Agents must not assume aski does or doesn't support it.** |
| **Confirmed OUT** | design.md explicitly rejects, with citation to a prose §section. |

If you catch yourself writing "aski handles X" or "aski doesn't
support X," check which of these four applies. Most uses belong to
Proposed or Unspec'd, not Landed or Confirmed-OUT.

# Rust feature audit (as of 2026-04-20)

Legend: **L** Landed · **P** Proposed (with bridge-doc ref) · **U** Unspec'd · **OUT** Confirmed OUT with citation.

## Primitives

| Feature | Status | Notes |
|---------|--------|-------|
| U8–U64, I8–I64, F32, F64, Bool, String, Char | L | `Primitive::all()` in aski-core/src/lib.rs |
| Vec, Option, Box, Result | L | Primitive constructors with arity 1 / 2 |
| U128, I128 | U | Not in primitive list |
| Usize, Isize | U | Not in primitive list |
| str (borrowed string slice) | U | Aski has String as primitive; no &str distinction spec'd |
| Unit / `()` | U | LiteralValue has Unit variant in aski-core, but no source literal form |
| Never / `!` | P | bridge/clear.md §N2 — add as zero-arity primitive |
| Rc, Arc | U | Not in primitive list |
| Cell, RefCell, Mutex, RwLock | U | Not spec'd |
| HashMap, BTreeMap, HashSet, etc. | U | Not in primitive list |

## Compound types

| Feature | Status | Notes |
|---------|--------|-------|
| Struct (named fields) | L | `{Name (@Field Type)…}` |
| Struct (self-typed fields) | L | `{Name @FieldAsType…}` |
| Enum (bare, data, struct variants) | L | `(Name Var1 (Var2 T) {Var3 (@F T)})` |
| Newtype | L | `(\| Name WrappedType \|)` |
| Nested enum / nested struct | L | `(\| \|)` / `{\| \|}` within enum or struct body |
| Tuple | OUT | §No Tuples |
| Array `[T; N]` | P | bridge/clear.md §S11 — add `Array` primitive |
| Slice `[T]` | U | Not spec'd |
| Union | U | Not spec'd |

## References & pointers

| Feature | Status | Notes |
|---------|--------|-------|
| `&T` shared borrow | L | `&name Type` in params / types |
| `&mut T` mutable borrow | L | `~&name Type` |
| Place-based origins `'Place` | L | PlaceRef / PlacePath / PlaceUnion |
| View types `{\| fields \|}` | L | Partial-field borrows |
| `*const T`, `*mut T` raw pointer | U | Not in grammar; not explicitly rejected either |

## Callable types

| Feature | Status | Notes |
|---------|--------|-------|
| fn pointer `fn(A) -> B` | U | Not spec'd |
| Fn / FnMut / FnOnce traits | U | Not in stdlib spec |
| Closure literal `\|x\| body` | P/U | bridge/big-decisions.md §S4 — open design |

## Type system

| Feature | Status | Notes |
|---------|--------|-------|
| Generic type params `{$Value}` | L | |
| Trait bounds `$Value{Clone Debug}` | L | |
| Super-traits | L | Combined slot on TraitDecl |
| Associated types | L | Bare Pascal in TraitItem |
| Associated type impls | L | `(Item Type)` in TraitImplItem |
| Associated consts | P | bridge/clear.md §S9 |
| Method-level generics | L | `?{ +<GenericParam> }` in Signature |
| Where clauses | U | Not in grammar |
| GATs | U | Not in grammar |
| Lifetime generic parameters `<'a>` | OUT-ish | Replaced by place-based origins (different model) |
| `'static` | P | bridge/clear.md §N1 — conventional PlaceName |
| HRTB `for<'a>` | U | Not spec'd |
| const generics | U | Not spec'd |
| `impl Trait` (input / output) | U | Not spec'd |
| `dyn Trait` | P | bridge/small-decisions.md §S6 syntax + big-decisions.md §S6 semantics |
| PhantomData | U | Not spec'd |
| Never `!` as type | P | bridge/clear.md §N2 |
| Higher-kinded types | OUT | §Generics |
| Dependent types | OUT | §Generics |

## Control flow

| Feature | Status | Notes |
|---------|--------|-------|
| `match` | L | |
| `if` / `else` | L-idiom | Via match on Bool variants |
| `if let` / `while let` | P | bridge/clear.md §C4 — via match with `_` wildcard |
| `while` | L | `[\| cond body \|]` |
| `for` | L | Iteration `{\| src.binding body \|}` |
| `loop` (infinite) | L-idiom | `while true` pattern |
| `break` / `continue` / labels | P | bridge/small-decisions.md §S3 (sigil spelling open) |
| `return` / `?` | L | EarlyReturn / TryUnwrap |
| `async` / `await` | U | Not spec'd |

## Expressions

| Feature | Status | Notes |
|---------|--------|-------|
| `+` `-` `*` `%` | L | BinAdd / BinSub / BinMul / BinMod |
| `/` division | P | bridge/clear.md §C5 |
| `==` `!=` `<` `>` `<=` `>=` | L | |
| `&&` `\|\|` | L | |
| Bitwise (`&` `\|` `^` `<<` `>>`) | P | bridge/clear.md §S5 — stdlib methods |
| Unary `-` `!` | P | bridge/clear.md §C6 |
| Unary `*` (deref) | U | Open question — see mutation-side vs read-side analysis |
| Assignment `=` | U | Aski has no `=`; mutation via `~place.method(…)` statement |
| Compound assignment `+=` | U | Same — not a bare operator in aski |
| Method call `.method(…)` | L | |
| Field access `.Field` | L | |
| Cast `as` | P | bridge/clear.md §S7 — stdlib From/Into |
| Range `..` `..=` | P | bridge/clear.md §S2 |
| Array literal `[x; n]` | U | Aski has no array literal form |
| Tuple literal `(a, b)` | OUT | §No Tuples |
| Struct literal `{ f: v }` | L | StructConstruct |
| Block `{ … }` as expression | L | InlineEval `[body]` |
| Closure literal | P/U | §S4 open |
| Macro invocation `foo!()` | U | Not spec'd |

## Patterns

| Feature | Status | Notes |
|---------|--------|-------|
| Wildcard `_` | L | Landed 2026-04-19 |
| Variant match `Variant` | L | VariantMatch |
| Variant bind `Variant name` | L | VariantBind |
| Or-pattern `[A B]` (variants only) | L | VariantAlt |
| String literal `"…"` | L | StringMatch |
| Literal pattern (int/float/char) | P | bridge/clear.md §C3 — also subsumes StringMatch |
| Struct destructure `{ Field binding }` | P | bridge/big-decisions.md §C2 — binding rule open |
| Tuple destructure | OUT | §No Tuples |
| Reference pattern `&x` | U | Not spec'd |
| Binding `name @ pattern` | U | Not spec'd (and `@` is visibility now) |
| Range pattern `0..=9` | U | Not spec'd |
| Guard `(if cond)` | U | Acknowledged gap in RESTART-CONTEXT §13 |
| Rest `..` | U | Not spec'd |
| General or-pattern `A \| B` (non-variant) | U | Not spec'd |

## Items

| Feature | Status | Notes |
|---------|--------|-------|
| Struct, Enum, Newtype, Const, TraitDecl, TraitImpl | L | |
| Module header with imports | L | |
| Free function `fn foo()` | OUT | §No Free Functions |
| Inherent impl `impl Foo { fn bar }` | U | Grammar has no form; design.md is silent |
| Type alias `type X = Y` | U | Grammar has no form; design.md is silent (user preference: OUT per 2026-04-19) |
| Static item | U | Not spec'd |
| Submodule `mod` | U | File = module currently |
| macro_rules | U | Not spec'd |
| Proc macros | U | Sema pipeline may replace, but not spec'd |
| `extern` block | L-alt | Handled by RFI surface |

## Visibility

| Feature | Status | Notes |
|---------|--------|-------|
| `pub` / public | L | `@` prefix |
| default private | L | No prefix |
| `pub(crate)` / `pub(super)` / `pub(in …)` | P | bridge/clear.md §N4 — `@(Place)` form proposed, deferred |

## Safety

| Feature | Status | Notes |
|---------|--------|-------|
| `unsafe` | U | Not spec'd |
| `transmute` | U | Not spec'd |
| Raw pointer deref | U | No raw pointers spec'd |

## Error handling

| Feature | Status | Notes |
|---------|--------|-------|
| `Result<T, E>` | L | Primitive |
| `Option<T>` | L | Primitive |
| `?` try-unwrap | L | TryUnwrap in ExprPostfix |
| `panic!` | U | No panic function or marker in spec |
| `Error` trait | U | No stdlib spec |

## Strings & literals

| Feature | Status | Notes |
|---------|--------|-------|
| String literal `"…"` | L | |
| Escape sequences inside string | U | Not fully spec'd beyond what the lexer tokenizes |
| Raw string `r"…"` | P | bridge/clear.md §N8 — triple-quote form proposed |
| Byte string `b"…"` | U | Not spec'd |
| Char literal | P | bridge/small-decisions.md — backtick form proposed |
| Byte literal `b'x'` | U | Not spec'd |
| Int literal (decimal) | L | |
| Int literal hex/oct/bin | P | bridge/clear.md §N8 |
| Numeric separators `1_000_000` | P | §N8 |
| Typed integer suffix `42u32` | P | §N8 |
| Float literal | L | |
| Bool literal `true` / `false` | U | No camelCase-keyword form — must use `True` / `False` variants of a Bool enum |

## Traits (stdlib)

| Feature | Status | Notes |
|---------|--------|-------|
| Clone, Copy, Debug, Display, PartialEq, Eq, Hash, PartialOrd, Ord, Default | U | No stdlib spec yet |
| From, Into, TryFrom, TryInto | P | bridge/clear.md §S7 |
| AsRef, Borrow, Deref | U | Not spec'd |
| Iterator (trait) | U | Iteration syntax exists, but trait itself not spec'd |
| Fn / FnMut / FnOnce | U | §S4 open |
| Index / IndexMut | U | Not spec'd |
| Arithmetic operator traits (Add, Sub, Mul, Div, Rem) | U | Operators work on primitives; trait-level not spec'd |
| BitAnd / BitOr / Shl / Shr | P | bridge/clear.md §S5 |
| Neg, Not | P | bridge/clear.md §C6 |
| Send, Sync | U | Not spec'd |
| Drop | U | Not spec'd |

## Concurrency

All U. Nothing spec'd.

## Attributes

| Feature | Status | Notes |
|---------|--------|-------|
| `#[derive(…)]` | U | Not spec'd; sema pipeline *may* replace, unclear |
| `#[cfg(…)]` | U | Not spec'd; criome world-model *may* replace, unclear |
| Doc comments `///` | P | bridge/clear.md §N7 — `;;;` form proposed |

# How to talk about aski going forward

When writing docs, bridge proposals, or replies to the user:

- **Landed**: "aski parses X" / "Pattern.synth produces X" — grounded claim.
- **Proposed**: "bridge proposes X at §Ref" — tentative, not live.
- **Unspec'd**: "spec is silent on X" / "X is not addressed" — honest about the hole.
- **Confirmed OUT**: "aski rejects X per design.md §Section" — spec-grounded rejection.

Do not say "aski handles X" unless there's a grammar citation.
Do not say "aski doesn't support X" unless design.md rejects it
in prose. Grammar absence alone is not rejection — just a spec
hole waiting to be filled.

# Relationship to the bridge docs

This paradigm doc is the ground truth. If other bridge docs make
claims inconsistent with the status levels here, they are wrong.
Corrections underway.
