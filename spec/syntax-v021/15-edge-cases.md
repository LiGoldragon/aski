# II-L edge cases and precedent

## Edge cases

The filename encoding is not claimed to be exhaustive. A few cases need settling — these are II-L-specific and surface during spec work.

### E1. Nested generics in impl filenames

```
Display@std~Shape@shapes.impl
```

works. But if the target has its own type arguments, nested `[...]` appears:

```
Show[Token]~Parser[Token]@lib.impl
```

Tokenization is well-defined but reads heavy. Recommendation: keep filenames flat when possible; push complex generics into the body's generic slot.

### E2. Bounded blanket with trait argument

```
From[Vec]~$(Clone).impl
```

Parses, but reads dense. Alternative: move the trait arg into the body.

### E3. Multi-char operators in filenames

None present — aski names are ASCII Pascal / camel / alphanumeric, so no risk of `<=` or `=>` appearing in a filename.

### E4. Case sensitivity

macOS default filesystems are case-insensitive. `Point.struct` and `point.struct` collide on macOS even though aski's case rule makes them different names. Since all top-level names are Pascal, this doesn't surface in practice — but stdlib conventions should enforce Pascal-only top-level filenames.

### E5. Filename length

Some filesystems cap filenames at 255 bytes. An impl filename like

```
VeryLongTraitName[VeryLongArgumentType]~VeryLongTargetName@very_long_module.impl
```

can push this. Mitigation: such cases are structural hints that the trait/target names should be refactored. II-L naturally pressures toward shorter, clearer names.

### E6. Colons in filenames

Some filesystems disallow `:`. Aski's internal source paths use `:` (`Char:Upper:A`) but on disk this maps to directory hierarchy (`Char/Upper/A.enum`). Filename-level paths use `/` (directory), `@` (module qualifier), `~` (impl separator), or `[]` (args) — never `:`.

### E7. The `_` prefix

The `_` prefix is reserved for visibility. Names that semantically start with underscore are not supported — `_Foo` is always "private Foo," not "a type whose name is underscore-Foo." Under ASCII-only filenames this is a non-issue.

### E8. Duplicate-stem collision

`Foo.enum` and `Foo.struct` in the same directory is a HARD ERROR. `veric` rejects. One name per directory regardless of kind.

### E9. Derivation output

When derivations synthesize impls, the output goes to `.build/derivations/*.impl` — filesystem-visible (not hidden in memory), build-managed (humans don't edit).

### E10. Symlinks

`veric`'s filesystem walk does NOT follow symlinks. A symlink following would produce two paths for one file (duplicate identity).

### E11. Impl stem conflict with body binding

If an impl has BOTH a trait arg in the stem AND an associated-type binding in the body, both forms encode the same info. Convention: prefer ONE encoding per impl, not both.

- Trait arg in stem when multiple impls want different args (e.g., `From[String]~Token` vs `From[U32]~Token`).
- Associated-type binding in body when the impl has ONE canonical args set.

### E12. Name lookup performance

Filesystem walks for every module lookup sound slow. Mitigation: `veric` builds a name-index on first walk, invalidates on file change. Standard incremental-build technique — not an II-L-specific problem.

## Precedent

II-L is not novel at every level. Its components appear in many languages and systems; the completeness of the commitment is what distinguishes v0.21.

| Language / system | II-L-adjacent feature |
|---|---|
| Java | one public class per file; filename = class name |
| Smalltalk | identity-is-location via class browser (proprietary image, not filesystem) |
| OCaml | `.mli` / `.ml` pairing — two surfaces per module |
| Plan 9 | "everything is a file" for system resources (not source) |
| Unison | content-addressed definitions; names are tags on hashes |
| Hazel | structure editing in a custom editor; filesystem secondary |
| Clojure | one namespace per file by convention |
| Elm | one module per file, enforced |

Each moved 1–2 metadata channels to the filesystem or another structural medium. v0.21 moves six channels: **name, kind, visibility, module, imports, and sub-structure.** None of the predecessors pushed all six onto the standard filesystem simultaneously.

The payoff: aski's identifier graph gets native support from every shell, editor, version-control system, code-search tool, incremental-build system, and LLM that reads files. No custom tooling required.

## What v0.20 had that v0.21 doesn't need

Condensed inventory of the move from source to filesystem.

**Retired from source (moved to filesystem):**

- Module header `(Name [Imports])`
- Imports line inside module header
- Root visibility `@` prefix on Enum/Struct/Newtype/Const/Trait/Impl
- Root delimiters `(...)`, `{...}`, `(|...|)`, `{|...|}`, `[|...|]`
- Root name declaration inside delimiter
- Impl-name-at-position-0 inside `[...]`

**Moved to filename:**

| Channel | New form |
|---|---|
| Enum / Struct / Newtype / Const / Trait name | `StemName.ext` |
| Impl identity | `TraitName~TargetName.impl` (optionally with `[Args]`, `@Module`, `$`, `$(...)`) |
| Visibility | `_` prefix (private) / no prefix (public) |
| Module | directory name |
| Imports | per-directory `imports` file |
| Kind | file extension |
| Platform | `.platform.impl` / `.platform.effect` middle segment |
| Test / bench mode | `.test-impl` / `.bench-impl` extension |
| Derivation | `.derivation` extension |

**Stayed in source (body-level):**

- Field visibility `@` inside `.struct` bodies
- Newtype transparency `@Type` inside `.newtype` body
- Generic slot `{$Param ...}`
- Super-trait bounds `{Super1 Super2}`
- Method signatures and bodies
- Method-level generics `?{$Param}`
- Associated-type bindings in impls
- Match / loop / iteration / block / or-pattern / local decl
- Path syntax `Type:Variant:...:method(...)`
- Borrow / mutable / origin / view-type sigils
- Early return `^`, try-unwrap `?`
- Operators and literals
- Struct construction `{ :Type (:Field Expr) ... }`
- Char library access `Char:Upper:A`
