;; Bridge Proposals — Big Decisions
;; Date: 2026-04-20
;; Part of [../bridge-proposals.md](../bridge-proposals.md).
;;
;; These don't resolve from inferred intent alone. Each requires
;; a real design discussion — the alternatives have different
;; character, not just different spelling. Pick one; implement;
;; write it into design.md.

# Contents

1. [C2 + S10 + N10 — Destructuring binding rule](#c2--s10--n10--destructuring-binding-rule)
2. [S6 — Dynamic dispatch semantics](#s6--dynamic-dispatch-semantics)
3. [S4 — Closure philosophy](#s4--closure-philosophy)

---

## C2 + S10 + N10 — Destructuring binding rule

**The question:** when a match arm destructures a variant's payload or
a struct's fields, what determines the binding name?

design.md §PascalCase and camelCase says camelCase names are "actual
instances of a type." An **inferred-but-not-spec'd strict reading**
of this rule is that a binding's spelling must match its payload
type's Pascal-name lowercased — e.g., a `U32` payload can only bind
as `u32`. The spec does not state this; it's a proposal to make the
case rule's name-identity relationship strict.

Under the strict reading, `( Ok u32 )` is the only valid binding for
`(Ok U32)`. Under a looser reading, the binding could be any
camelCase name (though "Names Are Meaningful" still rules out
pointer names like `val` / `e` / `c`).

For StructVariant patterns the question is harder regardless of which
reading: fields have Pascal names AND types, and those don't always
coincide.

### The structural tension

```aski
@(Shape
  (Circle F64)                                  ;; DataVariant — bare F64 payload
  {Rectangle (@Width F64) (@Height F64)})        ;; StructVariant — two F64 fields
```

For `Circle`, under the strict reading: `( Circle f64 )`. Under a
looser reading, alternative camel names are possible. The strict
reading is the one being considered here because it's the only
reading that makes this a *decidable* problem.

For `Rectangle`, three plausible rules, each with consequences:

### Option A — Pun on field name (camel-of-field)

Binding name is derived from the *field* name, lowercased. Field
`Width` → binding `width`. Always mechanical; no author input; two
F64 fields yield `width` and `height`, not colliding.

```aski
;; Rectangle destructure — pun
( Rectangle { Width Height } )        ;; auto-binds width: F64, height: F64
;; Usage in arm body: width * height
```

- **Pro:** consistent; zero author naming cost; parallels Counter/counter
  at the field level.
- **Pro:** field names are the single source of truth for domain
  meaning — Width means Width regardless of type.
- **Con:** `width` isn't strictly an instance of a type called `Width`
  (F64 is the type). Softens the case rule at StructVariant positions
  specifically.

### Option B — Explicit naming required, type-derived

Each field's binding is camel-of-type-name. Two F64 fields need
distinguishing suffixes or the pattern is rejected.

```aski
( Rectangle { Width f64 Height f64' } )       ;; distinguishing suffix — ugly
```

- **Pro:** case rule holds strictly (binding = instance of payload type).
- **Con:** multi-field-same-type becomes unwriteable without ugly
  workarounds.
- **Verdict:** not viable in practice.

### Option C — Force field-name = type-name at declaration

Every struct field must have a type whose name is the field name. If
Width is an F64 quantity, declare `(| Width F64 |)` (newtype) and
write `(@Width Width)` in the struct.

```aski
(| Width F64 |)
(| Height F64 |)
@{Rectangle (@Width Width) (@Height Height)}

( Rectangle { Width width Height height } )   ;; case rule holds: Width/width
```

- **Pro:** case rule holds strictly everywhere; pun gives the right
  binding because field name IS type name.
- **Pro:** pushes meaningful-naming into the type system — every
  domain concept becomes a newtype.
- **Con:** heavy newtype discipline across every struct with
  primitive fields. Every F64 in a struct has to become its own
  named newtype. Either "lots of little newtypes" or "you can't have
  primitives in structs directly."
- **Con:** contradicts existing spec examples (`{Point (@Horizontal
  F64) (@Vertical F64)}` — would need `Horizontal`/`Vertical`
  newtypes).

### Recommendation

**Option A — pun on field name.** It's the only option that scales to
real code without either ugly bindings (B) or ubiquitous newtypes (C).
The softening of the case rule at StructVariant positions is small and
localized: inside `{ …fields… }` at pattern position, bindings derive
from field names (camelCase-of-Pascal), not from field types. This
reads naturally — you're binding a field *by its role in the struct*,
not by its raw type identity.

### Grammar impact

```synth
;; Pattern.synth (with C2 + A)
// #WildcardPattern#_
// #StructPattern#{ :Type *( :FieldName @binding ) }
// #StructVariantBind#:Variant { *( :FieldName @binding ) }
// #VariantBind#:Variant @binding
// #VariantAlt#[ +:Variant ]
// #VariantMatch#:Variant
// #LiteralPattern#:Literal
```

The `@binding` slot inside `{ :FieldName @binding }` is *optional* —
if omitted, default to camelCase-of-FieldName. Full explicit form
stays available when the author wants to rename.

### Semantic question

Does this "field-name is instance name" softening of the case rule
get written into design.md as a formal exception, or is it a stricter
rule that says "binding inside a field destructure is derived, not
declared"? I'd write it as the latter — it's not softening, it's
"bindings inside field destructures don't exist at the case-rule
level; they're projections of the field role."

### Decision required before landing

1. Which option (A / B / C) is the rule?
2. If A: is the pun automatic (`{ Width Height }` enough) or does the
   author still have to write the binding explicitly (`{ Width width
   Height height }`) with the grammar just validating the name matches?

---

## S6 — Dynamic dispatch semantics

**The syntactic** question (`?{Trait}` as the sigil) is in
`small-decisions.md`. **The semantic** question is much harder:

**How does dyn dispatch work in sema?**

### What Rust's model does

A `&dyn Trait` or `Box<dyn Trait>` is a fat pointer: `(data_ptr,
vtable_ptr)`. The vtable is a compile-time table of function pointers
per-concrete-type-per-trait, laid out in the binary.

### What sema wants to be

Sema is "the bytes ARE the type." No string tags, no pointer chases.
Every value's type is derivable from its byte layout alone (via
domain variant discriminants).

### The conflict

Dyn dispatch inherently *loses* static type identity — the whole point
is "some concrete type I don't know statically, but it satisfies
this trait." That tension doesn't exist in Rust because Rust isn't
claiming binary-level type recovery. Aski/sema does.

### Plausible positions

**Position 1: Dyn trait values carry a type-discriminant byte prefix.**
`?{Iterator Token}` is laid out as `(concrete-type-discriminant,
concrete-payload)`. The discriminant enumerates every concrete type
that impls `Iterator Token` in the program. At call time, the
discriminant selects which concrete impl's method to invoke.

- **Pro:** pure-binary, no vtable pointer.
- **Pro:** domain-variant-as-bytes extends naturally.
- **Con:** requires whole-program analysis to enumerate all impls.
  Breaks separate compilation; the discriminant is program-global.
- **Con:** adding an impl reshuffles every dyn value's byte layout.
  Bad for stability.

**Position 2: Dyn trait values carry a vtable pointer (Rust-style).**
Accept a non-binary component.

- **Pro:** works; matches Rust idiom directly.
- **Con:** violates "no unsized data; pure bytes." Vtable pointers
  aren't domain variants; they're implementation addresses.
- **Con:** sema-the-format loses its core invariant.

**Position 3: No dyn at all; polymorphism via generics + trait bounds only.**
Reject S6 entirely. All trait use is monomorphic; there's no "unknown
concrete type at runtime." Heterogeneous collections become enums of
specific types (`{Vec Shape}` where `Shape` is an enum of every
possible concrete shape).

- **Pro:** sema's invariant holds cleanly; no new machinery.
- **Pro:** monomorphic code is faster and smaller.
- **Con:** loses an expressiveness tier. Plugin/extension systems
  that don't know all impls at compile time can't work.
- **Con:** open design space in the criome (plugins) probably needs
  it eventually.

**Position 4: Dyn, but only in transient runtime values, never in sema binary.**
A `?{Trait}` type is valid at the aski/veric level but doesn't
serialize into sema — it exists only as a transient runtime concept
for dispatch. Serialized world state uses concrete types only.

- **Pro:** preserves sema's invariant (sema binary has no dyn).
- **Pro:** preserves programmer convenience (can still write dyn
  in aski source).
- **Con:** veric needs to enforce "no dyn in serialized fields"
  — a whole-type-tree rule.
- **Con:** adds a second type system tier (sema-level vs runtime-
  level); complicates what "the type" means.

### Decision required

Which position? Each lands on a different axis of the "sema is the
thing" commitment. Position 3 is the cleanest but most restrictive.
Position 1 is an interesting novel approach. Position 2 is the
pragmatic-familiar choice but breaks the thesis. Position 4 is a
compromise.

Until this is decided, the grammar half of S6 (the `?{Trait}` sigil)
can land safely — it's purely syntactic — but no program can *use* a
dyn type until the semantics are settled.

---

## S4 — Closure philosophy

**The question:** does aski get any syntactic sugar for anonymous
callables, or is "named type impl of Callable" the permanent answer?

### What Rust does

```rust
let items: Vec<u32> = nums.iter().map(|x| x + 1).collect();
let filtered: Vec<Task> = tasks.filter(|t| t.priority > threshold).collect();
```

`|x| body` is a one-shot anonymous type with an auto-generated impl of
Fn/FnMut/FnOnce. Cheap syntactically, heavy semantically (the compiler
invents a struct type, captures free vars into fields, generates the
trait impl).

### What aski-with-no-sugar does

Every callable is a named struct with an explicit Callable impl:

```aski
@{Increment (@Amount U32)}

[Callable {U32} U32 Increment [
  (call &self &u32 U32 [u32 + self.Amount])
]]

(items self.nums.map(&Increment {Amount 1}))
```

~7 lines for what was ~1 line in Rust. The upside: every callable has
a name, its captures are explicit fields, reuse is mechanical.

### Positions

**Position A: Permanent no-sugar. Named types always.**
- **Pro:** maximum consistency with "names are meaningful" and "no
  anonymous types." Every callable is inspectable, reusable, tested.
- **Pro:** zero new grammar.
- **Pro:** heavy closure use is a smell — this makes the smell loud.
- **Con:** Rust closure-idiomatic code (iterator pipelines, callback
  APIs) translates to 5-10× more aski source.
- **Con:** in practice, people will write ad-hoc helper types and
  never look at them twice — the "name" is ceremony, not meaning.

**Position B: Inline-closure sugar that desugars to a named type.**
The source writes something like `{|input| body}` (or whatever form);
the parser expands it to a synthetic named type impl during lowering.
The synthetic type gets a grammar-generated name based on position /
body-hash / counter.

- **Pro:** Rust-level ergonomics.
- **Pro:** the desugaring is mechanical; semantically identical to
  position A.
- **Con:** synthetic names violate "names are meaningful" in letter
  (though not spirit — they're internal).
- **Con:** adds a whole delimiter story for closure literals. Every
  sigil/delimiter is allocated; this needs one more.
- **Con:** captures are implicit (what vars does the body close over?);
  have to decide explicit capture syntax or infer.

**Position C: Named shorthand — explicit capture, synthetic name.**
An inline form like `{capturedField expr}` that must list its captures
but generates a synthetic type. Compromise.

```aski
;; Hypothetical syntax — pick your favorite delimiters:
(items self.nums.map({amount 1} &u32 [u32 + amount]))
```

- **Pro:** captures explicit (no surprise behavior).
- **Pro:** terser than A; more disciplined than B.
- **Con:** still introduces a new grammar-level form.
- **Con:** reads weird until you're used to it.

### Decision required

A vs B vs C.

**If A**: nothing else to design — the "clear" answer in clear.md is
final.

**If B or C**: need to design the closure-literal grammar: delimiter
choice, capture syntax, return-type inference or explicit annotation,
trait selection (Callable vs CallableOnce vs CallableMut — aski would
need a family).

This is the only Wave-C item that isn't technically ready — if A,
Wave C is straightforward; if B/C, it's a substantial grammar
expansion with cascading decisions.

**Recommendation:** A, provisionally. Confirm by writing a few
typical Rust closure-heavy programs in aski-named-type style and
seeing if the verbosity is tolerable. If yes, lock A. If the
programs become unmaintainable, revisit — but A being the default
means we've shipped a working language without B/C first.

---

# Decision dependencies

| Decision | Blocks | Unblocks |
|----------|--------|----------|
| C2 binding rule (A/B/C) | struct destructuring landing, iteration-with-destructure | full Wave B |
| S6 dyn semantics (1/2/3/4) | any program using `?{Trait}` types, trait objects as values | trait-object-dependent code |
| S4 closure philosophy (A/B/C) | higher-order API idioms | Rust closure-heavy transliteration |

These are independent — can be discussed and decided separately, in
any order. C2 is the most urgent because Wave B lands without it.
S6 is the most architecturally consequential. S4 is the most
ergonomically visible.
