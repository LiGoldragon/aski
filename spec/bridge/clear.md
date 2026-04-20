;; Bridge Proposals — Shapes Sketched, Decisions Still Yours
;; Date: 2026-04-20
;; Part of [../bridge-proposals.md](../bridge-proposals.md).
;;
;; ⚠️ REFRAMING NOTE. An earlier draft of this file presented items
;; as "clearly resolvable" with author-written recommendations. Per
;; [paradigm.md](paradigm.md)'s rule ("do not say aski handles X
;; unless there's a grammar citation; do not say aski doesn't support
;; X unless design.md rejects it in prose"), those recommendations
;; were out of scope — aski's syntax is being designed, not documented.
;; This pass strips the author-made calls and restores each item to
;; an open proposal. Li decides which shape lands; alternatives stay
;; listed where they were ruled out prematurely.

# Contents

1. [Already landed](#already-landed) — C1
2. [Proposed shapes awaiting approval](#proposed-shapes-awaiting-approval) — C3, C4, C5, C6, C7, N2, N7, N8, S2, S5, S7, S8, S9, S11, N3, S4 (one alternative shown)
3. [Works with no grammar change](#works-with-no-grammar-change) — N1, N9
4. [Proposed OUT — design.md doesn't yet reject these](#proposed-out--designmd-doesnt-yet-reject-these) — C8, S1, S12, N4, N6

---

## Already landed

### C1. Wildcard pattern `_` — landed 2026-04-19

```rust
match status {
    Status::Ready => self.run(),
    Status::Error(code) => self.log(code),
    _ => self.default(),
}
```

```aski
(| status
  ( Ready )       self.run
  ( Error code )  self.log(code)
  ( _ )           self.default
|)
```

```synth
;; Pattern.synth (current)
// #WildcardPattern#_
// #VariantBind#:Variant @binding
// #VariantAlt#[ +:Variant ]
// #VariantMatch#:Variant
// #StringMatch#"literal"
```

Also in `synth-core` (`TagKind::WildcardPattern`, `LiteralToken::Underscore`),
`askicc/src/synth_lex.rs` (bare-`_` path), `aski-core/core/pattern.core`
(`Pattern::Wildcard`), and `syntax-v020.aski` (Route/dispatch example).

---

## Proposed shapes awaiting approval

*Each item below proposes a grammar shape. Until Li confirms, nothing
below is settled. "Open question" markers inside each item flag the
specific calls that were previously baked in as prose.*

### C5. Division `/` — ACCEPTED 2026-04-20

```rust
let mean = total / count;
let remainder = total % count;
```

```aski
(mean total / count)
(remainder total % count)
```

```synth
;; ExprMul.synth — add BinDiv alt
// <ExprPostfix> #BinDiv#_/_ <ExprMul>
// <ExprPostfix> #BinMul#_*_ <ExprMul>
// <ExprPostfix> #BinMod#% <ExprMul>
// <ExprPostfix>
```

Adds `TagKind::BinDiv`, `Expr::BinDiv { Left, Right }`. Lexer already emits
`/` as `LiteralToken::Slash`.

---

### C6. Unary operators `-` / `!` — ACCEPTED 2026-04-20 (deref still open below)

```rust
let neg = -x;
let stopped = !self.running;
let failed = !result.is_ok();
```

```aski
(neg -x)
(stopped !self.Running)
(failed !result.isOk)
```

```synth
;; ExprUnary.synth — new dialect between ExprMul and ExprPostfix
// #UnaryNeg#_-_ <ExprUnary>
// #UnaryNot#_!_ <ExprUnary>
// <ExprPostfix>

;; ExprMul.synth — chain descends into ExprUnary
// <ExprUnary> #BinMul#_*_ <ExprMul>
// <ExprUnary> #BinDiv#_/_ <ExprMul>
// <ExprUnary> #BinMod#% <ExprMul>
// <ExprUnary>
```

Adds `TagKind::UnaryNeg`, `UnaryNot` and corresponding Expr variants.
Adjacency handles `- 1` (unary) vs `a - b` (binary).

**Open question — deref `*x`:** an earlier draft said "skipped — aski has
no raw pointers." That conflates two unrelated questions. Raw pointers
(`*const T` / `*mut T`) are Unspec'd per [paradigm.md](paradigm.md) —
not rejected. Deref could still be meaningful for smart-pointer types
(Box, Rc, etc., via a stdlib Deref trait) even if raw pointers never
land. Decide: (a) no unary `*` at all; (b) unary `*` dispatches to a
stdlib `Deref` trait; (c) defer until raw-pointer question is decided.

---

### C7. Borrow of path expression

```rust
fn describe(&self) -> String {
    summarize(&self.header, &self.body.inner)
}

fn mutate(&mut self) {
    commit(&mut self.buffer);
}
```

```aski
(describe &self String [
  self.summarize(&self.Header &self.Body.Inner)
])

(mutate ~&self [
  self.commit(~&self.Buffer)
])
```

```synth
;; PlaceExpr.synth — new dialect
// <PlaceAtom> *#PlaceField#.:FieldName

;; PlaceAtom.synth — new dialect
// #SelfPlace#self
// #InstancePlace#:instance

;; ExprAtom.synth — BorrowExpr now takes a PlaceExpr, not a bare instance
// #BorrowExpr#_&_?<Origin>?<ViewType><PlaceExpr>
// #MutBorrowExpr#_~__&_?<Origin>?<ViewType><PlaceExpr>
```

Aski-core restructures `BorrowExpr`/`MutBorrowExpr` to hold a `PlaceExpr`
instead of a bare `InstanceName`. **Proposed scope**: method calls are
NOT place expressions — `&foo.method()` is not borrowable. Matches
Rust's rule; to be confirmed before landing.

---

### C3. LiteralPattern

Folds `StringMatch` into a single LiteralPattern covering Int, Float,
String, Char — at minimum.

**Open question — Bool in LiteralPattern:** an earlier draft called Bool
"OUT" on the grounds that `true` / `false` as lowercase tokens would
read as instances of nonexistent types `True` / `False` under the case
rule. That's a real tension but not a decision. Options: (a) Bool is
not a LiteralPattern type; matching uses `( True )` / `( False )` variant
patterns on a Bool enum; (b) `true` / `false` are carved out as special
literal tokens (breaks the case rule's symmetry); (c) Bool isn't a
variant enum at the source level — it's a true primitive with its own
literal form. Related to C4's retraction question and the bare `true`
/ `false` literal-token question in N8.

```rust
fn status_name(code: u32) -> &'static str {
    match code {
        0   => "pending",
        200 => "ok",
        404 => "not found",
        _   => "other",
    }
}
```

```aski
(statusName &code U32 &'Static String (| code
  ( 0 )    "pending"
  ( 200 )  "ok"
  ( 404 )  "not found"
  ( _ )    "other"
|))
```

```synth
;; Pattern.synth — add LiteralPattern, remove StringMatch (subsumed)
// #WildcardPattern#_
// #VariantBind#:Variant @binding
// #VariantAlt#[ +:Variant ]
// #VariantMatch#:Variant
// #LiteralPattern#:Literal    ;; covers Int, Float, Str, Char
```

`Pattern::LiteralPattern(LiteralValue)` in aski-core; drop `StringMatch`.

---

### C4. if / if-let / while-let

**Open question — Bool representation:** an earlier draft retracted the
`true` / `false` literal-token carve-out on the grounds that lowercase
tokens would violate the case rule. That's a coherent argument but not
a settled call. The form shown below assumes Bool-is-a-variant-enum;
if Bool becomes a primitive with literal tokens instead (C3 alt-c),
this section's idiom changes. Decide in C3 first, then revisit here.

The form assuming Bool-as-variant-enum:

```rust
if self.ready {
    self.run()
} else {
    self.wait()
}

if let Some(value) = self.result {
    self.use_value(value);
}
```

```aski
(| self.ready
  ( True )   self.run
  ( False )  self.wait
|)

(| self.result
  ( Some value ) [self.useValue(value)]
  ( _ )          Unit
|)
```

Under the Bool-as-variant-enum answer, no grammar change — documentation
only; `syntax-v020.aski` gains an explicit if/else example. Under any
other answer, this section is revisited.

---

### N2. Never primitive

```rust
fn panic(msg: &str) -> ! { … }
fn run_forever(&mut self) -> ! { loop { self.tick() } }
```

```aski
(panic &msg String Never)
(runForever ~&self Never [| true [self.tick] |])
```

Zero grammar change. Add `("Never", 0)` to `Primitive::all()` in
`aski-core/src/lib.rs`. Sema representation not yet designed; one
plausible shape is a zero-variant enum (mirrors Rust's `!`), but
that's proposed, not spec'd. rsc doesn't exist yet — when it does,
it'll map Never to whatever Rust form is current.

---

### N7. Doc comments — SHELVED 2026-04-20

Moved to [../shelved.md](../shelved.md#u8-doc-comment-sigil). Not
blocking any in-flight decision; revisit when rsc / askid lands.

The earlier draft proposed the shape below. Kept here for reference
only — not live.

```rust
/// A bounded FIFO queue.
/// Pushes beyond capacity overwrite.
struct RingBuffer<T> {
    /// Where the next push lands.
    head: usize,
}
```

```aski
;;; A bounded FIFO queue.
;;; Pushes beyond capacity overwrite.
@{RingBuffer {$Value}
  ;;; Where the next push lands.
  (@Head U32)}
```

Lexer change: at line start, `;;;` reads to newline as a `DocComment(String)`
token. Aski-core adds `(Doc [Option String])` to Enum, Struct, Newtype,
Const, TraitDecl, Method. rsc emits `/// …` in Rust projection.

---

### N8. Literal lexer extensions (narrowed — no Bool literal)

**Retraction:** the original proposal included `true`/`false` as Bool
literals. Dropped per C4's retraction. All other items stand.

```rust
const MASK: u32 = 0xFF_FF_FF_00;
const FLAG: u8 = 0b0010_1100;
const PERM: u32 = 0o755;
const POP: u64 = 7_900_000_000;

let escape = '\n';
let path = r"C:\Users\li\projects";
let block = """
    Line one.
    Line two.
""";
```

```aski
@{| Mask   U32 0xFF_FF_FF_00 |}
@{| Flag   U8  0b0010_1100   |}
@{| Perm   U32 0o755         |}
@{| Pop    U64 7_900_000_000 |}

(escape `\n`)
(path """C:\Users\li\projects""")
(block """
    Line one.
    Line two.
""")
```

Zero grammar change. Lexer only. Char literal syntax (backtick) is a
small decision — see `small-decisions.md`.

---

### S2. Range expressions

```rust
for i in 0..10 { println!("{}", i); }
for j in 0..=max { self.process(j); }
```

```aski
{| 0..10.i      [StdOut:print(i)]  |}
{| 0..=max.j    [self.process(j)]  |}
```

```synth
;; ExprRange.synth — new dialect between ExprCompare and ExprAnd
// <ExprCompare> #Range#_.._ <ExprCompare>
// <ExprCompare> #RangeIncl#_.._=_ <ExprCompare>
// <ExprCompare>

;; ExprAnd.synth — chain descends into ExprRange
// <ExprRange> #BinAnd#&& <ExprAnd>
// <ExprRange>
```

Lexer adds `..` and `..=` as multi-char operators. Aski-core adds
`Expr::Range { Start, End }` and `Expr::RangeIncl { Start, End }`.

---

### S8. Const expressions

```rust
const MAX_USERS: u32 = 100;
const MAX_SESSIONS: u32 = MAX_USERS * 4;
const BUFFER_SIZE: u32 = MAX_USERS + MAX_SESSIONS + 1;
```

```aski
@{| MaxUsers    U32 100 |}
@{| MaxSessions U32 MaxUsers * 4 |}
@{| BufferSize  U32 MaxUsers + MaxSessions + 1 |}
```

```synth
;; Root.synth — Const's RHS becomes <Expr>, was @Literal
// *?_@_#Const#{| @ConstName <Type> <Expr> |}
```

Aski-core: `Const.Value: Expr` (was `LiteralValue`). Veric does const-eval.

---

### S9. Associated constants

```rust
trait BoundedQueue {
    type Item;
    const CAPACITY: u32;
    const DEFAULT_TIMEOUT_MS: u64 = 30_000;
    fn push(&mut self, value: Self::Item);
}

impl BoundedQueue for RingBuffer {
    type Item = Token;
    const CAPACITY: u32 = 256;
    fn push(&mut self, value: Token) { … }
}
```

```aski
@[| BoundedQueue
  Item
  {| Capacity         U32 |}
  {| DefaultTimeoutMs U64 30_000 |}
  (push ~&self self:Item)
|]

[BoundedQueue RingBuffer [
  (Item Token)
  {| Capacity U32 256 |}
  (push ~&self &value Token [ … ])
]]
```

```synth
;; TraitItem.synth
// #AssociatedType#@AssociatedName
// #AssociatedConst#{| @AssociatedName <Type> ?<Expr> |}
// ( @methodName <Method> )

;; TraitImplItem.synth
// #AssociatedConstImpl#{| @AssociatedName <Type> <Expr> |}
// #AssociatedTypeImpl#( @AssociatedName <Type> )
// ( @methodName <Method> )
```

First-token decidable: `{|` = const, `(` = method or type-impl, bare
Pascal = assoc type. Aski-core adds `AssociatedConst` carrying optional
default Expr and `AssociatedConstBinding` for impl side.

---

### S11. Arrays (depends on S8)

```rust
let buffer: [u32; 16] = Array::init(16, 0);
let table: [[u8; 8]; 8] = Table::blank();

const BOARD_SIZE: u32 = 8;
let board: [Cell; BOARD_SIZE * BOARD_SIZE];
```

```aski
(buffer {Array U32 16} Array:init(16 0))
(table  {Array {Array U8 8} 8} Table:blank)

@{| BoardSize U32 8 |}
(board {Array Cell BoardSize * BoardSize})
```

Zero grammar change. Add `("Array", 2)` to `Primitive::all()`. Second
arg must const-eval to U32 — that's what S8 enables.

**Open question — array literal expression:** Rust has `[1, 2, 3]` as
an expression form. This proposal has none; construction goes via
`Array:init` / `Array:from` methods only. Decide: (a) no literal form,
methods only; (b) add a literal form and pick a delimiter.

**Open question — slice types `[T]`:** Unspec'd per
[paradigm.md](paradigm.md). An earlier draft said "skipped (Vec +
view-types cover the ground)." That's a plausible position but a
user call, not mine. Decide: (a) Unspec'd indefinitely; (b) explicitly
rejected in design.md with Vec + view-types as the replacement; (c)
accepted with a distinct primitive.

---

### S5. Bitwise operators via stdlib

```rust
let flags = READ | WRITE;
let readable = flags & READ != 0;
let shifted = byte << 4;
let masked = word & 0xFF;
```

```aski
(flags Permission:Read.bitOr(Permission:Write))
(readable flags.bitAnd(Permission:Read).ne(0))
(shifted byte.shiftLeft(4))
(masked word.bitAnd(0xFF))
```

Zero grammar change. Stdlib trait:

```aski
@[| BitOps
  (bitAnd &self &other Self Self)
  (bitOr  &self &other Self Self)
  (bitXor &self &other Self Self)
  (shiftLeft  &self &bits U8 Self)
  (shiftRight &self &bits U8 Self)
  (bitNot &self Self)
|]
```

Impls on U8/U16/U32/U64/I8/... Repurposing `&` or `|` as bitwise operators
would break borrow and logical-or.

---

### S7. Cast via stdlib From/Into

```rust
let u = byte as u32;
let t = wide as u8;
let m: Result<u32, _> = i64_value.try_into();
```

```aski
(u U32:from(byte))
(t U8:truncate(wide))          ;; narrowing uses explicit method
(m {Result U32 ConversionError} U32:tryFrom(i64Value))
```

Zero grammar change. Stdlib traits `From` / `Into` across numeric
primitives.

**Open question — narrowing conversions:** an earlier draft proposed
"explicit method names so the lossy semantics are visible at the call
site" (e.g., `U8:truncate(wide)`). Alternatives: (a) explicit named
methods per lossy op (truncate, saturate, wrap) — what the example
shows; (b) a single `TryFrom` trait returning Result for any conversion
that could lose data; (c) both, with lossy named ops as shortcuts.
Which framing?

---

### N3. Assignment / compound assignment via stdlib

```rust
fn tick(&mut self) {
    self.count += 1;
    self.last = now();
}
```

```aski
(tick ~&self [
  ~self.Count.addAssign(1)
  ~self.Last.set(Time:now)
])
```

Zero grammar change under this proposal.

**Open question — bare `=` and compound assignment:** paradigm.md lists
these as Unspec'd — not rejected. An earlier draft said "Confirmed OUT
as bare `x = y` or `x += y` syntax." That's a design call pending Li's
decision. Options: (a) never accept `=` at statement position — mutation
via stdlib trait methods only, as shown below; (b) accept `~name = expr`
(reusing the `~` mutation marker) as shorthand; (c) accept `x += y`
family as operator-sugar that desugars to trait methods. The stdlib
trait sketch below assumes (a).

```aski
@[| Counter $Value
  (set       ~&self &value $Value)
  (addAssign ~&self &delta $Value)
  (subAssign ~&self &delta $Value)
  (mulAssign ~&self &factor $Value)
|]
```

Impls on U8–U64, I8–I64, F32, F64. Consistent with "methods on types
always."

---

### S4. Closures — Position A (named-type impls) shown here

**Status: not a clear resolution.** See
[bridge/big-decisions.md §S4](big-decisions.md) — A vs B vs C still open.
This section shows **Position A** (named-type-always); if that wins,
no grammar change. If B or C wins (sugar for inline closures), grammar
changes are nontrivial.

```rust
let items: Vec<u32> = nums.iter().map(|x| x + 1).collect();
```

```aski
@{Increment (@Amount U32)}

[Callable {U32} U32 Increment [
  (call &self &u32 U32 [u32 + self.Amount])
]]

(items self.nums.map(&Increment {Amount 1}))
```

Under Position A: zero grammar change. Stdlib `Callable` trait:

```aski
@[| Callable {$Input $Output}
  (call &self $Input $Output)
|]
```

See `big-decisions.md §S4` for alternatives B (inline-closure sugar)
and C (explicit-capture shorthand). Which one lands determines the
grammar impact.

---

## Works with no grammar change

### N1. `'static` and generic lifetime parameters

Place-based origins cover everything Rust's lifetime generics express.

```rust
fn longest<'a>(left: &'a str, right: &'a str) -> &'a str { … }
fn find_name(id: u32) -> &'static str { GLOBAL_TABLE.lookup(id) }
```

```aski
(longest &'(left right) left String
         &'(left right) right String
         &'(left right) String [ … ])

(findName &id U32 &'Static String [
  GlobalTable.lookup(id)
])
```

`'Static` is a conventional place name for program-root lifetime. No
grammar change — `'Static` is already a valid `PlaceRef`.

---

### N9. Param grammar edge (`BareNamed`) — docstring clarify only

Pattern.synth's `BareNamed` (`@param` with no type) is for parameters
whose type is implied by context (inference sites). Not a placeholder
for self. Update the Param.synth header comment; no code change.

---

## Proposed OUT — design.md doesn't yet reject these

*Every item below was previously marked "Confirmed OUT" but paradigm.md
classifies it as Unspec'd (or user-preference only). Each is a proposal
to add a prose rejection to design.md, pending Li's decision. Until
design.md gains a citation, these remain Unspec'd, not OUT.*

### C8. Inherent impls — spec silent, rejection proposed

**Current status (per paradigm.md):** Unspec'd. design.md §No Free
Functions forbids free functions; it does NOT explicitly forbid
inherent impls. Root.synth has no grammar rule for them today.

**Proposed rejection** (to add to design.md, pending approval): every
method belongs to a named trait. For one-off capabilities, declare a
single-method trait named after the capability.

```rust
impl Counter { fn tick(&mut self) { self.count += 1; } }
```

```aski
@[| Tick
  (tick ~&self)
|]

[Tick Counter [
  (tick ~&self [~self.Count.addAssign(1)])
]]
```

Proposed addition to design.md §No Free Functions (pending Li's approval):
"And no inherent impls — every method cluster is a named trait."

---

### S1. Type aliases — spec silent, user-preference OUT (pending formalization)

**Current status (per paradigm.md):** Unspec'd. design.md doesn't mention
type aliases. User stated preference 2026-04-19: aliases aren't a bridge
target because newtypes preserve type identity while aliases weaken it.
Preference noted but not yet written into design.md.

```rust
type FileId = u64;   // identity-free alias
```

```aski
(| FileId U64 |)     ;; Newtype — FileId is a distinct type.
```

---

### S12. Multi-field unnamed variants

StructVariant already covers this with named fields (no tuples in aski).

```rust
enum Message {
    Move(i32, i32),       // anonymous tuple-variant — OUT
}
```

```aski
@(Message
  {Move (@X I32) (@Y I32)})    ;; StructVariant with named fields
```

---

### N4. Finer-grained visibility — open

**Current status (per paradigm.md):** Proposed. `@` = public, default
private is Landed. Rust's `pub(crate)` / `pub(super)` / `pub(in path)`
have no aski form.

**Open question:** is public/private the permanent model, or does aski
eventually need scoped visibility? If eventually: a plausible extension
path is `@(PlaceName)` for scoped visibility (`@(Crate)`, `@(Super)`,
module-path scopes) — reusing origins' place-name intuition. An earlier
draft said "Public/private is sufficient pre-1.0"; that's an opinion,
not Li's call.

---

### N6. Attributes / derive / cfg — spec silent

**Status: spec silent.** design.md doesn't address attributes.
The pipeline stages that might replace them (sema, domainc, criome)
don't exist yet. Commonly-cited rationales below are **speculation**,
not spec:

- `#[derive(...)]` — rationale: *might* be replaced once the sema
  pipeline auto-applies structural traits. Not currently specified.
- `#[cfg(...)]` — rationale: *might* be replaced by the criome's
  world model for conditional compilation. Not currently specified.
- `#[inline]` — rationale: *might* be replaced by semac's decisions
  from the binary representation. Not currently specified.

Proposed addition to design.md: "§No Attributes — sema, domainc, and
criome cover what Rust attributes do." This formalizes the intent
and would move N6 from "spec silent" to "confirmed OUT."
