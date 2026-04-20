;; Aski v0.20 vs Rust — Gap Analysis
;; Date: 2026-04-19
;; Sources: [syntax-v020.aski](syntax-v020.aski),
;; [design.md](design.md), ../core/*.core, ../../askicc/source/**/*.synth.
;; Cross-checked against Mentci/RESTART-CONTEXT.md §13.

# Scope

Only cases where aski **could not express** a Rust program, or would have to
contort via RFI/workarounds. Features aski deliberately rejects (tuples,
native `loop`, free functions, keywords, HKT, dependent types, shadowing
same name twice) are NOT flagged.

Features already acknowledged in RESTART-CONTEXT §13 "Broader language
evolution" (RFI expansion, trait objects, pattern guards, where clauses,
method-local generics) are listed once for completeness and not
re-analysed.

# Critical — blocks ordinary Rust code

## C1. Wildcard pattern `_` — SHIPPED 2026-04-19
~~No wildcard pattern.~~ Landed across synth-core, askicc, aski-core.
Pattern.synth now has five forms: `WildcardPattern`, `VariantBind`,
`VariantAlt`, `VariantMatch`, `StringMatch`. See
[bridge/clear.md §C1](bridge/clear.md).

## C2. No struct / data-variant destructuring
`VariantBind` binds the entire payload of a `DataVariant` to **one** name.
There is no `Point { Horizontal h Vertical v } => ...` or
`Some (x y)` → two bindings. If a variant carries a struct payload, you
can't bind individual fields in the arm; you must bind the whole struct
and use field access afterward. Common Rust pattern; currently
inexpressible.

## C3. No numeric literal patterns
`StringMatch "literal"` exists but no `IntMatch 0`, `FloatMatch`,
`BoolMatch true`. `match status { 0 => …, _ => … }` has no direct aski
form. You can work around by defining an enum per value, but arbitrary
integers can't.

## C4. No `if` / `if let` / `while let`
Only `match` and `while <cond>` exist. `if cond { a } else { b }` is
expressible only as `(| cond (True) a (False) b |)`, which requires
`Bool` to be a two-variant enum in scope AND exhaustive matching. This
is workable but friction-ful and relies on C3 being solved (for matching
on `bool`). `if let` and `while let` have no equivalent.

## C5. No division `/` operator
RESTART-CONTEXT notes `/` was "freed for future division" in v0.19 but
`ExprMul.synth` has only `*` and `%`. The lexer resolves `/` to
`LiteralToken::Slash`; no grammar consumes it. Ship-blocker for any
arithmetic code.

## C6. No unary operators
No negation `-x`, no logical NOT `!x`, no deref `*x`. `ExprAtom.synth`
has no opener for a leading operator; `ExprMul`/`ExprAdd` start from
`<ExprPostfix>`. Writing `-1` is currently impossible at expression
position — `LiteralExpr` emits a literal token but there is no grammar
path from a binary minus to "unary -". Logical NOT is especially glaring
because `&&` / `||` / `==` / `!=` all exist.

## C7. Borrow expressions only work on bare instances
`ExprAtom.synth`: `_&_?<Origin>?<ViewType>:instance` — the target of `&`
is a single `InstanceName` token. You cannot write `&self.field`,
`&item.inner.child`, `&method()`, or `&(expr)`. Rust borrows arbitrary
place expressions; aski restricts to the narrowest atom. Impact: any
API that takes `&T` for a nested field is unreachable from aski source.

## C8. Inherent impls — grammar has no form; spec silent
`Root.synth` has only `#TraitImpl#[@TraitName … <Type> [+<TraitImplItem>]]` —
no bare `[TypeName [...methods...]]` form. design.md §No Free Functions
addresses free functions, but does NOT explicitly forbid inherent impls
in prose. So: currently impossible to write because the grammar has
no rule; the design.md spec is silent on whether this is intended
permanent OUT or an oversight. See [bridge/paradigm.md](bridge/paradigm.md)
spec-status levels.

# Significant — common patterns not expressible

## S1. Type aliases — grammar has no form; spec silent
`Root.synth` has no `#TypeAlias#…` form. design.md does not mention
type aliases at all — neither accepting nor rejecting them. User has
indicated (2026-04-19) a preference that aliases stay OUT because
newtypes preserve type identity while aliases weaken it. Record as
user-preference-OUT rather than design-spec-OUT until design.md is
updated.

## S2. No range expressions
`0..n`, `a..=b` missing. Consequence: `for i in 0..10` has no form;
`Iteration` requires an expression that evaluates to an iterable, so
either the range is a method call (`Range:new(0 10)`) or there's no
numeric iteration.

## S3. No `break` / `continue` / labeled loops
`Statement.synth` has no `BreakStmt` / `ContinueStmt`. `break value` is
impossible. Only exit from a loop is `^expr` (early return of the
enclosing method). Nested loops cannot break outer loops. Impact: a lot
of loop-structured code becomes awkward.

## S4. Closures / lambdas — grammar has no form; spec silent
No `|x| x + 1` form in current grammar. design.md does not address
closures. Rust's `iter.map(|x| ...)` idiom has no direct form in
aski source today. Fn/FnMut/FnOnce traits not in stdlib spec either.
Direction still open — see [bridge/big-decisions.md §S4](bridge/big-decisions.md).

## S5. No bitwise operators
No `&`, `|`, `^`, `<<`, `>>` at Expr level (single `&` / `|` would
conflict with borrow / newtype sigils; `<<` / `>>` are unused). Any
bit-twiddling code can't be written; masks and flags are common in
systems-y code and protocols.

## S6. No trait objects / `dyn` / `impl Trait`
Already in RESTART-CONTEXT §13. Re-stating because it interacts with
S4 — without `dyn Fn` or `impl Fn`, there's no way to accept an
arbitrary callable as a parameter.

## S7. No cast `as`
No `as` operator in grammar. design.md doesn't address it. Trait
methods (user-defined `From` / `Into`) are already expressible via
normal trait impl — nothing blocks them — but the stdlib doesn't
declare them yet, so `U32:from(x)` works only if the user defines
the trait first.

## S8. Const values are literal-only
`Root.synth`: `#Const#{| @ConstName <Type> @Literal |}`. The right-hand
side is `@Literal` — a single literal token, not an expression. Rust
allows arbitrary const expressions: `const MAX: u32 = BASE * 2 + 1;`.
Aski has no form for this. Every derived constant must be hand-inlined.

## S9. No associated constants in traits
`TraitItem.synth` has only `AssociatedType` and methods. Rust trait
`const MAX: u32;` / `const MAX: u32 = 100;` has no aski form.

## S10. No struct field destructuring on left side
No `let Point { Horizontal h Vertical v } = point;`. Combined with C2
(same issue in match position), this means destructuring is entirely
absent.

## S11. No array/slice literal or type
No `[1, 2, 3]` expression, no `[T; N]` type, no `[T]` slice. `Vec` is
the only sequence type. No compile-time-sized arrays.

## S12. Enum variants can't carry multiple unnamed fields
A `DataVariant` has exactly one `Type` as payload. Rust's
`Some(x, y, z)` (a tuple-variant) forces aski to either use a
`StructVariant` (names required — consistent with §No Tuples) or wrap
a struct. That's consistent with no-tuples, but worth noting: existing
Rust code with multi-field unnamed variants can't round-trip until
you name the fields.

# Notable — narrower impact but real

## N1. `'static` / generic lifetime parameters — covered by origins
Place-based origins cover what Rust's lifetime generics express:
`fn longest<'a>(x: &'a str, y: &'a str) -> &'a str` becomes a borrow
whose origin is the union of the two input places (`&'(left right)`).
`'static` is a conventional place name for program-root scope. See
[bridge/clear.md §N1](bridge/clear.md). Not a real gap.

## N2. No `!` (never) type
`Primitive::all()` doesn't include `Never`. Functions that diverge
have no way to declare non-return in the current spec. Proposed
addition in [bridge/clear.md §N2](bridge/clear.md).

## N3. Assignment and compound assignment
No `x = y;` or `x += y;` in grammar. design.md is silent on
assignment operators specifically (though §Mutable Is Marked
describes the `~` mutation marker for method-call mutation). What
primitives "carry" in terms of stdlib mutation methods isn't
defined by the spec. Likely route is stdlib trait methods —
see [bridge/clear.md §N3](bridge/clear.md).

## N4. Only public / private visibility
Rust has `pub`, `pub(crate)`, `pub(super)`, `pub(in path)`. Aski's `@`
is public-or-private. For library-internal APIs that want to expose
within a crate but not outside, there's no level. Probably fine for
now given the ecosystem is small, but limits library ergonomics
eventually.

## N5. No explicit enum discriminants
`(Http Ok NotFound)` can't set `Ok = 200`. If sema binary layout ever
needs to match a wire protocol's numeric codes, you'd have to redefine
via a lookup table. Niche but real.

## N6. No attributes / derive / cfg
No `#[derive(Clone, Debug)]`, no `#[cfg(...)]`, no `#[inline]`. This
may be intentional: sema replaces derive (type → rkyv via the
bootstrap is already implicit); cfg-conditional compilation doesn't
obviously map to the sema model. Worth confirming whether attributes
are permanently OUT or just deferred.

## N7. No doc comments
`;;` is a line comment. No `///` or `//!`. For a self-hosting language
that emits Rust projections, some doc-carrying annotation seems
valuable — but may just be deferred.

## N8. No string escape / raw string / char / byte-string literal grammar
`LiteralValue` in aski-core has variants `Int/Float/Str/Bool/Char/Unit`.
The lexer has to turn source tokens into these. I didn't find grammar
for char literal form (`'x'` — apostrophe is the origin sigil) or raw
strings. Probably not an aski-source feature yet; worth clarifying
how non-trivial string literals are written.

## N9. No `self` by value in trait method outside of `OwnedSelf`
`Param.synth` does support `self` (owned) — OK. But note: `Param`'s
`BareNamed` (`@param` with no type) shouldn't apply to `self`, which
is fine. Just flagging: the 8th param variant (`BareNamed`) without
type may produce confusing errors if users write `self` intending
something else. Grammar is clean; doc clarity issue.

## N10. Iteration binding is a single `@Binding`
`IterationSource.synth`: `<Expr>.@Binding`. So `for (k, v) in map` has
no form (tuple destructuring missing anyway per C2/S10), but also no
form for iterating with index (`.enumerate()` → single binding, and
you'd need a way to destructure the `(usize, T)` tuple it yields).
Resolves only if C2/S10 resolve.

# Items that are OUT by design (listed so we don't re-raise)

Only items with a prose citation in design.md qualify. Items below lack
a citation; see §Unconsulted Claude decisions below for the others.

- Tuples → design.md §No Tuples.
- Native infinite `loop {}` → design.md §No Native Infinite-Loop Form.
- Higher-kinded types, dependent types → design.md §Generics.
- Free functions → design.md §No Free Functions.
- Keywords → design.md §Delimiter-First.
- Shadowing same name twice in a scope → design.md §Scopes Are a Tree.

# Items already acknowledged open in RESTART-CONTEXT §13

- RFI surface growth (target-lang specifiers, calling conventions).
- Trait objects / `dyn`.
- Pattern guards.
- Where clauses.
- Method-local generics (partially covered).

# Unconsulted Claude decisions — now open gaps

*An earlier pass through these bridge documents baked in positions
Claude had no standing to take. Per [bridge/paradigm.md](bridge/paradigm.md):
"do not say aski handles X unless there's a grammar citation; do not
say aski doesn't support X unless design.md rejects it in prose."
The items below violated that rule and are now re-opened. Each is a
gap in the spec that requires Li's decision; bridge-doc prose should
not presume one.*

## Decisions presented as settled that weren't

### U1. Deref `*x` — was "skipped because aski has no raw pointers"
clear.md §C6 previously asserted deref was out because raw pointers
are out. Two unrelated questions: raw pointers are Unspec'd
(paradigm.md), and deref could still be meaningful for smart-pointer
types (Box, Rc) via a stdlib `Deref` trait even if raw pointers never
land. Options: (a) no unary `*` at all; (b) unary `*` dispatches to a
stdlib `Deref`; (c) defer until raw-pointer question is decided.

### U2. Bool in LiteralPattern — was "OUT because case rule"
clear.md §C3 previously asserted Bool was out of LiteralPattern because
lowercase `true` / `false` tokens would violate the case rule. Options:
(a) Bool matched only via `( True )` / `( False )` variant patterns on
a Bool enum; (b) `true` / `false` carved out as primitive literal
tokens despite the case rule; (c) Bool reframed as a primitive with a
literal form, not a variant enum. Connected to U3 and U7.

### U3. `true` / `false` as literal tokens — was "retracted"
clear.md §C4 and §N8 previously retracted the carve-out, citing the
case rule. Open — depends on U2's framing. If Bool becomes a primitive
with literal form, carve-out is needed; if Bool stays a variant enum,
carve-out stays rejected.

### U4. Array literal expression syntax — was "no, methods only"
clear.md §S11 previously said arrays would be constructed via
`Array:init` / `Array:from` only, with no `[1, 2, 3]` literal form.
That's a design call, not a forced consequence. Options: (a) method-
only construction; (b) accept a literal form and pick a delimiter.

### U5. Slice types `[T]` — was "skipped"
clear.md §S11 previously asserted `[T]` was skipped because "Vec +
view-types cover the ground." Unspec'd per paradigm.md. Options:
(a) stay Unspec'd; (b) formally reject in design.md with Vec +
view-types as replacement; (c) accept as distinct primitive.

### U6. Narrowing conversions — was "explicit method names so lossy semantics are visible"
clear.md §S7 previously picked explicit lossy method names (truncate,
saturate, wrap) as the narrowing idiom. Options: (a) explicit named
methods per lossy op; (b) single `TryFrom` returning Result; (c) both,
with lossy names as shortcuts.

### U7. Bare `=` and compound assignment — was "Confirmed OUT"
clear.md §N3 previously said `x = y` / `x += y` were OUT, mutation
done via stdlib trait methods only. Unspec'd per paradigm.md. Options:
(a) never accept `=` — mutation via methods only; (b) accept
`~name = expr` (reusing the mutation marker); (c) accept `x += y`
family as operator-sugar desugaring to trait methods.

### U8. Doc comment sigil — SHELVED 2026-04-20
Moved to [shelved.md](shelved.md#u8-doc-comment-sigil). Not blocking,
not urgent; revisit when documentation becomes a real concern (rsc /
askid landing).

### U9. Inherent impls rejection — was "Confirmed OUT"
clear.md §C8 previously classified this as Confirmed OUT and proposed
the rule "every method belongs to a named trait." design.md §No Free
Functions addresses free functions but says nothing about inherent
impls. Unspec'd per paradigm.md until you approve adding the rejection
to design.md.

### U10. Finer-grained visibility — was "public/private is sufficient pre-1.0"
clear.md §N4 previously asserted pre-1.0 sufficiency as the reason for
deferring scoped visibility (`pub(crate)` family). Proposed per
paradigm.md. Options: (a) public/private permanent; (b) `@(PlaceName)`
scoped-visibility extension eventually; (c) defer indefinitely.

### U11. Struct destructuring — was "Option A recommended"
bridge/big-decisions.md previously carried a recommendation for
Option A (pun on field name) in the C2+S10+N10 destructuring
question. Three viable options remain — A, B (not viable per its own
analysis), or C. Plus sub-questions if A (automatic vs explicit
pun; case-rule framing in design.md).

### U12. Closure philosophy — was "Position A provisionally"
bridge/big-decisions.md §S4 previously recommended Position A (named-
types-always) as the provisional choice. Three positions remain — A
(no sugar), B (inline closure sugar desugaring to synthetic types), C
(named shorthand with explicit capture). Each has different character.

### U13. break / continue sigil spelling — was "`^^` / `^~` / `^'Label`"
bridge/small-decisions.md §S3 previously recommended `^^` for
break-with-value, `^~` for continue, `^'Label` for labeled break. All
alternatives (`^!`, `^@`, a dedicated non-composed sigil) remain on
the table.

### U14. dyn sigil — was "`?{Trait}`"
bridge/small-decisions.md §S6 previously recommended `?{Trait}` as
the sigil. Alternatives (`&{Trait}` with conflict, `{^Trait}` with
conflict, a new delimiter pair) listed. Syntax call still yours; the
semantic question in big-decisions.md §S6 is also open.

### U15. Enum discriminant lookahead — was "accept"
bridge/small-decisions.md §N5 previously recommended accepting one-
token lookahead inside enum bodies to disambiguate
`@VariantName = @Literal` from other variant forms. Open
interpretive question: does "No Complex Lookahead" (design.md) target
multi-token backtracking specifically, or cover single-token
disambiguation too?

### U16. Char literal delimiter — SUPERSEDED 2026-04-20 by Char-as-nested-enum
bridge/small-decisions.md previously recommended backtick `` `x` ``.
Li's direction: **no char literal syntax at all** — chars are a library
of types. `Char` is an enum with nested-enum variants by category
(Upper, Lower, Digit, Whitespace, Control, Punct, Bracket), accessed
via chained path: `Char:Upper:A`, `Char:Lower:A`, `Char:Digit:Zero`,
`Char:Punct:Tilde`, etc. Case is carried by the outer variant, so no
case-rule carve-out for letter names. Unicode fall-through via
`{Code (@Codepoint U32)}` data-variant.

**Still open:** (a) final category list (Upper/Lower/Digit/Whitespace/
Control/Punct/Bracket provisional); (b) 3-segment path grammar
(`Char:Upper:A` — chained `:` through nested enums) needs a grammar
confirmation when U16 lands.

### U17. Methods-over-operators rubric
bridge-proposals.md rubric rule #5 asserts "Methods over operators for
bit ops, casts, assignment, and similar. Stdlib traits, not new
syntax." That rule presupposes the outcomes of S5 (bitwise), S7
(cast), and N3 (assignment). It should be downgraded from rubric to
"proposed direction pending those decisions."

### U18. "unsafe / raw pointers / unions / macros / async" as OUT-by-design
gap-analysis.md's own OUT-by-design list previously included these
without a design.md citation. Each is Unspec'd, not OUT, until
design.md gains prose.

---

# Summary — ranked recommendations for review

1. **Fix immediately (pre-askic)**: C1 wildcard pattern, C5 division,
   C6 unary operators, C7 borrow-of-arbitrary-expression. Without
   these, most hello-world-beyond programs can't be written.
2. **Confirm intent, then fix or formally OUT**: C4 if/else, C8
   inherent impls, N3 assignment, N6 attributes, N4 finer-grained
   visibility. These are "feels like Rust should have it" features
   where a "no, by design" is a valid answer — but needs to be stated.
3. **Queue for post-askic**: S1 type alias, S2 range expr, S3
   break/continue, S4 closures (after trait objects land), S5 bitwise,
   S7 cast-as, S8 const expr, S9 assoc const, S10+C2 struct
   destructuring, S11 arrays, N1 static/lifetime generics, N2 never
   type, N5 enum discriminants.
4. **Clarify in docs only**: N8 char/string literal grammar, N10
   iteration bindings, N7 doc comments, N9 param-grammar edge.

Every §C and many §S items are genuine "agent reading Rust code can't
translate this" blockers. They are not "crippled language" symptoms
(that label was reserved for retiring fields); they are uncovered
corners of the grammar. Each resolution extends the language in a
well-defined direction.
