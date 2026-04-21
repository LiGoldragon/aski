# Self, mutation, cast, path

## Self in expressions

`self` is an expression atom. `self.Field` is field access; `self.method(args)` is a method call on self.

```aski
(offset &self &delta Point Point
  {Point (Horizontal self.Horizontal + delta.Horizontal)
         (Vertical self.Vertical + delta.Vertical)})
```

Receiver forms in method signatures:

| Form | Meaning |
|---|---|
| `self` | owned receiver (moves self) |
| `&self` | shared borrow |
| `~&self` | mutable borrow |

## Mutation

`~name.method(args)` is a mutation statement — the mutation marker `~` at expression position on a method call.

```aski
(tick ~&self [
  [~self.Count.addAssign(1)]
  [~self.Last.set(Time:now)]
  self.Count
])
```

`~` never stands alone. It always modifies the thing being made mutable:

- a local declaration (`~counter` at the declaration site)
- a borrow (`~&self`)
- a method call (`~counter.set(...)`)

Mutation is method-only. Stdlib trait `Counter` carries the general mutation surface:

```aski
# Counter.trait
{$Value}
(set       ~&self &value  $Value)
(addAssign ~&self &delta  $Value)
(subAssign ~&self &delta  $Value)
(mulAssign ~&self &factor $Value)
```

Impls on `U8`–`U64`, `I8`–`I64`, `F32`, `F64`.

Assignment `=` and compound `+=` are not currently grammar. Mutation flows through method calls on mutable locals, on `~&self`, or on stdlib primitive methods. See [16-open-questions §Bare = and +=](16-open-questions.md#bare--and-).

## Cast / conversion

Zero grammar — stdlib traits `From` / `Into` / `TryFrom` across numeric primitives. Narrowing conversions use explicit lossy method names so the semantics are visible at the call site.

```aski
(widened   U32:from(byte))                          # widen U8 -> U32
(narrowed  U8:truncate(wide))                       # explicit lossy
(converted {Result U32 ConversionError}
           U32:tryFrom(big))                        # fallible
```

Stdlib traits:

```aski
# From.trait
{$Source}
(from :value $Source Self)
```

```aski
# Into.trait
{$Target}
(into self $Target)
```

```aski
# TryFrom.trait
{$Source $Failure}
(tryFrom :value $Source {Result Self $Failure})
```

### Narrowing operations

| Method | Semantics |
|---|---|
| `truncate` | drop high bits (wrap modulo 2^N) |
| `saturate` | clamp to target min/max |
| `wrap` | explicit wrap-around (same as truncate for unsigned) |

## Path syntax

Paths use `:` as the separator.

| Form | Meaning |
|---|---|
| `Element:Fire` | variant of an enum |
| `Option:None` | bare variant |
| `Option:Some(42)` | data variant with arg |
| `Counter:new(0)` | type-path method call |
| `U32:zero` | type-path constant/method |
| `self:Item` | trait's associated type (inside trait/impl) |
| `Shape:Rectangle` | nested variant |
| `Token:Delimiter:LParen` | chained-nested variant |
| `Char:Upper:A` | path through the Char library |

### Cross-module access

Cross-module access uses `:` too — the module IS a name in the same namespace as the type, because both are paths:

```aski
shapes:Shape                        # type Shape in module shapes
shapes:Shape:Rectangle              # nested variant of a cross-module type
```

Filename-level `@` (e.g., `Describe~Shape@shapes.impl`) is filesystem syntax; source-level path syntax uses `:` only.
