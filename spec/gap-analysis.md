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

- Tuples → §No Tuples (design.md).
- Native infinite `loop {}` → §No Native Infinite-Loop Form (design.md).
- Higher-kinded types, dependent types → §Generics (design.md).
- Free functions → §No Free Functions (design.md).
- Keywords → §Delimiter-First (design.md).
- Shadowing same name twice in a scope → §Scopes Are a Tree (design.md).
- unsafe / raw pointers / unions → not in the rkyv contract.
- Macros → replaced by sema + proc-macro architecture.
- async / await → not in scope for v1 (unstated but consistent with "compile to Rust, defer stability").

# Items already acknowledged open in RESTART-CONTEXT §13

- RFI surface growth (target-lang specifiers, calling conventions).
- Trait objects / `dyn`.
- Pattern guards.
- Where clauses.
- Method-local generics (partially covered).

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
