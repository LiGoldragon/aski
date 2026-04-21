# Modules and visibility

## Directory = module

No module header in source. A directory IS a module. No source file names its module; no source file lists its imports inside the body.

```
shapes/
  imports                           # single imports file
  Shape.enum                        # one public object per file
```

`shapes/imports`:

```aski
[core Element Quality]
[collections Vec]
```

`shapes/Shape.enum`:

```aski
(Circle F64)
{Rectangle (Width F64) (Height F64)}
```

The module's name IS the directory name (`shapes`). File visibility is implicit from the filename prefix.

## Visibility channels

| Level | Channel | Public | Private |
|---|---|---|---|
| File | filename prefix | `Name.ext` | `_Name.ext` |
| Directory | dirname prefix | `name/` | `_name/` |
| Struct field | `@` sigil in body | `@Field` | `Field` |
| Newtype transparency | `@` on wrapped type in body | `@Type` | `Type` |

No other visibility sigils or keywords exist. Scoped visibility (`pub(crate)`, `pub(super)`, `pub(in path)`) is not currently supported — see [16-open-questions §Scoped visibility](16-open-questions.md#scoped-visibility).

## Path-level vs body-level visibility

Most visibility lives at the path level (filename/dirname prefix). Two cases stay in the body:

- **Struct fields** — one struct file can mix public and private fields, so per-field visibility lives inside the body.
- **Newtype transparency** — whether a newtype exposes its wrapped value is per-newtype, lives in the body.

The `@` sigil has no root-level meaning in v0.21 (root visibility moved to the filename prefix).

## Private sub-modules

A directory prefixed `_` is a private sub-module. All its files are visible only within the parent directory.

```
mylib/
  Public.struct
  _internal/
    Helper.struct        # visible only inside mylib/
    Detail.enum
```

Private sub-modules can contain public files (no prefix) — but their visibility is capped by the private parent directory. The file IS public, but only within `mylib/`.
