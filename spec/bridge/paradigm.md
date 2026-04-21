# Aski Paradigm — types all the way down

*2026-04-20; audit updated 2026-04-21 for v0.21*

This document is the ground truth for how to frame aski's relationship
to Rust. If another bridge doc claims something inconsistent with
this, that other doc is wrong.

v0.21 (Identity-is-Location) ships a filesystem-encoded identity
model: per-kind extensions (`.enum` / `.struct` / `.trait` /
`.impl` / …), one public object per file, `_` prefix for private,
directory = module. See [../syntax-v021.md](../syntax-v021.md).
Under II-L the outer object delimiters, module headers, and the
root-level `@` visibility sigil move out of source — reducing the
in-source audit surface.

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
3. **Keywords in source** — §Delimiter-First ("There are no keywords").
4. **Re-shadowing the same name in one scope** — §Scopes Are a Tree.

Under v0.21, the filesystem encodes identity (II-L):
filename = object name; extension = kind; `_` prefix = private;
directory = module; per-directory `imports` file. Several
questions the v0.20 spec reasoned about in-source (module
header, root-level `@` sigil, outer object delimiters) no longer
apply — the filesystem walk handles them. This narrows the audit
surface for "what aski in-source does or doesn't support" to
body grammar only.

Previous drafts of this list also included native-infinite-loop,
higher-kinded types, and dependent types. Those were Claude-
authored, not confirmed by Li. They're tracked as open questions —
see gap-analysis.md §U19 (infinite loop), §U20 (HKT), §U21
(dependent types).

Everything else is either **spec'd and present** in the grammar, or
**spec-silent** — the spec neither requires nor forbids it.

# Spec status levels

When discussing any Rust feature or aski construct, use one of four
statuses:

| Status | Meaning |
|--------|---------|
| **Landed** | Present in the current grammar (`.synth`), aski-core `.core`, and spec (`syntax-v021.md` for current; `syntax-v020.aski` as historical). Parses and produces typed output today. |
| **Proposed** | Exists only in bridge proposals. Not parseable by askicc yet. Do not assume behavior. |
| **Unspec'd** | Neither landed nor explicitly rejected. The spec is silent. **Agents must not assume aski does or doesn't support it.** |
| **Confirmed OUT** | design.md explicitly rejects, with citation to a prose §section. |

If you catch yourself writing "aski handles X" or "aski doesn't
support X," check which of these four applies. Most uses belong to
Proposed or Unspec'd, not Landed or Confirmed-OUT.

# Rust feature audit (as of 2026-04-21 — post v0.21)

Legend: **L** Landed · **P** Proposed (with bridge-doc ref) · **U** Unspec'd · **OUT** Confirmed OUT with citation. Items marked "L (v0.21)" merged into the v0.21 syntax spec on 2026-04-21.

## Primitives

| Feature | Status | Notes |
|---------|--------|-------|
| U8–U64, I8–I64, F32, F64, Bool, String, Char | L | `Primitive::all()` in aski-core/src/lib.rs |
| Vec, Option, Box, Result | L | Primitive constructors with arity 1 / 2 |
| U128, I128 | U | Not in primitive list |
| Usize, Isize | U | Not in primitive list |
| str (borrowed string slice) | U | Aski has String as primitive; no &str distinction spec'd |
| Unit / `()` | U | LiteralValue has Unit variant in aski-core, but no source literal form |
| Never / `!` | L (v0.21) | §N2 merged — Never primitive; see ../syntax-v021/11-stdlib-primitives.md |
| Rc, Arc | U | Not in primitive list |
| Cell, RefCell, Mutex, RwLock | U | Not spec'd |
| HashMap, BTreeMap, HashSet, etc. | U | Not in primitive list |

## Compound types

| Feature | Status | Notes |
|---------|--------|-------|
| Struct (named fields) | L | `{Name (@Field Type)…}` |
| Struct (self-typed fields) | L | `{Name @FieldAsType…}` |
| Enum (bare, data, struct variants) | L | `(Name Var1 (Var2 Type) {Var3 (Field Type)})` |
| Newtype | L | `(\| Name WrappedType \|)` |
| Nested enum / nested struct | L | `(\| \|)` / `{\| \|}` within enum or struct body |
| Tuple | OUT | §No Tuples |
| Array `[T; N]` | L (v0.21) | §S11 merged — `{Array T N}` integer-const; see ../syntax-v021/02-structs.md, array-literal expression still open (outliers §U4) |
| Slice `[T]` | U | Not spec'd |
| Union | U | Not spec'd |

## References & pointers

| Feature | Status | Notes |
|---------|--------|-------|
| `&T` shared borrow | L | `&name Type` in params / types; C7 merged in v0.21 — borrow now accepts path expressions like `&self.Field` |
| `&mut T` mutable borrow | L | `~&name Type`; C7 merged — `~&self.Field` borrow of path |
| Place-based origins `'Place` | L | PlaceRef / PlacePath / PlaceUnion |
| View types `{\| fields \|}` | L | Partial-field borrows |
| `*const T`, `*mut T` raw pointer | U | Not in grammar; not explicitly rejected either |

## Callable types

| Feature | Status | Notes |
|---------|--------|-------|
| fn pointer `fn(A) -> B` | U | Not spec'd |
| Fn / FnMut / FnOnce traits | U | Not in stdlib spec |
| Closure literal `\|x\| body` | L (v0.21, Position A) | §S4-A merged — named-type Callable impls; B/C remain open (outliers §U12) |

## Type system

| Feature | Status | Notes |
|---------|--------|-------|
| Generic type params `{$Value}` | L | |
| Trait bounds `$Value{Clone Debug}` | L | |
| Super-traits | L | Combined slot on TraitDecl |
| Associated types | L | Bare Pascal in TraitItem |
| Associated type impls | L | `(Item Type)` in TraitImplItem |
| Associated consts | L (v0.21) | §S9 merged — see ../syntax-v021/04-traits.md |
| Method-level generics | L | `?{ +<GenericParam> }` in Signature |
| Where clauses | U | Not in grammar |
| GATs | U | Not in grammar |
| Lifetime generic parameters `<'a>` | OUT-ish | Replaced by place-based origins (different model) |
| `'static` | L (v0.21) | §N1 merged — `'Static` PlaceName; see ../syntax-v021/11-stdlib-primitives.md |
| HRTB `for<'a>` | U | Not spec'd |
| const generics | U | Not spec'd |
| `impl Trait` (input / output) | U | Not spec'd |
| `dyn Trait` | P | bridge/small-decisions.md §S6 syntax + big-decisions.md §S6 semantics |
| PhantomData | U | Not spec'd |
| Never `!` as type | L (v0.21) | §N2 merged — see ../syntax-v021/11-stdlib-primitives.md |
| Higher-kinded types | U | Open — gap-analysis.md §U20 |
| Dependent types | U | Open — gap-analysis.md §U21 |

## Control flow

| Feature | Status | Notes |
|---------|--------|-------|
| `match` | L | |
| `if` / `else` | L-idiom | Via match on Bool variants |
| `if let` / `while let` | L (v0.21) | §C4 merged — via match idiom; see ../syntax-v021/09-control-flow.md |
| `while` | L | `[\| cond body \|]` |
| `for` | L | Iteration `{\| src.binding body \|}` |
| `loop` (infinite) | U | `while true` works today; dedicated form open — gap-analysis.md §U19 |
| `break` / `continue` / labels | P | bridge/small-decisions.md §S3 (sigil spelling open) |
| `return` / `?` | L | EarlyReturn / TryUnwrap |
| `async` / `await` | U | Not spec'd |

## Expressions

| Feature | Status | Notes |
|---------|--------|-------|
| `+` `-` `*` `%` | L | BinAdd / BinSub / BinMul / BinMod |
| `/` division | L (v0.21) | §C5 merged — see ../syntax-v021/12-expressions.md |
| `==` `!=` `<` `>` `<=` `>=` | L | |
| `&&` `\|\|` | L | |
| Bitwise (`&` `\|` `^` `<<` `>>`) | L (v0.21) | §S5 merged — stdlib methods; see ../syntax-v021/12-expressions.md |
| Unary `-` `!` | L (v0.21) | §C6 merged — see ../syntax-v021/12-expressions.md |
| Unary `*` (deref) | L (v0.21) | §U1 merged — stdlib `Deref` method; see ../syntax-v021/12-expressions.md |
| Assignment `=` | U | Aski has no `=`; mutation via `~place.method(…)` (N3 merged method-only direction; bare `=` still open — outliers §U7) |
| Compound assignment `+=` | U | Same — not a bare operator in aski (outliers §U7) |
| Method call `.method(…)` | L | |
| Field access `.Field` | L | |
| Cast `as` | L (v0.21) | §S7 merged — stdlib From/Into; see ../syntax-v021/10-self-mutation-cast-path.md; narrowing form still open (outliers §U6) |
| Range `..` `..=` | L (v0.21) | §S2 merged — see ../syntax-v021/09-control-flow.md + 12-expressions.md |
| Array literal `[x; n]` | U | Aski has no array literal form |
| Tuple literal `(a, b)` | OUT | §No Tuples |
| Struct literal `{ f: v }` | L | StructConstruct |
| Block `{ … }` as expression | L | InlineEval `[body]` |
| Closure literal | L (v0.21, Position A) | §S4-A merged as named-type Callable impls; B/C remain open (outliers §U12) |
| Macro invocation `foo!()` | U | Not spec'd |

## Patterns

| Feature | Status | Notes |
|---------|--------|-------|
| Wildcard `_` | L | Landed 2026-04-19 |
| Variant match `Variant` | L | VariantMatch |
| Variant bind `Variant name` | L | VariantBind |
| Or-pattern `[A B]` (variants only) | L | VariantAlt |
| String literal `"…"` | L | StringMatch |
| Literal pattern (int/float/char) | L (v0.21) | §C3 merged — scope for Int/Float/Str; Bool/Char excluded (outliers §U3 for Bool) |
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
| Module header with imports | L (v0.21 — filesystem) | Directory = module; per-directory `imports` file lists visible names; see ../syntax-v021/07-modules-visibility.md |
| Free function `fn foo()` | OUT | §No Free Functions |
| Inherent impl `impl Foo { fn bar }` | U | Grammar has no form; design.md is silent |
| Type alias `type X = Y` | U | Grammar has no form; design.md is silent (user preference: OUT per 2026-04-19) |
| Static item | U | Not spec'd |
| Submodule `mod` | L (v0.21) | Directory = module under II-L; nested directories = nested modules; see ../syntax-v021/07-modules-visibility.md |
| macro_rules | U | Not spec'd |
| Proc macros | U | Sema pipeline may replace, but not spec'd |
| `extern` block | L-alt | Handled by RFI surface |

## Visibility

| Feature | Status | Notes |
|---------|--------|-------|
| `pub` / public | L (v0.21) | Filename without `_` prefix; field-level `@` still in struct bodies; see ../syntax-v021/07-modules-visibility.md |
| default private | L (v0.21) | `_` filename prefix under II-L; body-private fields bare Pascal |
| `pub(crate)` / `pub(super)` / `pub(in …)` | U | No II-L encoding yet — see outliers-v021.md §U10 / §N4 |

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
| Raw string `r"…"` | L (v0.21) | §N8 merged — triple-quote form; see ../syntax-v021/08-body-basics.md |
| Byte string `b"…"` | U | Not spec'd |
| Char literal | L (v0.21, via §U16) | No char literal syntax — Char is a library-of-types enum (`Char:Upper:A`); see ../syntax-v021/11-stdlib-primitives.md |
| Byte literal `b'x'` | U | Not spec'd |
| Int literal (decimal) | L | |
| Int literal hex/oct/bin | L (v0.21) | §N8 merged — see ../syntax-v021/08-body-basics.md |
| Numeric separators `1_000_000` | L (v0.21) | §N8 merged |
| Typed integer suffix `42u32` | L (v0.21) | §N8 merged |
| Float literal | L | |
| Bool literal `true` / `false` | U | No literal form today. Open — see bridge/clear.md §C3/§C4 and gap-analysis.md §U2/§U3. |

## Traits (stdlib)

| Feature | Status | Notes |
|---------|--------|-------|
| Clone, Copy, Debug, Display, PartialEq, Eq, Hash, PartialOrd, Ord, Default | U | No stdlib spec yet |
| From, Into, TryFrom, TryInto | L (v0.21) | §S7 merged — stdlib cast path; see ../syntax-v021/10-self-mutation-cast-path.md |
| AsRef, Borrow, Deref | U | Not spec'd |
| Iterator (trait) | U | Iteration syntax exists, but trait itself not spec'd |
| Fn / FnMut / FnOnce | U | §S4 open |
| Index / IndexMut | U | Not spec'd |
| Arithmetic operator traits (Add, Sub, Mul, Div, Rem) | U | Operators work on primitives; trait-level not spec'd |
| BitAnd / BitOr / Shl / Shr | L (v0.21) | §S5 merged — stdlib bit-op methods |
| Neg, Not | L (v0.21) | §C6 merged — unary `-` / `!` grammar + stdlib |
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
