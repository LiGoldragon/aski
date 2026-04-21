# Body basics

Body grammar appears inside method bodies and at other body positions (const values, struct construction, match arms, local decls). These forms are the same across all body positions.

## Literals

Literals are primitive values — not identifiers. The case rule (Pascal = structural, camel = instance) applies only to identifiers; literal tokens are their own class.

```aski
F64 3.14159                      # Float
U32 2026                         # Int (decimal)
String "hello"                   # Str
Bool true                        # Bool
Unit Unit                        # Unit (zero-info)
```

`true` and `false` are literal tokens of primitive type `Bool`. They're not instances of `True`/`False` identifier types — they are literals, same class as `42` or `"hi"`.

### Signed numbers and escapes

```aski
I32 -42                          # unary minus on literal
F64 0.25
String "line one\nline two"      # escape sequences
```

### Integer literal forms

```aski
U32 0xFF_FF_FF_00                # hex (0x prefix)
U8  0b0010_1100                  # binary (0b prefix)
U32 0o755                        # octal (0o prefix)
U64 7_900_000_000                # numeric separators
```

### String literal forms

```aski
"\n"                             # escape sequences in normal strings
"""C:\Users\li\projects"""        # raw triple-string (no escapes)
"""
  Line one.
  Line two.
"""                               # multi-line raw
```

Escape sequences in normal strings: `\n`, `\t`, `\r`, `\\`, `\"`, `\0`, `\x{NN}`, `\u{NNNN}`.

## Local declarations (the five shapes)

All locals use `()` at statement position inside method bodies. The shape inside picks the variant.

| Form | Shape | Meaning |
|---|---|---|
| `(name)` | Canonical | declare-only; type = Pascal-of-name |
| `(name Type)` | TypeOnly | new local wrapping `Type`, uninitialized |
| `(name Type:method(args))` | TypeInit | wrapping + initialized |
| `(name :method(args))` | Construct | instance via Pascal-of-name:method |
| `(name expr)` | BindExpr | bind name to expression |

Example (inside a method body):

```aski
(demo &self [
  (counter)                          ;; Canonical
  (buffer {Vec U8})                  ;; TypeOnly
  (origin Point:new(0.0 0.0))        ;; TypeInit
  (radius :new(5.0))                 ;; Construct
  (total counter + 1)                ;; BindExpr
  [~counter.set(total)]              ;; Mutation — ExprStmt, not LocalDecl
  counter
])
```

A local declared `~name` is mutable; without `~` it is immutable.

## References, borrows, origins, views

Shared borrow = `&T`. Mutable borrow = `~&T`. Origins are place-based (not lifetime variables).

### Borrow in type position (method signature)

```aski
(describe &self Quality)
(emit ~&self ~&out Writer)
```

### Origin in type position

```aski
(get &'Map self &key String String)
(leftmost &'self.Left self String)
(concat &'(Left Right) node Rope)
```

`'Place` annotations name the origin of a borrow. `&'self` = "borrow originates at self"; `&'(A B)` = union of two places.

### View types (partial-field borrows)

```aski
(tick ~&self {| Count |} U32)
(summary &self {| Count Name |} String)
```

`{| Field |}` after a borrow restricts it to specific fields — the caller only holds a borrow of those fields.

### Borrow in expression position

```aski
(shared &rawLocal)
(mutRef ~&rawLocal)
```

### Borrow of place expressions

Borrows accept place expressions: `self`, `:instance`, and any depth of `.FieldName` suffixes. Method calls are NOT place expressions (matches Rust).

```aski
(describe &self String [
  self.summarize(&self.Header &self.Body.Inner)
])

(mutate ~&self [
  self.commit(~&self.Buffer)
])
```

## Generic syntax

Appears in `.enum` / `.struct` / `.newtype` / `.trait` / `.impl` as an optional body-opening `{...}` slot.

| Form | Meaning |
|---|---|
| `{$Value}` | simple slot |
| `{$Value{Clone Debug}}` | bounded |
| `{$Left $Right}` | multi-param |
| `{$Value{Clone} SuperTrait}` | mixed with super-traits (traits only) |
| `${Clone Debug}` | bounds-as-name (no semantic name) |

Method-level generics use `?{...}` after the method name, before the parameter list:

```aski
(into {$Target} &self {$Target})
(apply ?{$Output} &self &fn {Callable self:Item $Output} $Output)
```

Type application uses `{Constructor Arg Arg ...}`:

```aski
{Vec U32}
{Option {Vec String}}
{Result U32 ConversionError}
{Map String {Vec Token}}
```
