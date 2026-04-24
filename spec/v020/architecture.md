# Sema Engine — Architecture

## Sema Is the Thing

Sema is a universal typed binary format. No strings. No unsized
data. Domain variants ARE the bytes. Everything else exists to
serve sema.

Only semac produces true sema. Everything upstream is rkyv. If
it has unsized data, it is not sema.


## The Pipeline

```
corec       — .core → Rust with rkyv derives (bootstrap seed tool)
synth-core  — grammar .core + corec → Rust rkyv types (askicc↔askic contract)
aski-core   — parse tree .core + corec → Rust rkyv types (askic↔veric↔semac contract) + spec docs
veri-core   — verified-program .core + corec → Rust rkyv types (veric↔semac contract)
askicc      — source/<surface>/*.synth → dsls.rkyv (domain-data-tree, all 5 DSLs combined, embedded in askic)
askic       — .aski source + dsls.rkyv → per-module rkyv (aski-core types)
veric       — per-module rkyv + cross-module linking → program.rkyv (veri-core types)
domainc     — program.rkyv → Rust domain types (proc macro, compile-time)
semac       — program.rkyv + domain types → .sema (pure binary, no strings)
rsc         — .sema + domain types → .rs (Rust source)
askid       — .sema + domain types + name table → .aski (canonical text)
```

Each stage is a nix derivation depending on the previous.
Each component has defined inputs and defined outputs.

askic compiles each .aski file independently to a per-module
rkyv containing a structured `Module` (aski-core type). veric reads
all per-module rkyv files, verifies cross-module references
(imports, exports, type existence, no cycles), and produces a
single `program.rkyv` containing resolved entities with embedded
absolute-reference indices (veri-core types). domainc is a proc
macro that reads program.rkyv at compile time and generates
per-program domain types — no intermediate source files.

Only two Rust-emitting tools in the pipeline: **corec** (generates
contract types from `.core`) and **semac-via-rsc** (generates Rust
projections from `.sema`). Everything else is rkyv-typed-data in,
rkyv-typed-data out.


## Five Surfaces (v0.20)

aski has five DSLs, one per file type:

- `.core` — pure type definitions (for corec)
- `.aski` — modules and libraries (for askic)
- `.synth` — grammar self-description (for tooling)
- `.exec` — executable programs (for askic)
- `.rfi` — Rust foreign interface declarations (v0.20, for askic)

Each DSL is a set of **dialects** — one .synth file per
dialect (Body.synth, Statement.synth, Expr.synth, …). askicc
reads source/<surface>/*.synth and produces ONE combined
rkyv at `generated/dsls.rkyv` containing every dialect from
every DSL. Each Dialect entry carries its SurfaceKind.

askic dispatches on file extension to pick the entry surface
(`.core` → Core, `.aski` → Aski, `.synth` → Synth, `.exec`
→ Exec, `.rfi` → Rfi), then walks dialects looked up by
(SurfaceKind, DialectKind). Cross-surface refs
(`<:surface:Name>` — e.g., exec's `<:aski:Statement>`)
resolve via the same flat table.

The synth language in v0.18 has three orthogonal concepts:

- `#Tag#` — names the output node TYPE. Never reads source.
  Resolves to `TagKind`.
- `@Label` / `:Label` / `'Label` — names the ROLE of a source-read
  identifier. Three bindings: Declare (`@`), Reference (`:`),
  Origin (`'` for place-based lifetime annotations).
  Resolves to `LabelKind`.
- `<Name>` / `<:surface:Name>` — dialect reference (same-surface
  or cross-surface). Resolves to `ItemContent::DialectRef`.

No overlap between TagKind and LabelKind. Cross-surface refs
use `<:surface:Name>`. Whitespace adjacent to delimiters is
ignored; whitespace between non-delimiter items still
distinguishes adjacency-required from adjacency-optional.


## The Naming IS the Architecture

```
synth       = the grammar-description language (.synth files)
synth-core  = rkyv contract for synth's grammar data
askicc      = synth compiler (produces synth-core rkyv = dsls.rkyv)

aski        = the language family, user-facing text
aski-core   = rkyv contract for aski's parse tree
askic       = aski compiler (produces aski-core rkyv = per-module .rkyv)

veric       = aski verifier + linker (produces veri-core rkyv = program.rkyv)
veri-core   = rkyv contract for verified, resolved program
semac       = sema compiler (consumes veri-core + domain types, emits .sema)
```

Each compiler consumes the contract of the previous stage and
produces the contract of the next. Each *-core crate is one rkyv
contract between two tools.


## The rkyv Contracts

```
synth-core (.core) ──corec──→ Rust types with rkyv derives
                                   │
                       ┌───────────┴───────────┐
                       ▼                       ▼
                    askicc                   askic
                 (serializes                (deserializes
                  dsls.rkyv)                 dsls.rkyv)

aski-core (.core) ──corec──→ Rust types with rkyv derives
                              │
                  ┌───────────┴───────────┐
                  ▼                       ▼
               askic                veric / semac
           (serializes              (deserializes
            per-module              per-module rkyv)
            rkyv)

veri-core (.core) ──corec──→ Rust types with rkyv derives
                              │
                  ┌───────────┴───────────┐
                  ▼                       ▼
               veric              semac / domainc / rsc / askid
           (serializes              (deserializes
            program.rkyv)           program.rkyv)

<program>.rkyv ──domainc proc macro──→ Rust per-program domain types
                                              │
                                  ┌───────────┴───────────┐
                                  ▼                       ▼
                               semac                   rsc/askid
                            (serializes .sema)     (projections)
```

**synth-core** defines grammar types: Dialect, Rule, Alternative,
Item, ItemContent, Label, Tag, TagKind, LabelKind, DialectKind,
SurfaceKind, LiteralToken, DelimKind, etc.

**aski-core** defines parse-tree types: Module, Enum, Struct,
Newtype, Const, Rfi, TraitDecl, TraitImpl, Method, Signature,
Type, Param, Origin, Expr, Statement, Pattern, Body, etc. — all
named after what they ARE, not with "Def" suffix.

**veri-core** defines verified-program types: Program, with
modules containing resolved entities (each carrying
`Vec<EntityRef>` — absolute references to everything it relates
to). Design pending full implementation per the D6 intent:
parallel types mirroring aski-core with resolution baked in.

**per-program domain crate** defines the program's own types:
enums, structs, newtypes, consts — generated at compile time by
domainc from the verified program.rkyv.

Each contract is a Rust crate with rkyv derives. Each is
generated by corec (from `.core` files) or by domainc (proc
macro from `program.rkyv`). Each is shared between a serializer
and a deserializer.


## corec — The Bootstrap Tool

Reads `.core` type definitions, emits Rust with rkyv derives.
Zero dependencies. Used by synth-core, aski-core, and veri-core
to generate their contract types.


## askicc — The Synth Compiler

Reads `source/<surface>/*.synth` files (one dialect per file, four
surfaces: core, aski, synth, exec). Populates synth-core domain
types — the parsed grammar becomes a typed data tree. Serializes
as a single `dsls.rkyv` containing every dialect from every DSL
(each Dialect tagged with its `SurfaceKind`). The rkyv output is
embedded in askic at build time via `include_bytes!`, giving askic
the state-machine data for that version of aski's grammar.

askicc does NOT generate Rust. Only corec and semac-via-rsc
generate Rust. askicc produces rkyv data (a domain-data-tree of
synth-core types).


## askic — The Aski Compiler

A generic dialect engine with NO language-specific parsing
logic. The embedded rkyv dialect data IS the state machine.
Reads one .aski source file, produces one per-module .rkyv
containing a structured Module.

Three layers:
- Lexer — tokenizes .aski source
- Engine — walks dialect data, matches tokens, produces ParseValues
- Builder — restructures flat parse into Module container

Text is flat; the tree comes from the builder. Root.synth
is a flat sequence of alternatives. The builder populates
Module fields (enums, structs, newtypes, consts, etc.)
from the flat parse result.

askic's output is rkyv, NOT sema — it has strings (user
names, literals). It becomes sema only when semac processes
it. Each per-module .rkyv is independently cacheable and
parallelizable by nix.


## veric — The Aski Verifier

Reads per-module .rkyv files produced by askic. Verifies
cross-module structural correctness. Produces a single
program.rkyv containing all modules.

Five verification tiers:
1. Module linking — imports resolve, exports valid, no cycles
2. Type graph — every TypeName/TraitName references a real definition
3. Trait structure — impl methods match decl signatures
4. Scope and visibility — name uniqueness, private/public
5. Literal/const — value types match declarations

veric catches structural errors before semac. semac receives
a verified program and can trust all references are valid.

See ~/git/veric/ARCHITECTURE.md for full design.


## domainc — The Domain Proc Macro

A proc-macro crate that reads veric's program.rkyv at
compile time and expands into per-program domain types with
rkyv derives. No intermediate source files. No separate
binary.

```rust
domainc::domains!(env!("PROGRAM_RKYV"));
```

semac and rsc both invoke the same macro on the same
program.rkyv to get identical types. The .rkyv IS the
contract — the macro is just the mechanism.

### What It Reads

`Vec<Module>` from veric's program.rkyv. It extracts:

- **Enum** → Rust enums (bare, data-carrying, struct variants, nested)
- **Struct** → Rust structs (typed fields, self-typed fields, nested)
- **Newtype** → Rust tuple structs
- **Const** → Rust consts
- **Module** → module scope structure (exports, imports)
- **TraitDecl** → trait index enum (which traits exist)

It ignores: TraitImpl (has expressions → semac), Process
(has expressions → semac), FFI (semac generates extern blocks).

### What It Generates

For a module like:
```aski
(Elements Element Quality Describe)
(Element Fire Earth Air Water)
(Quality Passionate Grounded Intellectual Intuitive)
{Point (Horizontal F64) (Vertical F64)}
(| Counter U32 |)
{| MaxSigns U32 12 |}
(Describe [(describe &self Quality)])
```

domainc generates:

```rust
// Scope index enums
pub enum ElementsEnums { Element, Quality }
pub enum ElementsStructs { Point }
pub enum ElementsNewtypes { Counter }
pub enum ElementsTraits { Describe }
pub enum ElementsConsts { MaxSigns }

// Domain enums
pub enum Element { Fire, Earth, Air, Water }
pub enum Quality { Passionate, Grounded, Intellectual, Intuitive }

// Domain structs
pub struct Point { pub horizontal: f64, pub vertical: f64 }

// Newtypes
pub struct Counter(pub u32);

// Consts
pub const MAX_SIGNS: u32 = 12;
```

All types have rkyv derives. All enums with no data get
Copy + Eq + Hash.

### What It Does NOT Generate

- Trait definitions (semac — needs method body compilation)
- Trait implementations (semac — expression compilation)
- Process bodies (semac — expression compilation)
- FFI extern blocks (semac)

domainc generates the NOUNS (types). semac generates the
VERBS (implementations).

### Dependencies

```
domainc depends on: aski (rkyv types) + rkyv + proc-macro2 + quote
```

domainc is independent of corec. Each has its own codegen.

### Usage

semac and rsc depend on domainc as a proc-macro crate:
```toml
[dependencies]
astro-domains = { path = "flake-crates/astro-domains" }
```

### Nix Integration

```
askic output → domainc → domain crate (nix derivation)
                              ↓
                         semac (depends on domain crate)
```

Each is a nix derivation. domainc's output is a source tree
that semac's flake populates into flake-crates/.


## semac — The Sema Backend

Reads rkyv parse tree (aski types) + per-program domain crate
(from domainc). Performs semantic analysis:
- Builds scope tree from domain definitions
- Resolves all names against scopes
- Compiles expressions/bodies using the resolved domain types
- Serializes the resolved tree as .sema using the domain crate
- Produces .sema (pure binary, no strings) + .aski-table.sema

semac produces SEMA — not Rust. The .sema binary is the domain
tree serialized with per-program types. Every string resolved
to a domain variant.

semac depends only on aski, NOT on aski-core.


## rsc — The Rust Projector

Reads .sema + domain crate. Projects to Rust source. A pure
mechanical transformation — each domain variant maps to one
Rust codegen pattern. No semantic analysis.


## askid — The Aski Deparser

Reads .sema and reconstructs canonical aski text. It is the
reverse of askic — the sema→aski direction. It proves that
sema is lossless: anything that went in can come back out.

```
.sema + .aski-table.sema + domain crate → .aski text (canonical)
```

askid is a PROJECTION from sema, parallel to rsc:
- rsc: .sema + domain crate → .rs (Rust projection)
- askid: .sema + domain crate + name table → .aski (aski projection)

### Why It Matters

Self-hosting requires the full grammar — the same grammar that
parses also reconstructs (bidirectional). Shortcuts break
round-tripping from sema.

The round-trip: `.aski → askic → semac → .sema → askid → .aski`

The output .aski is CANONICAL — same formatting for equivalent
programs. Running it twice is idempotent.

### The Grammar Is Bidirectional

Each synth rule works in both directions:

**Sequential rules** — parse reads items left-to-right,
deparse emits items left-to-right.

**Ordered choice** — parse tries alternatives until match,
deparse uses the variant to select the alternative.

**Delimiters** — parse matches open/close, deparse emits
open/close.

**Cardinality** — parse collects Vec/Option, deparse
iterates and emits.

### Expression Precedence

The expression chain (ExprOr→ExprAnd→...→ExprAtom) is a
parsing mechanism only — it doesn't survive into the parse
tree or .sema. The tree structure encodes precedence:
`BinAdd(a, BinMul(b, c))` = `a + b * c`.

For deparse, askid maintains a 6-level precedence table
(matching the dialect chain) and emits `[expr]` grouping
only when a lower-precedence expression is a child of a
higher-precedence one.

### Output Format

Canonical. One .aski file per module. Module name determines
filename. Consistent formatting:

```aski
(Elements Element Quality describe)

(Element Fire Earth Air Water)
(Quality Passionate Grounded Intellectual Intuitive)

{Point (Horizontal F64) (Vertical F64)}

Counter U32
```

Whitespace is always canonical (newlines are not significant
in aski). Comments are not preserved (not in .sema).

### Dependencies

```
askid depends on:
  - <program>-domains crate (domainc output)
  - aski-core (for dialect grammar types)
  - askicc rkyv (embedded — the synth grammar as data)
  - rkyv (for deserialization)
```

rsc and askid are sibling projectors from .sema. Neither
depends on the other.


## Per-Program Domain Generation

The parse tree contains domain definitions with strings:
`Enum { name: "Element", children: [Variant("Fire"), ...] }`

domainc reads these and generates Rust types:
`pub enum Element { Fire, Earth, Air, Water }`

These ARE the sema domains. The enum discriminant IS the byte.
No indices, no lookup tables. Real Rust enums.


## The Data Trees

Each compiler stage produces a data-tree for the next. All
three are quasi-pure domain-trees — composed almost entirely
of enums (one-of) and structs (all-of). No generic "Node"
type with untyped children.

All intermediate data is rkyv-serialized. Only semac produces
true sema — no strings, no unsized data, domain variants as
bytes. Everything upstream has strings and is therefore rkyv,
not sema.

### The Insight

Synth rules define domains. Each synth dialect IS a domain
definition:

- `//` alternatives → enum (which construct?)
- Sequential items → struct (what does it contain?)
- `+` repeated items → Vec of domain
- `?` optional items → Option of domain

The synth grammar IS the domain-tree schema.

```synth
;; Enum.synth defines this domain:
// *@Variant                    → Variant (leaf)
// *(@Variant <Type>)           → DataVariant (struct: name + type)
// *{@Variant <Struct>}         → StructVariant (struct: name + fields)
// *(|@Enum <Enum>|)            → NestedEnum (recursive)
// *{|@Struct <Struct>|}        → NestedStruct (recursive)
```

This IS an enum definition:

```rust
enum EnumChild {
    Variant { Name: VariantName },
    DataVariant { Name: VariantName, Payload: Type },
    StructVariant { Name: VariantName, Fields: Vec<StructField> },
    NestedEnum(Enum),
    NestedStruct(Struct),
}
```

The synth rule → the Rust enum. One-to-one. The grammar IS
the type system of the data-tree.

### Stage 1: corec + aski-core — The askicc/askic rkyv Contract

aski-core defines every type that appears in the rkyv message
between askicc and askic. corec generates Rust with rkyv derives
from the .aski definitions. Both askicc (serializer) and
askic (deserializer) depend on corec's output.

Source of truth (currently incomplete — see aski-core CLAUDE.md):
- `aski-core/core/name.core` — NameDomain, Operator
- `aski-core/core/scope.core` — ScopeKind, Visibility
- `aski-core/core/span.core` — Span
- (missing) — Dialect, Rule, Item, ItemContent, DelimKind,
  Cardinality, DialectKind, Sigil

### Stage 2: askicc's Output — rkyv Domain-Data-Tree

askicc reads .synth dialect files from each DSL's subdirectory,
populates a domain-data-tree using synth-core's corec-generated
types, and serializes it as a single `dsls.rkyv` containing all
five DSLs. This rkyv data gets embedded in the askic binary at
build time, giving askic the ability to read that version of
aski's grammar. askic deserializes using the same corec-generated
types. The tree itself is pure domain composition — every node
is an enum (one-of) or struct (all-of) of synth-core types.

The domain-data-tree IS the state machine that drives askic's
parser. It captures what tokens to match, in what order, with
what adjacency, using what delimiters, with what cardinality.

#### Parse tree domains (from synth rules)

The synth rules define the typed domain-tree that askic's
engine populates at runtime. These domain types are defined
in `.core` files:

- `aski-core/core/module.core` — Module, Import, Export, Visibility
- `aski-core/core/domain.core` — Enum, Struct, Newtype, Const, Rfi (and children: Field, RfiFunction, EnumChild, StructChild)
- `aski-core/core/trait.core` — TraitDecl, TraitImpl, Method, Signature, NamedSignature, NamedMethod
- `aski-core/core/type.core` — Type (enum-first, 6 variants), TypeApplication, GenericParam, TraitBound
- `aski-core/core/origin.core` — Origin (PlaceRef, PlacePath, PlaceUnion — lifetime annotations)
- `aski-core/core/param.core` — Param (7 nested variants per borrow kind × Self/Named)
- `aski-core/core/expr.core` — Expr, FieldInit
- `aski-core/core/statement.core` — Statement, Instance, Mutation
- `aski-core/core/pattern.core` — Pattern, MatchArm, MatchExpr
- `aski-core/core/body.core` — Body, Block, Loop, Iteration, StructConstruct
- `aski-core/core/primitive.core` — Primitive (built-in types)
- `synth-core/core/dialect.core` — Dialect, Rule, Alternative, Item, ItemContent, Label, Tag, Binding, LabelKind, TagKind, Casing, Cardinality, DelimKind, DialectKind, SurfaceKind, LiteralToken, KeywordToken

The `.core` files ARE the source of truth. Every type is a
domain (enum or struct). No generic Node. No untyped children.
The tree IS domains all the way down — a domain-data-tree.

### Stage 3: askic's Output — rkyv Parse Tree

askic reads user .aski source and produces an rkyv-serialized
parse tree. askic is a generic dialect engine — it contains
no language-specific parsing logic. askicc's rkyv domain-data-
tree (aski-core types) is embedded in askic at build time,
and the engine executes it as a dialect-based state machine.
askic serializes its parse tree output using aski types —
the contract that semac reads.

The parse tree records the engine's path through the dialect
state machine. Each node captures which dialect was entered,
which alternative matched, what names were declared, and
what values were found. Pure domains all the way down.

### Stage 4: What semac Receives

semac receives askic's rkyv parse tree (aski types).
semac depends only on aski, NOT on aski-core. This is
NOT sema yet — it has strings (user names, literals). semac
resolves strings to domain variants and produces:

1. **True sema** — the domain-tree with no strings. Each
   enum variant is a discriminant byte. Each struct is a
   record. Fixed-size. No unsized data.

2. **Rust source** — the domain-tree translated to Rust.

3. **.aski-table.sema** — name projection. Maps domain
   variants back to their aski source names.

This is where rkyv becomes sema.

### Why This Works

**Synth rules = domain definitions.** Each dialect IS a
domain. The grammar defines the tree's type system. No
separate "AST definition" — the grammar IS the AST.

**Grammar is data, not code.** askicc produces a rkyv
domain-data-tree that gets embedded in askic. askic is a
generic dialect engine with no language knowledge compiled in.

**Parsing = walking a state machine.** askic executes the
embedded dialect data as a state machine against the token
stream. The engine records its path through the state machine
— that path IS the parse tree.

**Only semac produces sema.** Everything upstream is rkyv.
semac is where strings become domain variants, where unsized
data becomes fixed-size, where rkyv becomes sema.


## Synth IS the Grammar

PascalCase .synth dialect files define aski's entire syntax.
32 dialects. Each file's name is a DialectKind variant.

Synth items:
- `@Label` — declare a name (Binding::Declare)
- `:Label` — reference an existing name (Binding::Reference)
- `<Dialect>` — enter another dialect
- `()[]{}(||){||}[||]` — match delimiters
- `_X_` — literal token escape
- `*+?` — cardinality
- `//` — ordered choice

The Label struct carries: Binding (Declare/Reference) +
LabelKind (what it is) + Casing (Pascal/Camel). Three bytes.

Keywords: Self. Matched exactly, not declared or referenced.


## Delimiters Are Context-Dependent

At root level:
- `()` — Module (first), Enum, TraitDecl
- `[]` — TraitImpl
- `{}` — Struct
- `{||}` — Const
- `(||)` — FFI
- `[||]` — Process

In body context:
- `()` — Local type declaration
- `[]` — Block, InlineEval
- `{}` — StructConstruct
- `[||]` — Loop
- `{||}` — Iteration
- `(||)` — Match


## Rust Style

**No free functions — methods on types always.** All Rust will
eventually be rewritten in aski, which uses methods (traits +
impls). `main` is the only exception.


## Repos

```
corec        .core → Rust with rkyv derives (bootstrap tool)
synth-core   grammar .core + corec → rkyv types (askicc↔askic)
aski-core    parse tree .core + corec → rkyv types (askic↔veric↔semac)
askicc       source/<surface>/*.synth → rkyv dsls.rkyv (all 5 DSLs)
askic        .core/.aski/.synth/.exec → per-module .rkyv (surface-dispatched)
veric        per-module .rkyv → program.rkyv (verified, linked)
domainc      program.rkyv → domain types (proc macro)
semac        program.rkyv + domain types → .sema (pure binary)
rsc          .sema + domain types → .rs (Rust projection)
askid        .sema + domain types + name table → .aski (canonical text)
sema         Nix aggregator
```


## Reference: Sema Binary Shape from v0.15 Prototype

A v0.15 prototype of semac (archived 2026-04-16, deleted 2026-04-20
after extraction) implemented a concrete sema binary representation
worth documenting as reference for the current rewrite. These notes
are PROPOSED shapes, not spec — they record a plausible starting
point. Revisit when designing the v0.20 sema binary.

### Ordinal-based names

Each naming role (TypeName, VariantName, FieldName, TraitName,
MethodName, ModuleName, StringLiteral, BindingName) became a
newtype over `u32`. The u32 IS the discriminant in the binary.
String values live outside sema, in a sidecar name table accessed
through a `ResolveName` trait. This is what "no strings in sema"
looks like concretely.

### Flat sema structure

```rust
pub struct Sema {
    pub types: Vec<SemaType>,
    pub variants: Vec<SemaVariant>,
    pub fields: Vec<SemaField>,
    pub trait_decls: Vec<SemaTraitDecl>,
    pub trait_impls: Vec<SemaTraitImpl>,
    pub rfi_entries: Vec<SemaRfi>,     // was SemaFfi in v0.15
    pub constants: Vec<SemaConst>,
    pub modules: Vec<SemaModule>,
    pub arena: ExprArena,
}
```

Every entity is a typed struct with ordinal fields referring to other
tables. No pointers. rkyv-trivial.

### Flat expression arena

All expressions, statements, bodies, and match arms live in parallel
Vecs inside `ExprArena`, referenced via `ExprRef`/`StmtRef`/`BodyRef`
newtypes. No `Box`, no recursion. Nested expressions hold arena
indices instead of owned children.

```rust
pub struct ExprArena {
    pub exprs: Vec<SemaExpr>,
    pub stmts: Vec<SemaStatement>,
    pub bodies: Vec<SemaBody>,
    pub match_arms: Vec<SemaMatchArm>,
}
```

This removes the need for `Box` anywhere in the serialized form
while preserving recursive grammar (expressions still reference
sub-expressions).

### Name resolution sidecar

```rust
pub trait ResolveName {
    fn type_name(&self, id: TypeName) -> &str;
    fn variant_name(&self, id: VariantName) -> &str;
    // ... per name kind
}
```

Codegen and deparse consume `(Sema, &dyn ResolveName)`. The sema
binary alone has no names; resolution is a separate step.

### Rust projection model (future rsc)

v0.15 codegen emitted name enums into a `pub mod names` sub-module
first, then domain types, then trait decls, trait impls, constants.
Each name kind became a `#[derive(..)] enum TypeName { Element,
Quality, Point }` with a Display impl. Future `rsc` may adopt this
shape.

### Aski text reconstruction model (future askid)

v0.15 deparse walked the pre-lowering parse tree and emitted aski
source by matching on node constructors and delimiters. Future
`askid` consumes sema + name table + aski-specific projection rules
to reconstruct canonical text.
