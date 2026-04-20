# Aski Design — Established Constraints

These are settled design decisions. They are not open for
reconsideration. New syntax, new dialects, and new engine work
must conform to all of them.


## Sema Is the Thing

Sema is a universal typed binary format. It IS the thing.
No strings. No unsized data. Domain variants as bytes.
Everything else exists to serve sema.

**Only semac produces sema.** Everything upstream (askicc,
askic) produces rkyv-serialized data that still has strings.
It becomes sema when semac resolves all strings to domain
variants. If it has unsized data, it is not sema.

Aski is one notation for specifying sema — a text-based,
human-readable stepping stone. Aski will eventually be replaced
by better ways to represent sema for human consumption.

semac (the sema compiler) is the permanent backend. It reads
rkyv data and produces sema + Rust. Any tool that produces
valid rkyv parse trees can feed semac.

The criome is the endgoal — the runtime that hosts sema worlds.

Do not treat aski as the center of the system. Sema is the
center. Aski is one path to it.


## Domain = Any Data Definition

A **domain** is the overarching concept for any data definition.
Enum, struct, and newtype are three forms of domain:

- **Enum** `()` — one-of. `(Element Fire Earth Air Water)`
- **Struct** `{}` — all-of. `{Point (Horizontal F64) (Vertical F64)}`
- **Newtype** `(||)` — wraps one type. `(| Counter U32 |)`

The delimiter determines the form. All three are domains.
Enums and structs are two sides of the same thing — the two
shapes that composed data takes. Newtypes are transparent
wrappers — the pipes connote "one thing wrapped."


## Surfaces (v0.20)

Aski has five surfaces, each a grammar family for a specific
file kind:

- **core** (`.core`) — pure type definitions. What corec eats.
- **aski** (`.aski`) — modules, libraries. What askic parses.
- **synth** (`.synth`) — grammar definitions. What askicc parses.
- **exec** (`.exec`) — executable programs. What askic runs.
- **rfi** (`.rfi`) — Rust foreign interface declarations (v0.20).

Each surface has its own `Root.synth` and its own dialect
tree. Surfaces don't share `.synth` files directly — they
reference across surfaces via `<:surface:Name>` syntax. This
keeps surfaces independent while avoiding duplication.

The exec surface is minimal (just Root and Module) —
everything else is referenced from aski. Core similarly
references aski for Type expressions.


## Every Construct Is Delimited (v0.19)

No bare multi-item sequences. Every construct at every level
has explicit delimiters so the engine always knows what it's
reading before entering.

Aski root delimiter allocation (v0.20):

| Delimiter | Construct |
|-----------|-----------|
| `()` | Module (first), Enum |
| `[]` | TraitImpl |
| `{}` | Struct |
| `{||}` | Const |
| `(||)` | Newtype |
| `[||]` | **TraitDecl** (v0.20; was FFI) |

Every root construct has a unique opening token — first-token
decidable. RFI moved to its own `.rfi` surface; see §Surfaces.
Process moved to the exec surface. No bare newtypes. No
fallback rules. The delimiter identifies the construct; the
`@LabelKind` after it reads the name.


## Everything Is a Type

There are no variables in aski. What other languages call a
"variable declaration" is a **local type declaration**.

`(counter U32:new(0))` declares a local type `counter` wrapping
a `U32` instance. The `()` delimiter at statement position is
the local-declaration form. The camelCase name marks it as an
actual instance of a type (vs. compile-time structural Pascal
types).

Locals are camelCase — they are actual instances of a type. The
types they wrap, and types they reference, are PascalCase.
`counter` (camel) is an instance of `Counter` (Pascal); the two
names are one entity viewed as instance vs type.


## Names Are Meaningful

There are no pointer names. No `T`, `X`, `A`, `B`. Every name
describes what the thing IS.

Type parameters use the `$` sigil. The name after `$` is the
semantic identity of the parameter:

- `$Value` — the broadest category of what something contains
- `$Output` — what a computation produces
- `$Failure` — what goes wrong
- `${Clone Debug}` — bounds-as-name (no semantic name; bound set
  inside `{}` identifies the parameter)

Two different things always have different names. `$LeftValue`
and `$RightValue` are different even if they share qualities.


## Delimiter-First

Aski uses six delimiter pairs. The opening delimiter comes first,
then position derives meaning. There are no keywords.

Delimiter semantics (v0.19):
- `()` — categorical single things (Module, Enum, TraitDecl, local decl, typed field, match arm, call args)
- `[]` — **evaluation** (block, InlineEval, TraitImpl, ExprStmt, or-pattern)
- `{}` — **construction / composition** (Struct def, StructConstruct, type application, generic slot, bound set)
- `(| |)` — Match (body) / Newtype (root)
- `[| |]` — Loop / FFI
- `{| |}` — Iteration / Const / View type

Type application uses `{}`:

```aski
{Vec Element}               ;; not Vec<Element>
{Option $Value}             ;; not Option<T>
{Result $Output $Failure}   ;; not Result<T, E>
```

`<>` is NOT an aski delimiter. It appears only in synth files
as dialect references (`<Type>`, `<Body>`), which are parser
instructions, not source syntax.


## Position Defines Meaning

The same delimiter means different things in different contexts.
Synth dialects define what each position means. There are no
keywords or special tokens to disambiguate — the dialect's
parse position is the sole authority.

`()` at root level = enum or module declaration.
`()` inside a struct = typed field.
`()` inside a body = arguments.

The parser always knows which dialect is active, so there is
never ambiguity.


## No Newline Significance

Newlines are never significant in any aski-family language
(aski, synth, nexus, and any future members). Whitespace
(including newlines) is only a token separator. Parsing is
purely token-based.


## Synth Drives Parsing

Every syntactic construct is defined by a synth dialect. If
something is "handled by the engine" rather than by a synth
rule, that is a design flaw to be fixed.


## No Opaque Strings

Every value in the data-tree is structured. If a name or type
is stored as a flat string, that is a bug. Names are typed
domain variants. Types are structured node trees.

In sema, string fields are transitional — every string is a
placeholder for a domain composition not yet specified. As the
ontology grows, strings collapse to domain variants.


## Scopes Are a Tree

Names live in a scope tree, not a flat global registry. Every
syntactic nesting level (module, enum, struct, method, block,
match arm, loop) creates a scope. The same name in different
scopes = different things.

Recursive nesting (`(| |)` for nested enums, `{| |}` for
nested structs) creates arbitrarily deep scope chains. Name
resolution walks up from the current scope toward root. First
match wins (shadowing).

Nested type declarations can shadow outer names. An inner
`State` inside `Engine` is a different type from an outer
`State` — the scope tree distinguishes them. Access the inner
one through the parent: `Engine.State`.

Exports only reference names declared at the module's own
scope level. A name buried inside a nested definition is not
directly exportable — it is reachable through its parent.

In bodies, a bare camelCase name (`counter`, `result`) references
a local in scope. To declare a new local, use `(name …)` at
statement position. Shadowing the same name twice in one scope
is not possible — use a different name.


## Domains Come From Data

Writing an enum or struct by hand in Rust instead of defining
it in `.aski` is always wrong. The `.aski` definition IS the
source of truth. The bootstrap compiler derives all types from
the data — they are never hand-maintained.

DialectKind is derived from `.synth` filenames (PascalCase
files = variants). NodeKind variants map to synth rules.
Name classification is defined in `core/name.aski`.


## PascalCase and camelCase

**PascalCase = compile-time structural things** — types, enums,
structs, newtypes, traits, variants, fields, type parameters,
modules, consts. The *shapes* — the named pieces of the program's
structure.

**camelCase = actual instances of a type** — local declarations,
local references, methods invoked against an instance, the `self`
keyword referring to the current instance, match-arm bindings
holding a variant payload. The *this-one-right-here* of a given
shape.

The two are related by identity: `F64` is the type; `f64` is an
instance of it. `Counter` is the struct; `counter` is one Counter.
The case of the first letter is how the parser knows which kind of
thing a name refers to.

This is not convention — it is syntax. The parser distinguishes
PascalCase from camelCase tokens and dispatches differently.

Historical note: the current form was established in v0.19 with
the trait flip (traits moved from camel to Pascal — they are
categories of types, noun-like) and the instance flip (locals
moved to camelCase — they are instances, not structural entities).
The `@` sigil was retired as an instance marker at the same time;
locals are declared inside `()` at statement position and
referenced bare.


## Mutable Is Marked

`~` marks mutability — always a modifier, never standalone
meaning. It composes with the thing being made mutable:

- `~counter` — mutable local binding (at declaration)
- `~&self` — mutable borrow of self (combines `~` and `&`)
- `~counter.set(x)` — mutation statement (mutation marker on
  a method call)

Immutability is the default. Mutation is always visible at the
declaration site.


## We Compile to Rust

Aski compiles to Rust via sema. Do not design constructs that
Rust cannot express. No higher-kinded types. No dependent types
(yet). The bootstrap engine is Rust. The self-hosted engine
will be written in aski but still compiles to Rust — Rust is
the compilation target, not the implementation language.


## Instances Are Owned

Once a `(name …)` declaration introduces a local, that name is
owned in its scope and cannot be re-declared. If you need a new
value, declare a new name. Local declarations are one-shot
commitments.

This aligns with move-by-default semantics. An instance
declaration is not an assignment — it is the creation of a
thing. Things don't get replaced; new things are created.


## Text Is Flat, Trees Come From the Compiler

Text is a left-to-right, top-to-bottom medium. Every
text-based language — aski, synth, or anything else — is
written as a flat sequence of tokens. An aski file lists
definitions one after another. A synth file lists rules one
after another. This is not a limitation to work around. It
is the nature of text.

Trees are what the compiler constructs from the flat input.
The builder takes a flat sequence of matched tokens and
produces a structured domain tree (modules containing enums,
structs, traits). The grammar rules stay flat because the
source text is flat. Do not attempt to make grammars
hierarchical — structure lives in the compiler, not the
grammar.


## Data-Tree IS the Parser State

Synth files define patterns — what tokens to match. Nothing
more. The data-tree built by askicc IS the parsing state
machine. When the parser encounters ambiguity, the answer
comes from the data-tree's context, not from grammar
complexity.


## No Complex Lookahead

Aski's grammar is first-token-decidable at every choice point.
When new features would require multi-token lookahead or
backtracking to parse, the escape valve is **creating a new DSL
(surface)** for that domain — not adding parser logic.

Examples of the DSL-creation pattern:
- **exec** (`.exec`) — executable programs, separate from module-
  oriented `.aski`. Process-level constructs don't complicate
  the aski grammar.
- **rfi** (`.rfi`, v0.20) — Rust foreign interface declarations.
  Moved to their own surface when `[||]` was
  reclaimed for TraitDecl; gives FFI room to grow with
  target-language specifiers and calling conventions.

Every dialect's parser stays locally decidable. Every grammar
rule has a unique opening token within its dialect.


## Visibility (v0.20)

The `@` sigil prefix marks public. Default is private. Applies
uniformly at every declaration point and field slot:

```aski
@(Element Fire Earth Air Water)              ;; public enum
(InternalEnum Ready Done)                     ;; private enum

@{Point (@Horizontal F64) (@Vertical F64)}    ;; public struct, public fields
@{Counter (@Count U32) (cache U32)}            ;; Count public, cache private
{SecretData (key String)}                      ;; private struct

@(| Counter @U32 |)                            ;; public newtype, wrapped public (transparent)
@(| OpaqueCount U32 |)                          ;; public newtype, wrapped private (opaque)
```

Module exports list (v0.19) retired — visibility is declaration-
local. veric resolves "is name X visible from outside?" by
looking at the declaration's `@` prefix.

Rules:
- **Declarations:** Enum, Struct, Newtype, Const, TraitDecl, TraitImpl
  each take optional `@` prefix for public.
- **Struct fields:** `(@FieldName Type)` public; `(FieldName Type)` private.
- **Self-typed fields:** `@FieldName` public; `FieldName` private.
- **Newtype wrapped type:** `@Type` inside `(| Name @Type |)` = wrapped public;
  bare type = wrapped private (opaque).
- **Module:** module itself is always "visible" within its file; the
  `.aski` file IS the module. No `@` on the Module line.


## No Tuples

Aski does not have tuples like Rust's `(A, B)`. Positional
nameless grouping betrays "Names Are Meaningful" — if you have
two values that need to travel together, they have roles, and
those roles deserve names.

For multi-value returns, define a struct:

```aski
{DivResult (Quotient I64) (Remainder I64)}

(Math [(divmod &self &divisor I64 DivResult)])
```

Reads clearly at every use site:

```aski
(result self.divmod(divisor))
result.Quotient + result.Remainder     ;; meaningful
```

vs what a tuple would give:
```aski
result.0 + result.1                     ;; what's .0? what's .1?
```

### Self-typed struct fields make this terse

Where a field name IS the type name, aski's self-typed form
collapses the declaration to one word:

```aski
;; verbose (generic field names)
{Person (Name String) (Age U32) (Greeting String)}

;; self-typed — field IS the type (v0.19)
{Person Name Age Greeting}              ;; assumes Name, Age, Greeting are defined types
```

Self-typed fields remove the type-declaration cost for meaningful
fields where name = type. Combined with struct-for-grouping, the
"tuples would be shorter" argument loses most of its force.

### What you give up

Ad-hoc pair/triple grouping. Aski forces naming for every group.
This is a deliberate cost that buys clarity at every use site.


## No Native Infinite-Loop Form

Aski's loop delimiter `[| <Expr> <Body> |]` requires a
condition. For infinite loops, write `while true`:

```aski
[| true
  [handleEvent]
  [updateState]
|]
```

### Why no distinct `loop {}` form

All six delimiter pairs are allocated (`()`, `[]`, `{}`,
`(||)`, `[||]`, `{||}`). Adding a dedicated infinite-loop form
would require either:

- Stealing a delimiter from another construct (costs grammar clarity)
- A distinguishing marker inside `[||]` (sigil noise)
- A contextual rule like "first-token-is-statement → infinite" (works but adds parser state)

The cost-benefit doesn't justify it: infinite loops are a
genuine pattern (event loops, servers, retry-until-success)
but not frequent enough in aski's domain-modeling focus to
earn their own syntactic weight.

### Common infinite-loop uses

- **Event/server loops** — `[| true [event self.receive] [self.handle(event)] |]`
- **Retry until success** — `[| true (attempt self.tryConnect) (| attempt …arm for Ok, arm for Err |) |]`
- **Polling watchers** — `[| true [change self.waitForChange] [self.process(change)] |]`
- **State machine drivers** — exit via `^` early return when terminal state reached.

### Fallback for agents / contributors

If an agent reads this and is tempted to "fix" the missing
infinite-loop form: don't. `while true` is the intended pattern.
The cost is one extra token at declaration; the gain is zero
grammar expansion. This is a deliberate language decision, not
a gap to fill.


## Defined Inputs and Outputs

Every pipeline component has defined inputs and defined
outputs. A component can take multiple inputs of different
kinds and produce multiple outputs. What matters is that
every input and output is explicit and known.


## No Shortcuts in Compiler Work

Never propose raw text passthrough, "skip for now" stubs,
post-processing scripts, or partial grammars. Self-hosting
requires the full grammar — the same grammar that parses also
reconstructs (bidirectional). Shortcuts break round-tripping
from sema.

When hitting a language limitation, stop and discuss the
language construct needed. Don't work around it — extend the
language properly.


## No Hand-Maintained Lists

Every list of names, enum variants, or dispatch tables in
source code is a bug. If a domain changes, hand lists silently
break. Types are derived from .aski data, never hand-written.


## Pure Binary Means Pure Binary

When the project says "binary," it means actual byte values.
Not hex strings. Not JSON arrays of integers. Not text
representations of any kind. The bytes ARE the protocol.


## .sema Is the Canonical Format

`.sema` binary is the canonical representation. Everything else
is a projection. .aski is a text projection. .rs is a code
projection. .aski-table.sema is a name projection.


## No Generated Rust Outside corec, domainc, and semac

Only three places in the pipeline generate Rust source code:
- **corec** — generates Rust with rkyv derives from .aski
- **domainc** — generates per-program domain crate from rkyv parse tree
- **semac** — the permanent backend, turns sema into Rust

askicc does NOT generate Rust. It produces rkyv data that
gets embedded in the askic binary at build time.


## No Free Functions

All Rust in the sema ecosystem uses methods on types (traits
+ impls). No free functions. `main` is the only exception.

All Rust will eventually be rewritten in aski, which uses
methods (traits, impls). Free functions have no aski equivalent.


## Module Names Drop the -aski Suffix

Repo name minus `-aski` suffix = module name. `astro-aski` →
module `astro`. The `-aski` suffix says what language the repo
is written in, not what it's about.


## Astrology, Not Astronomy

The astrological types (Sign, Planet, House, Dignity) come
from astrological tradition — Hellenistic, Vedic, medieval.
Never use "astronomical" to describe these. The traditions are
Ptolemy, Valens, Brennan, Lilly — astrologers, not astronomers.


## Validate Terms Against the Ontology

Before introducing a new term or concept, check it against the
current project ontology. Don't port old terminology without
verifying it's still active. When in doubt, use "Criome" as
the universal framing term, not "Sema" or "Sajban."


## Generics

### Core Principles

1. **Names are meaningful.** No pointer names like T, X, A, B. The
   name describes what the thing IS.

2. **Two different things have different names.** `$Left` and `$Right`
   are different even if they share qualities. Name IS identity.

3. **Bounds ARE names (optionally).** `${Clone Debug}` — bounds alone
   can identify a parameter. `$Value{Clone Debug}` adds a semantic
   name. The `&` combinator retires; `{}` groups bounds.

4. **Everything is structured.** No opaque strings, no engine escapes.
   Types are synth-driven, producing structured nodes.

5. **Delimiter-first.** Type application is `{Constructor Arg}`
   (v0.19; was `[…]`). `<>` is not an aski delimiter.

6. **We compile to Rust.** No higher-kinded types. Kinds are implicit
   (count $ slots in a definition).

7. **Everything synth-driven.** Types have their own dialect (Type.synth).


### What Type Parameters ARE

A type parameter is a **type-level function argument**. A type
constructor (Vec, Option, Result) is a function from types to types.
Application yields a concrete type.

In aski, the parameter's name describes its semantic role. There are
no meaningless placeholder variables.


### Type Syntax

#### Simple type

```aski
Element                      ;; a bare type name
U32                          ;; a primitive
```

#### Type application — {} delimiter (v0.19)

```aski
{Vec Element}                ;; Vec applied to Element
{Option Element}             ;; Option applied to Element
{Result Element String}      ;; two parameters
{Vec {Option Element}}       ;; nested
{Map String {Vec Element}}   ;; composed
```

Note: v0.18 used `[…]` for type application. v0.19 moves it to
`{…}` — construction, not evaluation. `[…]` becomes purely the
evaluation delimiter (block, InlineEval, TraitImpl, ExprStmt,
or-pattern).

#### Type parameter — $ sigil (v0.19)

```aski
$Value                       ;; bare named slot
$Value{Clone Debug}          ;; bounded (bound set in {})
$Value{Clone Debug Display}  ;; multiple bounds (space-separated)
${Clone Debug}               ;; bounds-as-name (no semantic name)
```

No `&` combinator — `{}` is the bound-set delimiter; space between
trait refs is conjunction.


### Enum Definitions with Parameters (v0.19)

Generic slot in `{}` after the definition name.

#### One parameter

```rust
enum Option<T> { Some(T), None }
```

```aski
(Option {$Value} (Some $Value) None)
```

#### Two parameters (different roles)

```rust
enum Result<T, E> { Ok(T), Err(E) }
```

```aski
(Result {$Output $Failure} (Ok $Output) (Err $Failure))
```

#### Two parameters (same quality, different identity)

```rust
struct Pair<A, B> { left: A, right: B }
```

```aski
{Pair {$Left $Right} (LeftValue $Left) (RightValue $Right)}
```


### Struct Fields

#### Typed field — () delimiter

```aski
{Container {$Value} (Items {Vec $Value}) (Count U32)}
```

#### Self-typed field — bare name (encouraged)

```aski
{Drawing (Shapes {Vec Shape}) Name}
```

`Name` is self-typed: field name IS the type.


### Recursive Nesting

#### Nested enum inside domain or struct — (| |)

```aski
(Shape
  (Circle F64)
  (Compound {Vec Shape})
  (| Status Active Inactive Done |))
```

#### Nested struct inside domain or struct — {| |}

```aski
{Drawing
  (Shapes {Vec Shape})
  Name
  {| Config (Timeout U32) (Retries U32) |}}
```


### Synth Dialects for Generics (v0.19)

#### Type.synth

```synth
;; borrowed type: &{Vec Element}
// #BorrowedType#_&_?<Origin>?<ViewType>{ <TypeApplication> }

;; mutable borrow: ~&{Vec Element}
// #MutBorrowedType#_~__&_?<Origin>?<ViewType>{ <TypeApplication> }

;; applied type: {Vec Element}, {Option $Value}
// #AppliedType#{ <TypeApplication> }

;; type parameter reference: $Value, $Value{Clone Debug}
// #GenericParamType#<GenericParam>

;; simple type reference: Element, U32
// #Named#:Type
```

#### TypeApplication.synth

```synth
:Constructor +<Type>
```

#### GenericParam.synth

```synth
;; bounded: $Value{Clone Debug}
// #BoundedParam#_$_@Role { +:Bound }

;; bare: $Value
// _$_@Role
```


### Kinds (Implicit)

Kind is inferred from the enum definition:

```aski
(Option {$Value} (Some $Value) None)     ;; 1 slot: Type -> Type
(Result {$Output $Failure} ...)          ;; 2 slots: Type -> Type -> Type
(Element Fire Earth Air Water)            ;; 0 slots: Type (concrete)
```

No explicit kind annotations needed.


## Origins — Place-Based Lifetime Annotations

The `'` sigil marks an **origin**: the place from which a borrow's
loan came. Aski adopts the user-facing form of Rust's place-based
lifetime syntax (Polonius + view-types roadmap) before Rust
stabilizes it, so that parse-tree shape is fixed early and
semantic enforcement can be layered on later without breaking
grammar.

### Binding model (v0.19)

Three sigils for source-read identifier roles (synth-level):

| Sigil | Binding   | Role                                    |
|-------|-----------|-----------------------------------------|
| `@`   | Declare   | declares a new named slot (synth only — aski source uses position)  |
| `:`   | Reference | names an existing label kind (synth only — in aski source `:` is path) |
| `'`   | Origin    | names a place for lifetime tracking     |

`'Place` always refers to a place that exists in scope — a
parameter, local, or field path from one of those.

### Three origin forms (v0.19)

```aski
;; 1. Simple place — binding or parameter name
&'Map self
~&'Buffer counter U32

;; 2. Field path — any depth
&'self.Inner ref String
~&'self.Inner.Deeper node

;; 3. Union — borrow originated at any of these places
&'(Left Right) node Tree
```

### View types — partial-field borrows

The `{| Field ... |}` delim after a borrow restricts the view to
exactly the named fields. Other fields remain free for concurrent
borrows to hold.

```aski
;; shared view: read-only, only these fields visible
(observe &self {| Name Count |} String)

;; mutable view: writable, only this field visible;
;; a concurrent shared borrow may still hold the other fields
(tick ~&self {| Counter |} U32)
```

### Grammar position

Origins and view types both attach to a borrow sigil (`&` or
`~&`). Order: borrow, then optional origin, then optional view,
then instance name. All pieces are positional — no commas, no
syntactic noise.

```
&'Map {| Count |} self          ;; origin + view + self
&'Map foo Type                   ;; origin + named param
foo Type                         ;; no borrow — no origin, no view
```

See also:
- `aski/Origin.synth` — `'Place`, `'Place.Field`, `'(A B)` forms
- `aski/FieldPath.synth` — recursive `.Field` chain
- `aski/ViewType.synth` — `{| Field ... |}` shape
- `aski/Param.synth` — where origins + views plug into params

### Semantic status

v0.18 **accepts the syntax into the parse tree**. Origins and
view types are captured as typed nodes (`PlaceRef`, `PlacePath`,
`PlaceUnion`, `ViewType`), but veric/semac do not yet enforce
origin correctness. Enforcement arrives with rsc (Rust
projection) once Rust's Polonius/view-types stabilize enough
for aski to emit correct Rust. Until then, writing origins
is optional documentation.

### Future lifetime tests

When semantic enforcement lands, tests verify:
- origin propagation across function boundaries
- that view-type fields are exactly the set accessible through the borrow
- that concurrent view borrows with disjoint field sets type-check
- that aski's `:` / `~@` / `'` compile to Rust `&` / `&mut` / `'place`
  in rsc output.
