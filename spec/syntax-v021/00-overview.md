# Overview

## Identity-is-Location (II-L)

**Principle.** A name is a place. A place is a path. A path is a filesystem path. The filesystem is the program's identifier graph. Source files hold only what has no name of its own — their bodies.

Crisp form: *identity is location; location is path; a source file is what its path refers to — its body, and nothing else.*

## Filesystem layout

A project under II-L is organized by directory. Each directory is a module. Each file inside is one public object (or, if its name starts with `_`, one private helper). Files carry per-kind extensions.

```
myproject/
  imports                          # per-directory imports file
  Element.enum                     # public enum Element
  Quality.enum                     # public enum Quality
  Point.struct                     # public struct Point
  Counter.struct                   # public struct Counter
  _CacheSlot.struct                # PRIVATE helper struct
  MaxSigns.const                   # public const MaxSigns
  Describe.trait                   # trait Describe
  Iterator.trait                   # trait Iterator
  Describe~Element.impl            # impl Describe for Element
  Iterator[Token]~TokenReader.impl # impl Iterator for TokenReader
  FileReader~LocalFs.effect        # effectful impl
  DebugStruct.derivation           # derivation rule
  shapes/                          # sub-module `shapes`
    imports                        # self-contained; no inheritance
    Rectangle.struct
    Circle.struct
  _internal/                       # PRIVATE sub-module
    Helper.struct
```

Every name in the program corresponds to a path on disk. No source file names itself; no source file lists its module or its visibility. Those channels live in the path.

## Imports file

Each directory has at most one `imports` file. Grammar: a list of bracketed lines, one per source module.

```
[SourceModule ImportedName ImportedName ...]
```

Example `myproject/imports`:

```aski
[core Element Quality Shape Point]
[collections Vec Map]
[text String CharIterator]
```

No module header. No name. No visibility. The file is identified by its fixed filename `imports`.

Each directory's `imports` file is self-contained. Names are not inherited from a parent directory's `imports`. If `myproject/shapes/` uses `Vec`, it lists `Vec` in its own `imports` file — even if the parent `myproject/` already imports `Vec`.

This keeps the answer to "what names does this file see?" local to one file. No action-at-a-distance when a parent's imports change.

```aski
# myproject/shapes/imports — the full visible set for this directory
[collections Vec Set]
[text String StringFormat]
```

## File extensions (per-kind surfaces)

| Extension | Surface |
|---|---|
| `.enum` | enum declaration |
| `.struct` | struct declaration |
| `.newtype` | newtype wrapper |
| `.const` | constant |
| `.trait` | trait declaration |
| `.impl` | trait implementation |
| `.effect` | effectful impl (allowed to cross I/O) |
| `.derivation` | derivation rule |
| `.test-impl` | test-only impl |
| `.bench-impl` | benchmark-only impl |
| `.exec` | executable entry point |
| `.rfi` | Rust foreign interface group |

The extension picks which synth surface grammar is used to parse the body.

## Delimiters (body-internal)

| Pair | Role |
|---|---|
| `( )` | Categorical single thing (local decl, typed field, match arm, call args, variant with payload) |
| `[ ]` | Evaluation (block, InlineEval, ExprStmt, or-pattern) |
| `{ }` | Construction (struct construct, type application, generic slot, bound set, view type) |
| `(\| \|)` | Match body, nested enum |
| `[\| \|]` | Loop |
| `{\| \|}` | Iteration, const value, view type, nested struct |

## Sigils

| Sigil | Meaning | Position |
|---|---|---|
| `:` | path | between type/variant/method |
| `&` | borrow | type or expression |
| `~` | mutable modifier | on borrows, locals, method calls |
| `$` | type parameter | inside generic slots |
| `'` | origin / place | before a place name |
| `^` | early return | statement prefix |
| `?` | try-unwrap | postfix on `Result`/`Option` expr |
| `?` | while condition marker | prefix inside `[\| \|]` loop |
| `?` | dyn type | prefix on `{Trait}` at type position |
| `@` | field visibility | on struct field names inside bodies |
| `;;` | line comment | anywhere |

The `?` sigil carries three positional meanings, disambiguated by where it sits:
- postfix on an expression → try-unwrap
- immediately after `[\|` → while-condition marker
- immediately before `{` at type position → dyn trait type

## Case rule

- **Pascal** = compile-time structural things (types, variants, fields, type params, modules, consts, associated types).
- **camelCase** = actual instances of a type (locals, methods, `self`, match-arm bindings).

Struct fields remain Pascal regardless of visibility. The `@` field sigil marks public fields inside struct bodies.

## Visibility

- **File-level**: filename prefix `_` = private (visible only within its directory); no prefix = public.
- **Directory-level**: directory prefixed `_` = private sub-module (all files visible only to its parent).
- **Field-level**: `@` on a struct field name = public; bare field name = private.
- **Newtype transparency**: `@Type` on the wrapped type inside a `.newtype` file = transparent (wrapped value publicly readable).

Scoped visibility (`pub(crate)`, `pub(super)`) is not currently in v0.21 — see [16-open-questions §Scoped visibility](16-open-questions.md#scoped-visibility).

## Reading order

Each section shows:

1. The filesystem layout that defines the object.
2. The file's content (pure body).
3. The Rust equivalent where instructive.
4. Notes on grammar or stdlib dependencies where relevant.

Start with [01-enums](01-enums.md) for the simplest root form and work forward; body grammar starts at [08-body-basics](08-body-basics.md).
