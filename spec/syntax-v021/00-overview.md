Aski v0.21 — by example.

Principle: Identity-Is-Location (II-L).
  A name is a place. A place is a path. A path is a filesystem
  path. Therefore the filesystem is the program's identifier graph,
  and source files hold only what has no name of its own — their
  bodies.

  Crisp form: identity is location; location is path; a source
  file is what a path refers to — its body, and nothing else.

This file is a by-example reference for v0.21. Every block is
introduced by its filesystem path (what the file is called,
where it lives) followed by the file's contents (what goes
inside). The two together are one definition.

Shifts from v0.20 under II-L:
  * Module header `(Name [Imports])` disappears — directory is
    the module; imports live in a per-directory `imports` file.
  * `@` visibility sigil on root declarations disappears —
    filename prefix `_` = private; no prefix = public.
  * Outer root delimiters around declarations disappear — the
    file IS the delimiter. Content = body only.
  * Per-kind file extensions replace first-token-decidability
    at the root: `.enum`, `.struct`, `.newtype`, `.const`,
    `.trait`, `.impl`, `.effect`, `.derivation`, `.test-impl`,
    `.bench-impl`, `.exec`, `.rfi`.
  * Impl filename grammar carries trait + target + impl name
    at the path level: `Trait[Args]~Target.impl`.

What survived unchanged from v0.20:
  * Type expression grammar (Named, AppliedType, GenericParam,
    Borrowed, MutBorrowed, SelfAssoc, origins, view types)
  * Local-declaration 5-shape grammar at statement position
  * Match grammar (|...|), loop [|...|], iteration {|...|},
    ExprStmt [...], or-pattern [Variant1 Variant2],
    early-return ^expr, try-unwrap expr?
  * Struct construction { :Type (:Field Expr) ... }
  * Path syntax: Type:Variant, Type:method(args), self:AssocType
  * Case rule: Pascal = compile-time structural, camel = runtime.
    Struct fields remain Pascal regardless of visibility.

Newly landed (see v0.21 update notes):
  * C5 Division `/` (accepted 2026-04-20)
  * C6 Unary `-` and `!` (accepted 2026-04-20)
  * U16 Char-as-nested-enum: `Char:Upper:A` and similar
    (no char literal syntax)
  * U1 Deref `*` (accepted 2026-04-21, dispatches via stdlib Deref)
  * C4 if / if-let / while-let as match idioms (doc-only)
  * C7 Borrow of place expressions (&self.field, &item.inner.deep)
  * S2 Range expressions 0..n / a..=b
  * S5 Bitwise via stdlib BitOps trait methods
  * S7 Cast via stdlib From / Into / TryFrom trait methods
  * S8 Const expressions (const RHS is Expr, not just Literal)
  * S9 Associated constants in traits and impls
  * S11 Array primitive {Array T N}
  * N1 'Static and lifetime generics via origins (conventional
       PlaceName; no grammar change)
  * N2 Never primitive for divergent functions
  * N3 Assignment / compound assignment via stdlib Counter methods
       (= / += bare forms still open — see outliers-v021.md)
  * N5 Enum discriminants `[Ok 200]`
  * N8 Literal lexer extensions (hex/bin/oct, numeric separators,
       raw triple-strings)

Pick-and-merge (Li to confirm in v0.21):
  U11 struct destructuring (Option A pun-on-field)
  U13 break/continue sigil (3 candidates)
  U14 dyn sigil `?{Trait}`
  U15 discriminant shape confirm
  U17 methods-over-operators rubric as standing rule
  C3  LiteralPattern scope
  S4  Closures Position A (B/C in outliers)

Outliers (see outliers-v021.md):
  U3, U4, U5, U6, U7, U10, U12, U19, U20, U21, S6, N4

Delimiters (v0.21 body-internal — unchanged from v0.20):
  ()      Categorical single thing (local decl, typed field,
          match arm, call args, variant with payload)
  []      Evaluation (block, InlineEval, ExprStmt, or-pattern)
  {}      Construction (StructConstruct, type application,
          generic slot, bound set, view type)
  (||)    Match body (|...|), Nested enum (|...|)
  [||]    Loop [|cond body|]
  {||}    Iteration {|src.binding body|}, Const value (body-
          internal), View type {|Field|}, Nested struct {|...|}

Sigils (v0.21):
  :   path                                   &   borrow
  ~   mutable modifier                        $   type parameter
  '   origin                                  ^   early return
  ?   try-unwrap (postfix on Result/Option)
  @   field visibility (inside struct bodies only; root @ retired)
  ;;  line comment

The rest of this file is arranged by concern. Each section
shows:
  1. The filesystem layout that defines the object.
  2. The file's content (pure body).
  3. The Rust equivalent where instructive.
  4. Brief notes on what v0.20 had that v0.21 replaces.

## FILESYSTEM LAYOUT — orientation

A project under II-L is organized by directory. Each directory
is a module. Each file inside is one public object (or, if its
name starts with `_`, one private helper object). Files carry
per-kind extensions.

Example project layout:

  myproject/
    imports                          ;; per-directory imports
    Element.enum                     ;; public enum Element
    Quality.enum                     ;; public enum Quality
    Shape.enum                       ;; public enum Shape
    Point.struct                     ;; public struct Point
    Counter.struct                   ;; public struct Counter
    _CacheSlot.struct                ;; PRIVATE helper struct
    MaxSigns.const                   ;; public const MaxSigns
    Describe.trait                   ;; trait Describe
    Iterator.trait                   ;; trait Iterator
    Describe~Element.impl            ;; impl Describe for Element
    Iterator[Token]~TokenReader.impl ;; impl Iterator for TokenReader
                                     ;;   with associated Item=Token
    FileReader~LocalFs.effect        ;; effectful impl
    DebugStruct.derivation           ;; derivation rule for Debug
    shapes/                          ;; sub-module `shapes`
      imports                        ;; shapes-specific imports,
                                     ;;   stacks on parent's imports
      Rectangle.struct
      Circle.struct
    _internal/                       ;; PRIVATE sub-module (all
                                     ;;   files visible only inside
                                     ;;   the parent directory)
      Helper.struct

Every name in the program corresponds to a path on disk.
No source file names itself. No source file lists its
module or its visibility. Those channels live in the path.

## IMPORTS FILE

Each directory has at most one `imports` file. Its grammar is
a list of bracketed lines:

  [SourceModule ImportedName ImportedName ...]

Each line lists one source module (by path-resolvable name) and
the names imported from it. Sub-directories inherit the parent
directory's imports; a sub-directory's `imports` adds to, does
not replace, the parent's.

Filesystem path:
  myproject/imports

File content:

```aski
[core Element Quality Shape Point]
[collections Vec Map]
[text String CharIterator]

```
No module header. No name. No visibility. This file is an
imports list, identified by its fixed filename `imports`.

A sub-directory can add to the parent:

  myproject/shapes/imports

```aski
[text StringFormat]
[collections Set]

```
In `myproject/shapes/`, the names visible are the union:
  Element Quality Shape Point Vec Map String CharIterator
  StringFormat Set
