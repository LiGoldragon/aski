# Grammar Review — Multi-Surface Delimiter Simplification

*2026-04-21 · A critique of per-surface grammar in the multi-surface
proposal. Pending Li's approval.*

[← index](../multi-surface.md)

---

## Why this review exists

The multi-surface proposal carries over v0.20 aski-root delimiter
choices into surfaces where the disambiguation those delimiters were
picked to provide no longer exists.

v0.20's delimiter allocation table exists because **six root constructs
competed for first-token-decidability inside one grammar**:

| Delimiter | v0.20 aski root construct |
|-----------|---------------------------|
| `()`      | Module (first), Enum      |
| `[]`      | TraitImpl                 |
| `{}`      | Struct                    |
| `{\|\|}`  | Const                     |
| `(\|\|)`  | Newtype                   |
| `[\|\|]`  | TraitDecl (new in v0.20)  |

Every one of those openings has to be distinct because the root parser
has to pick between all six on one token. That constraint drove
TraitDecl from `[…]` to `[|…|]` in v0.20 (clearing `[…]` for
TraitImpl), and kept Const at `{||}` to avoid colliding with Struct
`{}`.

**Once surfaces split by concern, most of those alternations vanish.**
A `.traits` file's root parser has exactly one non-module construct to
pick. A `.impls` file's root parser has exactly one non-module
construct to pick. Carrying `[|…|]` and `[…]` into those surfaces is
ceremony paid to a competition that no longer exists.

This review proposes per-surface delimiter simplifications. Each
simplification is **pending Li's approval** — nothing here has been
signed off, and the existing proposal docs are not modified.

---

## What stays non-negotiable

These are design axioms from `design.md` (§Delimiter-First, §Names Are
Meaningful, §No Free Functions, §Scopes Are a Tree, §No Complex
Lookahead, §Every Construct Is Delimited) and they constrain every
simplification below:

1. **No keywords.** Construct selection is always by delimiter + sigil
   + case.
2. **First-token decidable at every choice point within a surface.**
   Simplification cannot introduce multi-token lookahead.
3. **Pascal = compile-time structural; camel = runtime instance.** A
   Pascal-first inside a delimiter means "type-world name." A camel-
   first means "instance/method name."
4. **Every construct is delimited.** No bare multi-item sequences; no
   unwrapped root constructs (even when "there's only one construct,"
   it still needs an opener so the parser knows it's starting a new
   root item and not continuing a module body).
5. **Names are meaningful.** Impl names, derivation names, target
   names — all Pascal, all descriptive.
6. **`@` sigil = public.** Default private. Applied uniformly across
   all surfaces.

Any simplification that drops the delimiter pair entirely (e.g. "just
list trait items at file top level, no outer delimiter") violates
axiom 4 and is out of scope — root items must still be recognizable as
root items without newline significance (§No Newline Significance).

---

## Per-surface analysis

### 1. `.core` surface (the precedent, already simplified)

**What's hosted:** Module header + Enum + Struct + Newtype + Const (no
TraitDecl, no TraitImpl, no RFI, no Const with expressions beyond
literal).

**Current state (not part of this review — this is already what
ships):** reuses the same `()`, `{}`, `(||)`, `{||}` as aski root.

**Note:** The `.core` grammar is already narrower than aski root — no
TraitDecl / TraitImpl — and therefore has freed up `[]` and `[||]` in
`.core`'s root. Those freed delimiters have not been repurposed in
`.core`. The freed-delimiter analysis below for `.types` is analogous.

---

### 2. `.types` surface

**What's hosted:**
- Module header (first item)
- Enum declaration
- Struct declaration
- Newtype declaration
- Const declaration

**Current proposal (02-types.md):**
```
()    Enum (also Module at position 0)
{}    Struct
(||)  Newtype
{||}  Const
```

**Critique:** The critique's "`[|…|]` is ceremonial" observation does
*not* apply to `.types`. The four declaration delimiters encode four
**kinds of type** — Enum/Struct/Newtype/Const. Each is content-
bearing: the delimiter tells you whether the construct is one-of
(`()`), all-of (`{}`), wrapping (`(||)`), or a named compile-time
value (`{||}`). Collapsing two of these to a single delimiter would
collapse the corresponding conceptual distinction.

So `.types` delimiters are not ceremony — they are domain semantics
(§Domain = Any Data Definition). **Recommended action: leave as is.**

However, two sub-questions are worth raising:

**Q1. Does `{||}` for Const pull its weight in `.types`?**

Const is the odd one out — it's not a "domain" in the design.md §Domain
sense; it's a named compile-time value. In `.types`, the four root
constructs that share delimiter space are Enum, Struct, Newtype,
Const. `{||}` is the only one whose delimiter doesn't encode a
data-shape (the three pipes variants `(||)`/`[||]`/`{||}` are used for
NewtypeRoot / Loop or TraitDecl / Iteration or Const — the `||`
carries "wrap" or "meta" but not a data shape).

In `.types`, there's no Loop and no TraitDecl competing for `[||]`.
An alternative allocation would put Const at `[||]` (as "bracketed
meta-value") and free `{||}` entirely. This is speculative and not
recommended — the status quo `{||}` is already familiar from v0.20 —
but it is now a live option because `.types` lacks the Loop/TraitDecl
competition that constrained v0.20.

**Q2. Does `.types` need a distinction between "struct with no
fields" and "unit marker"?**

`@{Marker}` today works because `{}` with nothing inside is a valid
empty struct. No change needed.

**Freed delimiters in `.types`:**
- `[]` — free (no TraitImpl in `.types`)
- `[||]` — free (no TraitDecl in `.types`)

Possible future uses for these freed delimiters within `.types`:
- `[]` at root could host something like a **module-level
  type-alias-family block** (speculative; no proposal).
- `[||]` at root could host **opaque-abstract-type declarations** —
  types that exist only as rkyv handles, unavailable for hand impl
  (speculative; no proposal).

Both uses are sketches; not proposed for landing. The point is merely
that the freed budget exists.

**Before / after:** *(no change recommended for `.types` root).*

---

### 3. `.traits` surface

**What's hosted:**
- Module header
- Trait declarations

That's it. One non-module root construct.

**Current proposal (03-traits.md):**
```
@[| Describe
  (describe &self Quality)
|]
```

**Critique:** `[|…|]` was forced on TraitDecl in v0.20 because
TraitDecl competed with Enum for `()`, Struct for `{}`, Newtype for
`(||)`, Const for `{||}`, and TraitImpl for `[]`. Of the six pairs,
only `[||]` was free. That constraint doesn't exist in `.traits`.

In `.traits`, the root parser picks between:
- Module (`(ModuleName …)` — first item, `()` with Pascal first)
- TraitDecl (everything else)

That's a two-alternative root with a position constraint (Module is
first). Any delimiter that isn't `()` with Pascal-first at position 0
could be TraitDecl. There are multiple simpler options:

#### Option A — TraitDecl at `()` (reclaim the enum's old home)

```aski
@(Describe
  (describe &self Quality))
```

Pros:
- Shortest form. One delimiter pair, shared with Module (but Module
  appears only at position 0, TraitDecl only after).
- Matches the aesthetic that `()` = "categorical thing" (design.md
  §Delimiter-First).
- Zero ceremony.

Cons:
- A bare `(Describe …)` at position 1+ could be mistaken for a
  second module header by a reader skimming — but only visually; the
  parser has no ambiguity because position 0 is the only Module slot.
- If `.traits` files ever host non-trait root items (e.g., trait-
  aliases, effect-category declarations), `()` is consumed, forcing
  future root-construct competition again.

Verdict: cleanest form. Requires confidence that `.traits` will never
host anything else.

#### Option B — TraitDecl at `[…]` (borrow from TraitImpl's v0.20 home)

```aski
@[Describe
  (describe &self Quality)]
```

Pros:
- `[]` as "evaluation / bracket" (design.md §Delimiter-First) is a
  reasonable semantic fit for "bracketed declaration."
- Visually distinct from Module `()`.
- `[|…|]` stays in reserve for anything more structurally complex
  later (e.g., trait families).

Cons:
- Two-character delimiter forms are more informative than one-character
  — dropping the pipes loses some "this-is-a-meta-construct" visual
  marker.

Verdict: good compromise. Preserves a tier of "bigger" delimiter
(`[||]`) for richer future constructs.

#### Option C — keep `[|…|]` (status quo)

Pros:
- No transition cost; existing proposal examples stand.
- `[|…|]` is already learned by readers of v0.20.

Cons:
- Pure ceremony, as the critique observes. Pays for a disambiguation
  the surface doesn't need.

Verdict: defensible if the criterion is "cost of change" rather than
"cost of ceremony going forward."

#### Recommendation

**Option B (`[…]` for TraitDecl in `.traits`)** is the best balance:
keeps a clear visual signal that this is a declaration (not a local
thing in `()` or a struct in `{}`), while freeing `[|…|]` for
richer constructs. If future `.traits` work wants to host trait-
families or effect categories, `[|…|]` remains available for them.

**Pending approval from Li.**

**Freed delimiters in `.traits` under Option B:**
- `{}` at root — free (no Struct in `.traits`)
- `(||)` at root — free (no Newtype in `.traits`)
- `{||}` at root — free (no Const-declaration in `.traits`; note that
  `{|…|}` is still used *inside* trait bodies for associated consts)
- `[|…|]` at root — free

Possible future uses:
- `[|…|]` at root — **TraitFamily** declarations (sketch: a trait
  family groups related traits that must be impl'd together).
- `{|…|}` at root — already used inside trait body for associated
  consts; at root it could mark a **trait constant block** declaring
  shared constants across all traits in a module.

Sketch-level only. Not proposed for landing.

**Before / after (Option B):**

```aski
;; before (v0.20-era, current proposal)
@[| Iterator
  Item
  (next ~&self {Option self:Item})
|]

;; after
@[Iterator
  Item
  (next ~&self {Option self:Item})]
```

```aski
;; before
@[| Service {$Request{Clone} Sync Clone}
  Response
  Error {Display Debug}
  {| DefaultTimeout Duration Duration:fromMillis(30000) |}
  (call    &self :request $Request {Result self:Response self:Error})
  (timeout &self Duration [Self:DefaultTimeout])
|]

;; after
@[Service {$Request{Clone} Sync Clone}
  Response
  Error {Display Debug}
  {| DefaultTimeout Duration Duration:fromMillis(30000) |}
  (call    &self :request $Request {Result self:Response self:Error})
  (timeout &self Duration [Self:DefaultTimeout])]
```

---

### 4. `.impls` surface

**What's hosted:**
- Module header
- Named trait implementations

One non-module root construct (NamedImpl).

**Current proposal (04-impls.md):**
```
@[ImplName TraitName Target [ *<TraitImplItem> ]]
```

The outer `[…]` was picked in v0.20 because TraitImpl had to be
distinct from Enum `()`, Struct `{}`, Newtype `(||)`, Const `{||}`,
and TraitDecl `[||]`. That competition doesn't exist in `.impls`.

The critique notes: "`.impls` root has no body-position. Can impls use
simpler delimiters?" **Yes, potentially.** But note that the v0.20
`[…]` IS already one of the simpler pairs — it's not a piped-
delimiter form. So the ceremony claim is weaker here than for
`.traits`.

Two sub-questions:

#### Q1. Does impls benefit from a different outer delimiter?

Options for `.impls` root:

**Option A — keep `[…]` (status quo)**

```aski
@[Default Describe Element [
  (describe &self Quality …)
]]
```

The outer `[…]` delimits the NamedImpl; the inner `[…]` delimits the
body. Two different roles for the same delimiter, distinguished by
position (outer is root-level; inner follows the target type and is
the body slot).

Pros: no transition cost; familiar from v0.20.
Cons: two nested `[…]` at root level look visually ambiguous to
scanners (though unambiguous to the parser).

**Option B — switch NamedImpl to `()` at root**

```aski
@(Default Describe Element [
  (describe &self Quality …)
])
```

Pros: shorter outer form; body still `[…]`; clear separation of
"impl shell" vs "impl body."
Cons: `()` at root is also Module's delimiter (position 0 only). Even
though position disambiguates for the parser, a reader seeing a `()`
after the module header has to remember the rule.

**Option C — switch NamedImpl to `{…}` at root**

```aski
@{Default Describe Element [
  (describe &self Quality …)
]}
```

Pros: distinct from Module `()`; distinct from inner body `[…]`.
Cons: `{}` semantically carries "construction / composition" in
design.md §Delimiter-First. NamedImpl is arguably "composition" (a
trait composed with a target), so this isn't a stretch. But `{}` in
`.types` means Struct, and cross-surface consistency of delimiter
semantics is a design value.

**Option D — drop the outer delimiter entirely (reject)**

This would make root items recognizable only by their prefix (`@` or
`ImplName`). That violates §Every Construct Is Delimited. Out.

#### Recommendation for `.impls` root

**Option A (status quo `[…]`)** is the best choice because:
1. The outer/inner `[]` pair gives two bracket roles that the parser
   distinguishes by position (trait-impl shell vs body).
2. `[…]` in design.md §Delimiter-First means "evaluation" and
   TraitImpl-as-evaluation is coherent with that semantic.
3. No transition cost.

The critique's concern applies more to `.traits` (where `[|…|]` is
genuine ceremony) than to `.impls` (where `[…]` is already simple).

#### Q2. Does the NamedImpl internal structure simplify?

The current form is:
```
@[ImplName TraitName Target [ *<TraitImplItem> ]]
```

Four positional slots. First-token-decidable inside `[…]`:
- Position 0: `ImplName` (bare Pascal, no sigil)
- Position 1: `TraitName` (bare Pascal)
- Position 2: `Target` (Type expression, may be `{$Value}` or
  `{Constructor Args}` or bare Pascal)
- Position 3: body `[…]`

That's already minimal. No further simplification without losing
information.

**Note on generics:** The proposal shows generics after the trait name
(`@[Default Container {$Value{Clone}} {RingBuffer $Value} [body]]`).
This introduces a 5-slot form when generics are present. Whether the
generic slot is part of `TraitName` or `Target` (or a separate slot)
is a question for the grammar landing; the review flags it but
doesn't resolve it.

**Freed delimiters in `.impls` root under Option A (status quo):**
- `(||)` — free (no Newtype at root)
- `{||}` — free (no Const at root; inside body, `{|…|}` is still used
  for AssociatedConstImpl)
- `[||]` — free (no TraitDecl at root)

Possible future uses:
- `{|…|}` at root — **module-level impl-activation block**, as the
  proposal already uses inside module headers for activation lists
  (`(App [imports …] {SafeIter DefaultParser})`). This is already
  committed-to in 04-impls.md.
- `[|…|]` at root — **impl-family** or **impl-bundle** declarations
  (sketch-only).

**Before / after for `.impls`:** no change recommended. The surface
is already as simple as it gets without violating axioms.

---

### 5. `.effects` surface

**What's hosted:** Same shape as `.impls`. One non-module root
construct (NamedImpl with an effect-tracking constraint).

**Current proposal (05-effects-and-platforms.md):**
```
@[ImplName TraitName Target [body]]
```

Identical to `.impls`.

**Critique analysis:** Same as `.impls`. No simpler delimiter is
available without violating axioms.

**Recommendation:** **Keep the same grammar as `.impls`.** This is a
feature, not a bug — the extension is what marks it as effect-bearing,
not the syntax. An `.effects` file becomes a `.impls` file by
renaming it (and removing any effect-requiring content); the grammar
stays stable across the rename.

**Freed delimiters:** same as `.impls`.

**Before / after:** no change.

---

### 6. `.test-impls` and `.bench-impls` surfaces

**What's hosted:** Same as `.impls`.

**Analysis:** Same conclusion — grammar stays identical to `.impls`.
The extension does the surface-selection work. No grammar
simplification available.

**Recommendation:** **No change.** Mirror `.impls` exactly.

---

### 7. `.derivations` surface

**What's hosted:**
- Module header
- Derivation rules

A derivation rule binds:
- DerivationName (Pascal)
- TraitName (Pascal)
- TypePattern (a shape-matcher like `{StructOf {$Struct} {AllFields
  Debug}}`)
- Body (TraitImplItem list — impl template)

**Current proposal (06-derivations-and-testing.md):**
```aski
@[| DebugStruct Debug {StructOf {$Struct} {AllFields Debug}}
  (debug &self String [ … ])
|]
```

The proposal uses `[|…|]` explicitly because a derivation "declares
how to make an impl" — visually echoing TraitDecl.

**Critique:** In `.derivations`, the root competes with:
- Module (`()` at position 0)
- DerivationRule (everything else)

Two-alternative root. `[|…|]` is ceremony for the same reason as
`.traits`.

Options:

**Option A — `[|…|]` (status quo)**
Echoes TraitDecl aesthetic; flags "meta" — a rule, not an impl.

**Option B — `[…]`**
Matches impls; visually signals "this is related to impls" (which
derivations synthesize). Simpler form.

**Option C — `(…)`**
Like Option A for `.traits`; short form.

#### Recommendation for `.derivations`

**Option B (`[…]`)** — because derivations *produce* impls, and the
grammar hint should point at impls. The rule body is an impl template
(TraitImplItem list). Using the impl delimiter at the rule level makes
the relationship visible.

**Pending approval from Li.** This is a judgment call; Option A is
also defensible on the "meta" aesthetic.

The derivation rule then reads:
```aski
@[DebugStruct Debug {StructOf {$Struct} {AllFields Debug}} [
  (debug &self String [ … ])
]]
```

Four slots in the `[…]`:
1. DerivationName (Pascal, bare)
2. TraitName (Pascal)
3. TypePattern (a `{…}` shape-matcher — stays in `{}`)
4. Body `[…]`

Identical structure to a NamedImpl except that slot 3 is a type-
pattern instead of a concrete target type. veric's type-checker
distinguishes the two by whether slot 3 is a pattern-matcher (contains
a `$Struct` / `$Enum` / `StructOf` / `EnumOf` / `AllFields` /
`Primitive` constructor) or a concrete type.

That *is* a multi-token lookahead concern (§No Complex Lookahead).
Alternative: use a different outer delimiter to signal "rule, not
impl" at the first token:

**Option D — `[|…|]` at root keeps the derivation-vs-impl distinction
immediate, at the cost of `.traits`-style ceremony.**

If Li values "tell at first token whether this is a rule or an
impl," Option D / A win. If Li values "rules look like impls because
they produce impls," Option B wins.

This review's recommendation is **Option B** on the grounds that
`.derivations` files are already separated by extension — the first-
token signal duplicates information the filename already carries.

**Freed delimiters in `.derivations`:**
- `(||)`, `{||}` — free at root
- Under Option B: `[|…|]` remains free at root

Possible future uses:
- `[|…|]` at root — **meta-derivation** (a rule that generates other
  derivation rules); sketch-only.

**Before / after:**

```aski
;; before (current proposal, Option A)
@[| DebugStruct Debug {StructOf {$Struct} {AllFields Debug}}
  (debug &self String [ … ])
|]

;; after (Option B)
@[DebugStruct Debug {StructOf {$Struct} {AllFields Debug}} [
  (debug &self String [ … ])
]]
```

---

### 8. Platform-impl surfaces (`.native.impls`, `.browser.impls`, etc.)

**What's hosted:** Same as `.impls` — platform-tagged by extension.

**Analysis:** Grammar is identical to `.impls`. Platform is a build-
time dispatch concern, not a grammar concern.

**Recommendation:** **No grammar change.** Same conclusion as
`.effects`, `.test-impls`, `.bench-impls`.

---

### 9. `.async-impls` and `.unsafe-impls` (future)

**What's hosted:** Same as `.impls`. Deferred.

**Recommendation:** **No grammar change.** Same pattern.

---

## Summary table — old vs new grammar (proposed)

| Surface          | v0.20-era form       | Proposed simplification | Recommended? | Notes |
|------------------|----------------------|-------------------------|--------------|-------|
| `.types`         | `()`/`{}`/`(\|\|)`/`{\|\|}` | unchanged           | keep         | All four delimiters are domain-semantic. |
| `.traits`        | `@[\| Name … \|]`    | `@[Name …]` (Opt B)     | **yes, pending Li** | `[\|\|]` drops to `[]`; `[\|\|]` freed for future constructs. |
| `.impls`         | `@[Name T Target […]]` | unchanged             | keep         | Already minimal; `[…]` is the simplest root delimiter it can use. |
| `.effects`       | `@[Name T Target […]]` | unchanged             | keep         | Mirrors `.impls`. Extension carries the effect marker. |
| `.derivations`   | `@[\| Name T Pat … \|]` | `@[Name T Pat […]]` (Opt B) | **yes, pending Li** | Matches `.impls` form; extension carries the "rule" marker. |
| `.test-impls`    | `@[Name T Target […]]` | unchanged             | keep         | Mirrors `.impls`. |
| `.bench-impls`   | `@[Name T Target […]]` | unchanged             | keep         | Mirrors `.impls`. |
| `<platform>.impls` | `@[Name T Target […]]` | unchanged           | keep         | Mirrors `.impls`. |
| `<platform>.effects` | `@[Name T Target […]]` | unchanged         | keep         | Mirrors `.effects`. |
| `.async-impls`   | TBD                  | TBD (follow `.impls`)   | defer        | Same shape expected. |
| `.unsafe-impls`  | TBD                  | TBD (follow `.impls`)   | defer        | Same shape expected. |

**Net effect of simplification:** only two surfaces change from the
current multi-surface proposal — `.traits` and `.derivations`. Both
drop a pipe-pair. The rest of the multi-surface grammar stays exactly
as proposed.

---

## Freed-delimiter inventory

After the proposed simplifications:

| Surface          | Root delimiters used           | Root delimiters free            |
|------------------|---------------------------------|---------------------------------|
| `.types`         | `()` `{}` `(\|\|)` `{\|\|}`     | `[]` `[\|\|]`                   |
| `.traits`        | `()` `[]`                       | `{}` `(\|\|)` `{\|\|}` `[\|\|]` |
| `.impls`         | `()` `[]`                       | `{}` `(\|\|)` `{\|\|}` `[\|\|]` |
| `.effects`       | `()` `[]`                       | `{}` `(\|\|)` `{\|\|}` `[\|\|]` |
| `.derivations`   | `()` `[]`                       | `{}` `(\|\|)` `{\|\|}` `[\|\|]` |
| `.test-impls`    | `()` `[]`                       | `{}` `(\|\|)` `{\|\|}` `[\|\|]` |
| `.bench-impls`   | `()` `[]`                       | `{}` `(\|\|)` `{\|\|}` `[\|\|]` |
| `<plat>.impls`   | `()` `[]`                       | `{}` `(\|\|)` `{\|\|}` `[\|\|]` |
| `<plat>.effects` | `()` `[]`                       | `{}` `(\|\|)` `{\|\|}` `[\|\|]` |

The pattern: **`.types` keeps domain delimiters; every other surface
uses only `()` (Module) + `[]` (the one non-module root construct).**
Four delimiter pairs are freed in every impl-family surface.

This is architecturally meaningful: the "budget" of un-used delimiters
per surface is now a resource that can fund future per-surface
features without cross-surface collision. A future `{|…|}`-at-root
construct in `.impls` (e.g., module-level activation blocks, already
proposed in 04-impls.md) does not steal from anyone else's budget.

---

## Cross-surface consistency table

Body-position delimiters *inside* constructs stay uniform across
surfaces:

| Body position                 | Delimiter | Where it appears |
|-------------------------------|-----------|------------------|
| Method body                   | `[…]`     | `.impls`, `.effects`, `.traits` (default methods), `.derivations` |
| Match                         | `(\|…\|)` | any method body |
| While / infinite loop         | `[\|…\|]` | any method body |
| Iteration                     | `{\|…\|}` | any method body |
| Struct construction           | `{…}`     | any method body |
| Type application              | `{…}`     | any position accepting a Type |
| Associated const (trait/impl) | `{\|…\|}` | `.traits`, `.impls` body |
| View type                     | `{\|…\|}` | method signature |
| Newtype definition            | `(\|…\|)` | `.types` root |
| Or-pattern                    | `[…]`     | match arm |

Uniformity inside bodies is preserved. The proposal simplifies only
the **root delimiters per surface**, not the body-position grammar.

---

## Open questions requiring Li's decision

1. **`.traits` root: `[|…|]` → `[…]`?** (Option B). This is the
   clearest ceremony-drop. Approve / reject / defer.

2. **`.derivations` root: `[|…|]` → `[…]`?** (Option B). Parallel
   choice to `.traits`. If `.traits` is approved and `.derivations` is
   not, the two surfaces look maximally different even though they're
   structurally parallel — which may be a feature ("a derivation is
   not a trait decl") or a confusion ("why does this look like an
   impl and that look like a trait?"). Approve / reject / defer.

3. **`.traits` Option A (`()`) vs Option B (`[…]`)?** Option A is
   shorter but overloads `()` with Module. Option B keeps `()`
   reserved for Module. Pick one.

4. **`.derivations` Option B (`[…]`) vs Option D (`[|…|]` kept for
   "rule" signal)?** Does Li want the first token to distinguish
   "this is a rule, not an impl"? Or is the extension enough?

5. **`.types` Const: keep `{|…|}` or move to `[|…|]`?** Cosmetic. No
   cost to keeping status quo. Only worth raising if Li wants the
   pipes allocation to carry more consistent semantics (e.g., "pipes
   = wrap" as in Newtype, leaving `[|…|]` for "pipes = meta").

6. **Generics slot in NamedImpl (5-slot form):** is it part of
   `TraitName`, part of `Target`, or its own slot? Affects grammar
   tidiness but not delimiter choice.

7. **Should `.impls` and `.effects` look grammatically identical?**
   They do under the current proposal. Li may want a first-token
   distinction (e.g., `.effects` at `{…}` to signal "composition with
   the outside world") — which is cosmetic and breaks the "rename
   .impls to .effects" refactor. Raised for completeness; this review
   recommends against.

---

## Non-recommendations

This review deliberately does **not** propose:

- Dropping the outer delimiter entirely on any surface (violates
  §Every Construct Is Delimited).
- Cross-surface delimiter unification beyond what the proposal
  already has (e.g., "make `.types` use `[…]` too") — that would
  break the domain-semantic encoding of enum/struct/newtype.
- Changing inside-body grammar (loops, matches, iteration, etc.) —
  body-position grammar is shared across surfaces and any change
  there is out of scope for a surface-root review.
- Keywords or soft keywords — axiom 1 forbids them.
- Shorthand / contextual grammar that relies on newlines or
  indentation (§No Newline Significance).

---

## What the review recommends in one sentence

Drop the ceremonial pipes from `.traits` root (`[|…|]` → `[…]`) and
from `.derivations` root (`[|…|]` → `[…]`); leave every other surface
exactly as the multi-surface proposal specifies. **Pending Li's
approval — no existing doc is modified.**

---

*End of review.*
