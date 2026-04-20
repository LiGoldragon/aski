;; Bridge Proposals — Small Decisions
;; Date: 2026-04-20
;; Part of [../bridge-proposals.md](../bridge-proposals.md).
;;
;; Each item's design shape is settled — only a specific naming
;; or sigil choice remains. One nod per item unblocks the landing.

# Contents

1. [S3. break / continue / labeled loops — sigil spelling](#s3-break--continue--labeled-loops--sigil-spelling)
2. [S6. dyn Trait — the `?` prefix at type position](#s6-dyn-trait--the--prefix-at-type-position)
3. [N5. Enum variant discriminants — one-token lookahead](#n5-enum-variant-discriminants--one-token-lookahead)
4. [Char literal delimiter — backtick vs alternative](#char-literal-delimiter--backtick-vs-alternative)

---

## S3. break / continue / labeled loops — sigil spelling

Proposed direction: extend the `^` family. The only existing spec
item is `#EarlyReturn#^<Expr>` in Statement.synth — the "exit family"
framing is my gloss, not spec. Three new statement forms plus an
optional `'Label` on loops. Reusing the origin sigil `'` for loop
labels is a proposed overload that follows the Polonius-adjacent
"code location = place" intuition.

**Proposed spellings:**

| Form | Spelling | Reading |
|------|----------|---------|
| Early return from method (existing) | `^<Expr>` | exit method |
| Break from innermost loop with value | `^^<Expr>` | exit deeper |
| Break from innermost loop (Unit) | `^^` | exit deeper |
| Continue innermost loop | `^~` | exit-and-restart |
| Break labeled loop | `^'LoopPlace<Expr>` | exit to this place |

```rust
fn next_critical(&self) -> Option<Task> {
    'outer: loop {
        for task in self.queue.iter() {
            if task.stale { continue; }
            if task.critical {
                break 'outer Some(task.clone());
            }
        }
        break None;
    }
}
```

```aski
(nextCritical &self {Option Task} [| 'outerLoop true
  {| self.queue.task
    (| task.Stale
      ( True )  ^~
      ( False ) Unit
    |)
    (| task.Critical
      ( True )  ^^'outerLoop Option:Some(task.clone)
      ( False ) Unit
    |)
  |}
  ^^Option:None
|])
```

```synth
;; Loop.synth — add optional origin label
?'<PlaceName>
<Expr>
*<Statement>

;; Statement.synth — add break, continue, labeled-break
// #Break#_^_ _^_?<Expr>
// #BreakLabeled#_^_ _^_ _'_@PlaceName ?<Expr>
// #Continue#_^_ _~_
```

Aski-core: `Statement::Break { Label, Value }`, `Statement::Continue
{ Label }`, `Loop.Label: [Option PlaceName]`.

### Decision to make

Is `^^` the right spelling for break-with-value, or would `^!`
(exit-emphasis) or `^@` (exit-at) read better? Is `^~` the right
continue spelling, or would `~^` work? Is `^'Label` natural or should
labeled-break have its own non-composed sigil?

**Recommendation:** `^^` / `^~` / `^'Label` as proposed. `^^` reads
"exit harder"; `^~` reuses `~` as restart-modifier; `^'` reuses the
origin sigil for code-place.

---

## S6. dyn Trait — the `?` prefix at type position

Syntactic shape proposed; semantic design is open (see `big-decisions.md §S6`
for the dyn-dispatch semantic question — vtables or discriminants in sema).
The *syntactic* question here is what sigil marks a type as dyn-dispatched,
conditional on the semantics being designed.

**Proposed syntax:**

```synth
;; Type.synth — add DynType
// #DynType#_?_{ <TypeApplication> }
```

```rust
fn emit(out: &mut dyn Writer, msg: &str) { out.write(msg); }
fn next_token(src: &mut dyn Iterator<Item = Token>) -> Option<Token> { src.next() }
let boxed: Box<dyn Callable<u32, u32>> = Box::new(…);
```

```aski
(emit ~&out {?Writer} &msg String [~out.write(msg)])
(nextToken ~&src {?Iterator Token} {Option Token} [~src.next])
(boxed {Box {?Callable U32 U32}} …)
```

`?` prefix on a type application = "dyn dispatch." Reads as
"unknown-concrete that satisfies."

### Decision to make

Is `?{Trait}` the right sigil for dyn, or would one of these read
better?

- `&{Trait}` — but plain `&Type` is already borrow; merging dyn into
  borrow conflates two orthogonal concerns.
- `{^Trait}` — `^` is early-return, bad overload.
- New delimiter pair — all six are allocated; creating a seventh costs
  design clarity.

**Recommendation:** `?{Trait}` as proposed. `?` is unused at type
position (postfix-only elsewhere as try-unwrap); it reads "unknown-but-
satisfies"; single-sigil addition doesn't burden the grammar.

---

## N5. Enum variant discriminants — one-token lookahead

Proposed: add a `DiscriminantVariant` form for `Variant = Literal`.
Uses `=` (currently only bound inside `==`/`!=`/`<=`/`>=`) as a bare
token.

The *decision* is whether to accept one-token lookahead inside Enum
bodies. Both `BareVariant` and `DiscriminantVariant` open with a
bare PascalCase name; they differ at the *second* token (`=` vs
anything else).

**Proposed grammar:**

```synth
;; Enum.synth — add DiscriminantVariant
// *#BareVariant#@VariantName
// *#DiscriminantVariant#@VariantName _=_ @Literal
// *#DataVariant#( @VariantName <Type> )
// *#StructVariant#{ @VariantName <Struct> }
// *#NestedEnum#(| @EnumName <Enum> |)
// *#NestedStruct#{| @StructName <Struct> |}
```

```rust
#[repr(u16)]
enum HttpStatus {
    Ok = 200,
    NotFound = 404,
    ServerError = 500,
}
```

```aski
;; aski binary layout is sema — repr is derived, not annotated.
@(HttpStatus
  Ok = 200
  NotFound = 404
  ServerError = 500)
```

### Decision to make

Accept one-token lookahead at the enum-body dispatch, or skip N5
entirely?

Enum.synth already branches on the *shape* of the next token after the
variant name (`(` → DataVariant, `{` → StructVariant, `(|` → NestedEnum,
`{|` → NestedStruct, nothing → BareVariant). The new case adds `=` as
one more "next-token" alternative. Materially the same cost.

**Recommendation:** accept. "No complex lookahead" (design.md §No
Complex Lookahead) targets multi-token backtracking, not single-token
disambiguation past a variant name.

If rejected: discriminants remain unspec'd. (The aski-core/sema layout
rule for variants without explicit discriminants is not currently in
design.md — commonly assumed to be ordinal but not spec-grounded.
Anything beyond "no explicit discriminant form exists" would be
speculation.)

---

## Char literal delimiter — backtick vs alternative

A char literal needs a delimiter that doesn't conflict with existing
syntax. The candidates:

- `'x'` — apostrophe is the origin sigil; bare `'` after an identifier
  would collide with `'PlaceName`.
- `\`x\`` — backtick, currently entirely unused in aski.
- `c"x"` / `"x"c` — prefix/suffix-typed char (borrows from byte-string
  patterns); pushes tag logic into the lexer.

**Proposed:** backtick.

```rust
let newline = '\n';
let ch = 'a';
let tab = '\t';
```

```aski
(newline `\n`)
(ch `a`)
(tab `\t`)
```

### Decision to make

Confirm backtick. If rejected, pick between the other candidates.

**Recommendation:** backtick. Zero existing conflict; compact; visually
distinct from string literal `"..."` and origin `'Place`.

---

# Ranking

Land in this order once nods land:

1. **Char literal backtick** — unblocks N8 (lexer literal work) fully.
2. **N5 discriminant lookahead** — binary accept/skip.
3. **S3 sigil spellings** — unblocks break/continue landing.
4. **S6 `?{Trait}` syntax** — unblocks the grammar half of dyn;
   semantics still blocked on `big-decisions.md §S6`.
