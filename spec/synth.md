# Synth — The Grammar Specification Language

Synth is the language that defines aski's grammar. Every
syntactic construct in aski is specified by a synth dialect
file. The synth files ARE the grammar — there is no separate
grammar specification.

Synth is part of the aski language family. No newline
significance. Whitespace is only a token separator.


## Space Is Significant (Between Non-Delimiter Items)

Space in a synth rule between non-delimiter items means
space is allowed in source. No space means tokens must be
adjacent.

```synth
@Type / @Variant          ;; matches: Element / Fire
@Type/@Variant            ;; matches: Element/Fire
@Type / @Variant          ;; does NOT match: Element/Fire
```

The engine checks token spans to enforce adjacency.
`Element/Fire` — the `/` starts where `Element` ends.
`Element / Fire` — there are gaps between spans.


## Space After Opening / Before Closing Delimiters Is a No-op

Whitespace (including newlines) after an opening delimiter
and before a closing delimiter is non-significant in both
synth and aski source. These forms are all equivalent:

```synth
(@Name <Type>)
( @Name <Type> )
(
  @Name
  <Type>
)
```

In aski source, the same rule applies:

```aski
(Element Fire Earth Air Water)
( Element Fire Earth Air Water )
(
  Element
  Fire Earth
  Air Water
)
```

Dense formatting and multi-line formatting are always valid.
The "pretty" form with breathing room around delimiter
contents is the recommended style — synth syntax is dense
and the extra space aids readability.

Adjacency tracking only applies to items NOT adjacent to
delimiters: `@Type/@Variant` stays adjacent; `( @Type @Variant )`
works because the space is next to delimiters, not between
items themselves.


## Surfaces (v0.20)

Synth is organized into five **surfaces**, each a dialect
family with its own root rule and rkyv artifact. Each
surface's `.synth` files live in their own subdirectory.

| Surface | Purpose | Consumer | Extension |
|---------|---------|----------|-----------|
| core | Pure type definitions | corec | .core |
| aski | Modules and libraries | askic | .aski |
| synth | Grammar self-description | tooling | .synth |
| exec | Executable programs | askic | .exec |
| rfi | Rust foreign interface declarations | askic | .rfi |

```
askicc/source/
  core/    — Root, Enum, Struct (no module header)
  aski/    — full grammar (module, enums, traits, trait impls, etc.)
  synth/   — synth describing synth (self-description)
  exec/    — Root + Module only (refs aski via <:aski:...>)
  rfi/     — Root only (refs aski for Signature)
```

askicc produces ONE combined rkyv containing every dialect
from every DSL: `generated/dsls.rkyv`. Each Dialect inside
carries its SurfaceKind. askic dispatches on file extension
to pick which surface's Root to enter, then looks up
(SurfaceKind, DialectKind) in one flat table for every
dialect ref (same-surface or cross-surface).

Terminology:
- **DSL** — one of the five surfaces (core, aski, synth, exec, rfi).
  Each is a complete grammar for one file type.
- **Dialect** — one `.synth` file within a DSL (Body, Statement,
  Expr, …). Its filename becomes a DialectKind variant.
- **dsls.rkyv** — the one rkyv bundling all five DSLs'
  dialects, surface-tagged for dispatch.


## File Structure

Each `.synth` file defines one dialect. The filename (without
extension) IS the dialect name and becomes a DialectKind
variant.

```
Root.synth       → DialectKind::Root
Enum.synth       → DialectKind::Enum
ExprAtom.synth   → DialectKind::ExprAtom
```

A synth file contains **rules**. Rules are either:
- **Sequential** — a sequence of items matched in order
- **Ordered choice** — alternatives tried in order, prefixed
  with `//`


## Ordered Choice (`//`)

Lines starting with `//` form an ordered choice group.
The engine tries each alternative top to bottom, taking the
first one that matches:

```synth
// @Variant
// (@Variant <Type>)
// {@Variant <Struct>}
```

Order matters — put more specific patterns before general
ones.


## Items

Each synth rule is a sequence of **items**. Items are
space-separated in the synth file:

### Declare — `@Name` or `@name`

Reads a token and declares it in the current scope.
PascalCase `@Name` reads a PascalCase identifier.
camelCase `@name` reads a camelCase identifier.

```synth
@Enum            ;; reads a PascalCase name, declares it
@trait           ;; reads a camelCase name, declares it
```

### Reference — `:Name` or `:name`

Reads a token that must name something already in scope.
Casing rules match `@`.

### Origin — `'Name`

Reads a place-name identifier for lifetime tracking. Third sibling
to Declare (`@`) and Reference (`:`). See design.md §Origins.

```synth
'PlaceName       ;; reads a PascalCase place (parameter/binding/field)
```

Labels carry a `Binding` enum (`Declare` / `Reference` / `Origin`),
a `LabelKind` (field role — `ModuleName`, `PlaceName`, `Instance`, …),
and a `Casing` (`Pascal` / `Camel`). All three are orthogonal.

### Tag — `#Name#`

Names the TYPE of the output node. Does NOT read a source
token. Every delimited construct and every alternative gets
exactly one tag.

```synth
// <ExprAnd> #BinOr#|| <ExprOr>    ;; || is the operator; #BinOr# names the output type
// #InlineEval#[ <Body> ]           ;; the bracket delimiter IS the construct
// #EarlyReturn#^<Expr>             ;; ^ is a literal sigil
// *#BareVariant#@VariantName       ;; tag + label: "output is BareVariant, reading a VariantName"
```

Every delimiter at every level should be tagged. The engine
reads `#Tag#` and knows the output variant before entering
the delimiter — no guessing, no backtracking.

`#Tag#` and `@Label` are **orthogonal**:

- `#Tag#` resolves to a `TagKind` — "what TYPE of output node
  is this?"
- `@Label` / `:Label` resolve to a `LabelKind` — "what ROLE
  does this source-read identifier play?"

They live in separate enums. A node has exactly one tag (its
type) and zero-or-more labelled fields (source-read
identifiers bound to roles). Verified across all .synth
files: no identifier is used as both a tag and a label.


### Dialect Reference — `<Name>` or `<:surface:Name>`

Pushes into another dialect to parse a sub-construct.

Bare `<Name>` refers to a dialect in the CURRENT surface:

```synth
<Enum>           ;; parse using same-surface Enum.synth
<Type>           ;; parse using same-surface Type.synth
```

Cross-surface refs use `<:surface:Name>`:

```synth
<:aski:Statement>   ;; use aski surface's Statement dialect
<:aski:Type>        ;; use aski surface's Type dialect
```

The exec surface uses this to reference aski's expression
and statement grammar without duplication. Core surface
uses this to reference aski's Type dialect for type
expressions inside fields.

### Literal Escape — `_X_`

Matches a literal token that would otherwise conflict with
synth syntax. The underscores delimit the token:

```synth
_@_              ;; match a literal @ token in source
_~@_             ;; match literal ~ then @ tokens
_$_              ;; match a literal $ token
_^_              ;; match a literal ^ token
_*_              ;; match a literal * (not synth cardinality)
_+_              ;; match a literal + (not synth cardinality)
_?_              ;; match a literal ? (not synth cardinality)
```

Only needed for characters that have synth-level meaning:
`@ $ ~ ^ # * + ?`. All other tokens (operators, delimiters,
identifiers) can appear bare.

### Bare Tokens

Tokens that don't conflict with synth syntax appear directly:

```synth
||               ;; match logical-or operator
&&               ;; match logical-and operator
==               ;; match equality operator
-                ;; match minus operator
%                ;; match modulo operator
/                ;; match slash token
.                ;; match dot token
```

### Delimiter Matching

Delimiters in synth match their aski source delimiters.
Content between them is parsed by the specified dialect:

```synth
(<Expr>)         ;; match ( ... ) with Expr inside
[<Body>]         ;; match [ ... ] with Body inside
{<Struct>}       ;; match { ... } with Struct inside
(|<Match>|)      ;; match (| ... |) with Match inside
{|<Loop>|}       ;; match {| ... |} with Loop inside
[|<Expr>|]       ;; match [| ... |] with Expr inside
```

### Cardinality Markers

Applied to the SINGLE item immediately after them:

```synth
+<Param>         ;; one or more Param
*@Variant        ;; zero or more Variant declarations
?<Type>          ;; optional Type
```

Cardinality applies to ONE item. For multi-item repetition,
use `//` ordered choice with recursion:

```synth
;; WRONG — no grouping syntax exists
;; <ExprAnd> *(_||_ <ExprAnd>)

;; RIGHT — recursion via ordered choice
// <ExprAnd> || <ExprOr>
// <ExprAnd>
```

### String Literal

Matches a quoted string token in source:

```synth
"literal"        ;; match a string literal token
```


## Example: Root.synth

```synth
(@Module <Module>)
// *(@Enum <Enum>)
// *(@trait <TraitDecl>)
// *[@trait <TraitImpl>]
// *{@Struct <Struct>}
// *{|@Const <Type> @Literal|}
// *(|@Rfi <Rfi>|)
// ?[|<Process>|]
// *@Newtype <Type>
```

The first rule is sequential: match `(`, parse Module
inside, match `)`. Required, runs once.

The remaining rules are an ordered choice with `*` (zero
or more). For each top-level construct after the module,
try each alternative until one matches.


## Synth Rules Are Flat

See "Text Is Flat, Trees Come From the Compiler" in
design.md. Synth rules are sequences of items matched in
source order. The builder constructs the tree.


## Synth Does NOT Handle

- **Grouping for repetition** — `()` in synth always means
  "match paren delimiter." Use `//` recursion instead.
- **Expression precedence** — handled by the dialect chain
  (ExprOr → ExprAnd → ... → ExprAtom), not by synth
  mechanisms.
- **Scope resolution** — synth defines syntax. The scope
  tree (built by the engine from synth output) handles
  name resolution.


## Delimiter Budget

### The Six Delimiter Pairs

```
()      Paren           Solar     — identity, objects
[]      Bracket         Lunar     — reflection, cycling
{}      Brace           Saturnian — structure, boundary

(| |)   ParenPipe       Solar     — match (pattern on identity)
[| |]   BracketPipe     Lunar     — loop (cyclical)
{| |}   BracePipe       Saturnian — iteration (structured traversal)
```

### Root.synth — Top Level

```
()      Module (first), Enum, TraitDecl
[]      TraitImpl
{}      Struct
{| |}   Const
(| |)   FFI
[| |]   Process (entry point)
(bare)  Newtype — PascalCase Type (undelimited)
```

ALL SIX USED.


### Enum.synth — Inside (Enum ...)

```
()      data-carrying variant
{}      struct-form variant
[]      type application in variant payload
(| |)   nested enum
{| |}   nested struct
[| |]   free
```


### Struct.synth — Inside {Struct ...}

```
()      typed field
{}      (enclosing)
[]      type application in field type (via Type.synth)
(| |)   nested enum
{| |}   nested struct
[| |]   free
```


### Type.synth — Type expressions

```
[]      type application: [Vec Element]
$       dispatches to GenericParam.synth
@[]     instance of applied type
(bare)  simple type reference
```


### TraitDecl.synth — Inside (trait ...)

```
()      signature
[]      signature block
{}      free
{| |}   free
(| |)   free
[| |]   free
```


### TraitImpl.synth — Inside [trait ...]

```
[]      type impl block
()      free
{}      free
{| |}   free
(| |)   free
[| |]   free
```


### Signature.synth / Param.synth

```
(all)   free — params are sigil-driven
```


### Method.synth — Inside (method ...)

Any process delimiter is a valid method body:

```
[]      block body
(| |)   match body
[| |]   loop body
{| |}   iteration body
{}      struct construction body
()      free
```


### Statement.synth — Inside body

```
()      local type declaration: (Counter U32), (Names [Vec String])
[| |]   loop
{| |}   iteration
^       early return (sigil)
~@      mutation (sigil)
@       instance (sigil)
```

Via Expr fallthrough:
```
[]      inline eval (ExprAtom)
{}      struct construction (ExprAtom)
(| |)   match (ExprAtom)
[| |]   loop expression (ExprAtom)
{| |}   iteration expression (ExprAtom)
```


### ExprAtom.synth — Leaf expressions

```
[]      inline eval
{}      struct construction
[| |]   loop expression
{| |}   iteration expression
(| |)   match expression
()      free
```


### Instance.synth

```
()      optional type annotation: @Name (Type) Expr
```
