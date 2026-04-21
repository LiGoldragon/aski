# Aski v0.21 Outliers

*2026-04-21 · Sister doc to [syntax-v021.aski](syntax-v021.aski),
[gap-analysis.md](gap-analysis.md), [bridge/clear.md](bridge/clear.md),
[bridge/big-decisions.md](bridge/big-decisions.md),
[bridge/small-decisions.md](bridge/small-decisions.md).*

These items could not be cleanly merged into v0.21 in the
2026-04-21 pass. Each falls into one of these buckets:

- it **blocks against aski idioms** (case rule, delimiter budget,
  II-L channels);
- it requires a **real design decision** (architecturally
  consequential; needs Li's position, not just shape);
- it is **Li-uninspected** (a prior Claude-authored claim that
  was retracted and never re-confirmed).

Organized by the block type that keeps them out. The closing
section maps every outlier to the decision Li needs to make.

For items merged in this pass, see the "Newly landed" header in
`syntax-v021.aski` and the PICK-AND-MERGE flags throughout it.

---

# Bucket 1 — Case-rule blocks

## U3. `true` / `false` as literal tokens

**Why blocked.** The case rule (design.md §PascalCase and camelCase)
dispatches on the first character of every identifier: Pascal names
are compile-time structural things (types, variants, fields);
camelCase names are runtime instances. `true` / `false` written as
lowercase literal tokens read as instances of nonexistent types
`True` / `False` under this rule — there is no declared Pascal
`True` to be an instance of when the lexer meets the bare token.

**Current resolution.** `Bool` is a two-variant enum with `True`
and `False` as Pascal variants. Match arms read
`( True ) a ( False ) b`, and the conditional idiom in §C4 is
`(| cond ( True ) then ( False ) else |)`. This works today —
no literal-token form is needed for correctness.

**Carve-out option.** Make `true` / `false` special tokens in
the lexer that the parser accepts at LiteralExpr and
LiteralPattern positions. Cost: the case rule's "Pascal means
structural, camel means instance" symmetry weakens — two
lowercase tokens would have no declaration site, which is
exactly the category the case rule was designed to rule out.

**What needs to change to unblock.** Li either:
- (a) commits to the variant form permanently (case rule wins; no
  carve-out; close U3);
- (b) grants a case-rule carve-out for `true` / `false` specifically
  (cite "finite set of identifier-shaped literals" as the
  justification; add to design.md); or
- (c) reframes `Bool` as a primitive with its own literal form, not
  a variant-enum. This cascades to C3 (LiteralPattern scope) and
  C4 (conditional idiom).

Linked: U2 (Bool in LiteralPattern) and the gap-analysis.md §U3
entry. See also the C3 pick-and-merge in syntax-v021.aski for the
pattern-side question.

---

# Bucket 2 — Delimiter-budget blocks

## U4. Array literal expression `[1 2 3]`

**Why blocked.** All six delimiter pairs `()`, `[]`, `{}`,
`(||)`, `[||]`, `{||}` are allocated (see design.md §Delimiter-
First). `[]` at expression position is already ExprStmt / Block /
InlineEval / or-pattern / impl-activation — five roles on one
delimiter, position-disambiguated. Adding "array literal" at
expression position means either:

- stealing a role from `[]` at one of its positions (requires
  proof no ambiguity with the remaining positions), or
- picking a different delimiter that isn't allocated (there
  aren't any), or
- adding a seventh delimiter pair (reshapes the delimiter budget
  and the "six pairs" claim in design.md).

**Current resolution (merged as §S11 Array).** Array is a
primitive type `{Array T N}`; construction goes through methods
like `Array:fill(n, value)` or `Array:of(a, b, c)`. The Array type
landed; the literal expression form stayed behind.

**What needs to change to unblock.** Li either:
- (a) commits to methods-only construction permanently (close U4;
  add to design.md a "no literal delimiter-array form" note); or
- (b) picks a delimiter role to steal and sketches the
  disambiguation (e.g., `[: T : elems ]` at expression position
  with a leading `:` token — but this deserves a real proposal
  before grammar work); or
- (c) spends a seventh delimiter pair on array literals.

See gap-analysis.md §U4 and §S11.

---

# Bucket 3 — Semantic design needed

## S6. dyn semantics

**Why blocked.** The syntactic sigil `?{Trait}` is one of the
PICK-AND-MERGE flags in syntax-v021.aski; the grammar half is
easy to land. The semantic half is architecturally consequential
and unresolved.

Sema's core invariant ("the bytes ARE the type; no string tags,
no pointer chases") is at direct tension with dyn dispatch
(which inherently erases static type identity). From
bridge/big-decisions.md §S6, four positions:

1. **Discriminant-prefix dyn.** A `?{Trait}` value is laid out
   as `(concrete-type-discriminant, concrete-payload)`. The
   discriminant enumerates every concrete type impl'ing `Trait`
   in the program. Call dispatch walks the discriminant.
   - Pure binary, matches sema invariant.
   - Requires whole-program analysis; adding an impl reshuffles
     every dyn value's byte layout. Bad for stability.

2. **Vtable-pointer dyn (Rust-style).** A `?{Trait}` is a fat
   pointer with a vtable pointer component.
   - Works; matches Rust idiom directly.
   - Vtable pointers aren't domain variants; they are
     implementation addresses. Sema-the-format loses its core
     invariant.

3. **No dyn at all.** Reject S6 entirely; polymorphism via
   generics + trait bounds only. Heterogeneous collections
   become enums of specific types.
   - Sema invariant holds cleanly; monomorphic code is faster
     and smaller.
   - Loses an expressiveness tier. Plugin/extension systems that
     don't know all impls at compile time can't work.

4. **Transient-only dyn.** `?{Trait}` is valid at aski / veric
   level but doesn't serialize into sema. Exists only as a
   runtime concept for dispatch; serialized world state uses
   concrete types only.
   - Preserves sema invariant plus source convenience.
   - Veric enforces "no dyn in serialized fields"; adds a
     two-tier type system (sema-level vs runtime-level).

**What needs to change to unblock.** Li picks a position.
Position 3 is the restrictive-but-clean choice; Position 1 is a
novel discriminant-based approach; Position 2 is the
pragmatic-familiar choice that introduces non-binary components;
Position 4 is a compromise.

Until this is decided, the syntactic `?{Trait}` sigil sits in
the pick-and-merge bucket. Landing syntax ahead of semantics
invites source that won't have a consistent semantic path.

See gap-analysis.md §S6 and bridge/big-decisions.md §S6.

---

## U19. Native infinite-loop form

**Why blocked.** design.md had a previous note "No Native
Infinite-Loop Form" that was Claude-authored and retracted; the
question is open. Today's `[| true body |]` works but reads
awkwardly and relies on Bool's variant-enum form having a `true`
truth-value (which itself depends on U3's resolution).

From gap-analysis.md §U19, five candidates:

1. **Keep `[| true body |]`.** Current, works, awkward. Requires
   U3 resolution to know what `true` is at that position.
2. **Optional condition via prefix marker.** `[| ? cond body |]`
   for while; `[| body |]` for infinite. First-token-decidable
   at loop-body-open.
3. **Two dialects — WhileLoop + InfiniteLoop.** InfiniteLoop
   takes a seventh delimiter pair. Costs the six-delimiter
   budget.
4. **Content-shape dispatch inside `[||]`.** Peek past the open
   delimiter to decide while-vs-infinite. Borderline §No Complex
   Lookahead depending on Li's interpretation.
5. **Method-style — `Loop:forever [body]` via stdlib.** Zero
   grammar change; fits the methods-over-operators direction
   (aligns with U17 rubric PICK-AND-MERGE).

**What needs to change to unblock.** Li picks one. Candidate 5
is the lowest-cost option if U17 lands as the rubric — no
grammar change, just a stdlib trait. Candidate 2 is the
lowest-cost grammar option if the native form is preferred.

See gap-analysis.md §U19.

---

## U5. Slice types `[T]`

**Why blocked.** `[T]` in Rust is an unsized view into a
contiguous region; it exists as a distinct type from `Vec<T>`
and from `[T; N]`. aski currently has `Vec` and (as of this
pass) `{Array T N}`. The "view over a range" role is
currently served by view types `{| Field |}` attached to
borrows — but that's a field-granularity view, not a slice of a
sequence.

From gap-analysis.md §U5, three options:

1. **Stay Unspec'd.** Defer. If the need arises, the decision
   can be made later.
2. **Formally reject in design.md with Vec + view-types as
   replacement.** Prose citation in design.md. Closes U5.
3. **Accept as a distinct primitive `{Slice T}`.** Parallels
   `{Array T N}` but with a dynamic length component. Requires
   design for how the length is carried (fat pointer? prefix?)
   and how it interacts with view types.

**What needs to change to unblock.** Li picks (a), (b), or (c).
Note: the "Vec + view-types cover the ground" claim in the
earlier draft was Claude-authored; view types over sequence
ranges specifically aren't currently spec'd.

See gap-analysis.md §U5.

---

## U6. Narrowing conversions

**Why blocked.** S7 merged with explicit-lossy-method-name form
(`U8:truncate(wide)`, `U8:saturate(wide)`, `U8:wrap(wide)`), but
the earlier bridge proposal enumerated three forms. Li hasn't
explicitly picked one.

From bridge/clear.md §S7:

1. **Explicit lossy method names per op** — `truncate`,
   `saturate`, `wrap`. Lossy semantics visible at call site.
   (Current S7-merged shape.)
2. **Single `TryFrom` returning Result** for any conversion
   that could lose data. Uniform but pushes the lossy-vs-
   non-lossy distinction to runtime.
3. **Both** — lossy named ops as shortcuts over TryFrom. Every
   narrowing has a quick-method form (`truncate`) and a safe form
   (`tryFrom` returning Result).

**What needs to change to unblock.** Li confirms (a) or swaps
to (b) or (c). S7 as merged ships (a); the confirmation is
whether that's the standing answer.

See gap-analysis.md §U6 and bridge/clear.md §S7.

---

# Bucket 4 — II-L specific

## U10 / N4. Finer-grained visibility

**Why blocked.** Under II-L, the filesystem carries three
visibility channels:
- file-level: `_` prefix on filename = private (visible only
  within its directory); no prefix = public;
- directory-level: `_` prefix on directory name = private
  sub-module;
- field-level: `@` sigil on struct field names = public, bare
  Pascal = private (body-internal, not path-level).

That's the whole visibility vocabulary. Rust's `pub(crate)`,
`pub(super)`, `pub(in path)` have no natural filesystem encoding
under II-L — scoped visibility is a *scope* concept, and the
scope is the filesystem tree, so "visible up to X" becomes
"visible to any path that is an ancestor of X," which doesn't
collapse to a single filename channel.

**Options.**

1. **Public/private permanent.** Commit to two-level visibility
   forever. Add a design.md citation. Closes U10 / N4.
2. **Second prefix layer.** `__Name.struct` = module-private
   (visible only within the exact directory); `_Name.struct` =
   file-private (historical meaning, visible within subtree).
   Prefix depth = scope breadth.
   - Cost: `_` is the one visibility channel; adding `__`
     splits it. Readers must parse prefix depth.
3. **Directory-convention.** Files in a `private/` subdirectory
   are module-scoped private. All other files follow the
   standard rule.
   - Cost: introduces a reserved directory name; two ways to
     mark privacy at file level.
4. **Source-level sigil inside the file.** A line in the body
   or a separate `visibility` file per directory declares
   scoped visibility.
   - Cost: slightly contradicts II-L (some visibility info back
     in source).

**What needs to change to unblock.** Li picks one. (1) is the
simplest; (2) is the purest II-L extension; (3) uses a
convention channel; (4) steps back from II-L slightly.

See gap-analysis.md §U10 / §N4.

---

# Bucket 5 — Li hasn't confirmed

## U20. Higher-kinded types

**Why flagged.** design.md §We Compile to Rust and §Generics
rule 6 previously asserted "no higher-kinded types" because
"Rust can't express HKT." Li did not confirm; the inference from
"compile to Rust" to "no HKT at the aski layer" is Claude-
authored.

From gap-analysis.md §U20:
- (a) Keep HKT out with updated prose (acknowledging Rust's GATs
  but committing to rank-1 for simplicity).
- (b) Accept HKT at aski layer with desugaring strategy
  (monomorphization, or GAT-style desugaring on the way to
  Rust).
- (c) Leave Unspec'd pending a real use case.

**What needs to change.** Li picks (a), (b), or (c). Unconfirmed
today.

---

## U21. Dependent types

**Why flagged.** design.md §We Compile to Rust says "No dependent
types (yet)." The "(yet)" indicates deferred, not permanent. Li
did not confirm either way.

From gap-analysis.md §U21:
- (a) Permanent OUT.
- (b) Deferred with a trigger (when does aski get dependent
  types? what would they express?).
- (c) Unspec'd indefinitely.

**What needs to change.** Li picks.

---

## U7. Bare `=` and compound `+=`

**Why flagged.** N3 (assignment via stdlib methods) merged in
this pass, which ships the method-only direction: all mutation
is via `~place.method(args)`. But the bare-operator question —
does `=` / `+=` ever appear as grammar, even as a shorthand —
remains open.

From gap-analysis.md §U7:
- (a) Never accept `=` — mutation via stdlib trait methods only
  (the current direction; N3 ships this).
- (b) Accept `~name = expr` (reusing the `~` mutation marker)
  as a shorthand for `~name.set(expr)`.
- (c) Accept `x += y` family as operator-sugar desugaring to
  trait methods.

**What needs to change.** Li confirms (a) as permanent or opens
a carve-out path. If (a), add a design.md citation. If (b) or
(c), the grammar needs ExprStmt additions and aski-core needs
new Statement variants.

---

## U12. Closures Positions B and C

**Why flagged.** S4 (closures Position A — named-type impls of
Callable) merged in this pass as the zero-grammar-change
baseline. Positions B and C are inline-sugar forms that would
expand the grammar:

- **Position B — inline closure sugar.** A syntactic form like
  `{|input| body}` that desugars to a synthetic Callable-impl
  type during lowering. Synthetic names are grammar-generated
  (position / body-hash / counter).
  - Pro: Rust-level ergonomics for closure-heavy code.
  - Con: synthetic names violate "Names Are Meaningful" in
    letter. Adds a delimiter slot for closure literals (every
    delimiter is already allocated; this needs a seventh).
  - Capture semantics to decide: implicit-infer vs explicit.

- **Position C — explicit-capture shorthand.** An inline form
  that lists its captures and generates a synthetic type. E.g.,
  `(items self.Nums.map({amount 1} &u32 [u32 + amount]))`.
  - Pro: captures explicit (no surprise behavior); terser than
    Position A.
  - Con: still a new grammar form; reads weird until familiar.

**What needs to change.** Li picks. If A (already merged in
Position A) is the permanent answer, close U12. If B or C, the
grammar expansion is substantial and cascades: delimiter
choice, capture syntax, return-type inference or explicit
annotation, trait selection (Callable vs CallableOnce vs
CallableMut — aski would need a family).

See gap-analysis.md §U12 and bridge/big-decisions.md §S4.

---

# Decision table

| Item | What Li needs to decide | Cascades |
|------|-------------------------|----------|
| U3   | Bool literal-token carve-out? (a) variant form permanent, (b) carve-out, (c) Bool-is-primitive | Cascades into C3 (LiteralPattern scope) and C4 (conditional idiom); U19 if `true` stays the while-guard |
| U4   | Array literal expression? (a) methods-only permanent, (b) steal a `[]` role, (c) seventh delimiter | Local if (a). Reshapes grammar if (b) or (c) |
| U5   | Slice types? (a) Unspec'd, (b) formal reject, (c) accept as primitive | Local |
| U6   | Narrowing conversion form? (a) lossy names, (b) TryFrom only, (c) both | Local; S7 merged with (a) provisionally |
| U7   | Bare `=` / `+=`? (a) methods-only permanent, (b) `~name = expr`, (c) `+=` family | Local; N3 merged with (a) provisionally |
| U10 / N4 | Scoped visibility? (a) public/private permanent, (b) prefix-depth, (c) directory-convention, (d) source sigil | Local but shapes II-L convention doc |
| U12  | Closures B/C inline-sugar? (a) A is permanent, (b) B, (c) C | Grammar: delimiter, capture, trait family if B/C |
| U19  | Infinite loop? (a) keep `[\| true body \|]`, (b) prefix marker, (c) two dialects, (d) content-shape, (e) stdlib method | Touches Loop.synth / design.md § if (b)-(d); stdlib if (e) |
| U20  | HKT? (a) out, (b) in at aski layer, (c) Unspec'd | Local to design.md |
| U21  | Dependent types? (a) out, (b) deferred-with-trigger, (c) Unspec'd | Local to design.md |
| S6   | dyn semantics? (1) discriminant, (2) vtable, (3) no-dyn, (4) transient-only | Cascades into every doc section on dyn; unblocks U14 sigil once decided |

Most outliers are **local decisions** — picking one among
several candidates without further cascades. Two are not:

- **S6 dyn semantics** cascades into every section that mentions
  dyn or trait objects (bridge docs, gap-analysis, plugin
  systems, effect interactions, future stdlib traits). The sigil
  (U14) is ready to land the moment semantics are decided.
- **U19 infinite loop** cascades into Loop.synth grammar (if
  2/3/4 wins), design.md prose (if 1 wins and becomes canon), or
  the stdlib trait catalog (if 5 wins). The five candidates each
  shape different surfaces.

Everything else is a one-shot decision with bounded impact.
