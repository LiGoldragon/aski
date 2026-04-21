# Open questions

Items not yet settled in v0.21. Organized by category. Each item records what the gap is, what's been considered, and what decision would close it.

Resolved hard blocks (Bool primitive, dyn transient-only, `?` loop marker) have been folded into the relevant chapters and are not repeated here.

## Control flow

### Break and continue

**Gap.** No `break` / `continue` / labeled break grammar.

**Candidates:**

1. `^`-family composed — `[| ? cond [^^result] |]` break-with-value, `[^^]` bare break, `[^~]` continue, `[^^'outer result]` labeled.
2. `<<` / `>>` bigrams — `[<<result]` break-with-value, `[<<]` bare break, `[>>]` continue.
3. Method-style on a loop handle — `[| 'loopHandle ? cond [~loopHandle.break(result)] |]`.

**To close:** pick one.

## Expressions and operators

### Bare `=` and `+=`

**Gap.** Mutation goes through stdlib `Counter` methods (`~name.set(x)`, `~name.addAssign(d)`). Whether an assignment operator ever appears as grammar is open.

**Candidates:**

1. Never accept `=` — mutation via methods only. Permanent.
2. Accept `~name = expr` (reusing the `~` mutation marker) as shorthand for `~name.set(expr)`.
3. Accept `x += y` family as operator sugar desugaring to trait methods.

**To close:** Li confirms (a) as permanent, or opens the carve-out path for (b) / (c).

### Array literal expression

**Gap.** `Array` is a primitive type `{Array T N}`, constructed via methods (`Array:fill(n, v)`, `Array:of(a, b, c)`). The literal delimiter form is open because all six delimiter pairs are allocated.

**Candidates:**

1. Methods-only permanent.
2. Steal a `[]` role at expression position (requires unambiguity proof with ExprStmt, Block, InlineEval, or-pattern).
3. Spend a seventh delimiter pair.

**To close:** pick one.

### Narrowing conversion form

**Gap.** Cast via `From` / `Into` / `TryFrom` is landed. Narrowing conversions currently use explicit lossy method names (`U8:truncate`, `U8:saturate`, `U8:wrap`). Alternative forms exist.

**Candidates:**

1. Explicit lossy method names per op (current).
2. Single `TryFrom` returning `Result` for any lossy conversion.
3. Both — named lossy ops as shortcuts over `TryFrom`.

**To close:** confirm (a) or swap.

### Closure sugar

**Gap.** Closures as named `Callable` impls landed. Inline sugar forms are open.

**Candidates:**

- **Inline closure** `{|input| body}` — desugars to a synthetic `Callable` impl. Conflicts: "Names Are Meaningful" in letter; delimiter budget (no free pair).
- **Explicit-capture shorthand** — e.g., `self.Nums.map({amount 1} &u32 [u32 + amount])`. Lists captures explicitly, synthesizes a type.

**To close:** pick one if either is wanted; otherwise confirm named-type-only as permanent.

### Struct destructuring pattern

**Gap.** Variant bind today takes the whole payload by one name. Field-level destructuring is not grammar.

**Candidates:**

1. Pun on field name — `(Rectangle { Width Height })` binds `width: F64`, `height: F64`.
2. Explicit rename — `(Rectangle { Width w Height h })`.
3. Both — pun by default, explicit form available.

**To close:** pick the binding rule.

## Visibility

### Scoped visibility

**Gap.** Only file-level and directory-level privacy via `_` prefix. Rust's `pub(crate)`, `pub(super)`, `pub(in path)` have no II-L encoding.

**Candidates:**

1. Two-level visibility permanent.
2. Second prefix layer — `__Name.struct` = module-private; `_Name.struct` = file-private.
3. Directory convention — files in a reserved `private/` subdirectory are module-scoped.
4. In-body sigil or separate `visibility` file per directory.

**To close:** pick one.

## Type system

### HKT

**Gap.** Higher-kinded types are not in v0.21. No explicit position in `design.md`.

**Candidates:**

1. Permanent OUT, with prose citing rank-1 for simplicity.
2. Accept at aski layer with a desugaring strategy.
3. Leave unspec'd pending a real use case.

**To close:** Li picks one.

### Dependent types

**Gap.** Not in v0.21.

**Candidates:**

1. Permanent OUT.
2. Deferred with a trigger (what would they express?).
3. Unspec'd indefinitely.

**To close:** Li picks one.

### Inherent impls

**Gap.** Rust's `impl Foo { fn bar(&self) }` (outside a trait) has no form. `design.md` is silent on whether this is intentional.

**To close:** confirm OUT (with prose) or spec a form.

### Type aliases

**Gap.** No `type X = Y` form. `design.md` is silent.

**Candidates:**

1. Permanent OUT — newtypes preserve type identity; aliases weaken it.
2. Accept at aski layer with prose.

**To close:** Li confirms position.

## Unspec'd primitives

Not in v0.21 and not explicitly rejected:

- `U128`, `I128`
- `Usize`, `Isize`
- `&str` borrowed string slice
- `Rc`, `Arc`, `Cell`, `RefCell`, `Mutex`, `RwLock`
- `HashMap`, `BTreeMap`, `HashSet`
- Slice `[T]` (unsized view distinct from `Vec` and `[T; N]`)
- Raw pointers `*const T` / `*mut T`
- `fn` pointer `fn(A) -> B`
- `Fn` / `FnMut` / `FnOnce` traits

**To close:** per-item decision (spec in, explicit OUT, or leave unspec'd with prose note).

## Trait features

Not in v0.21:

- Where clauses
- GATs (Generic Associated Types)
- HRTB `for<'a>`
- const generics (distinct from associated consts)
- `impl Trait` (input and return position)

**To close:** per-feature decision.

## Patterns

Not in v0.21:

- Pattern guards (`if cond` in match arms)
- Reference pattern `&x`
- Binding `name @ pattern` (note: `@` is visibility in v0.21)
- Range pattern `0..=9`
- General or-pattern `A | B` (current or-pattern is variants only)
- Rest pattern `..`

**To close:** per-feature decision.

## Char category list

**Gap.** The `Char` library's category list (`Upper`, `Lower`, `Digit`, `Whitespace`, `Control`, `Punct`, `Bracket`, `Code`) is provisional. Final category boundaries — especially around symbol categories and Unicode coverage — are open.

**To close:** finalize the category list.

## Safety

Not in v0.21:

- `unsafe` blocks / functions
- `transmute`
- Raw pointer deref

**To close:** per-feature decision.

## Concurrency

Entirely unspec'd:

- `async` / `await`
- `Send` / `Sync` traits
- Concurrency primitives

**To close:** long-horizon design work.

## Macros

Entirely unspec'd:

- `macro_rules!`
- Proc macros

The `.derivation` surface covers much of the derive-macro use case. Full macro replacement is open.

## Error handling

- `panic!` — no form.
- `Error` trait — not spec'd.

## Strings

- Byte string `b"..."` — unspec'd.
- Byte literal `b'x'` — unspec'd.
- Typed integer suffix `42u32` — unspec'd (other literal lexer extensions landed).

## Unit literal

- `Unit` variant exists and is usable.
- Parenthesis-form `()` literal is unspec'd.

## Doc comments

**Gap.** No doc-comment syntax. No pipeline stage (`rsc`, `askid`) needs them yet.

**Candidates when revisited:**

- `;;;` (line-start triple-semicolon, extends `;;` line-comment)
- block-doc form
- different leading marker

**Status:** deferred until documentation tooling becomes a real concern.
