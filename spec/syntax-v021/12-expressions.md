# Expressions

## Type application

`{Constructor Arg Arg ...}` — applies a type constructor to its arguments.

```aski
{Vec U32}
{Option {Vec String}}
{Result U32 ConversionError}
{Map String {Vec Token}}
{HashMap String {Vec Token}}
{Box Tree}
{Tree $Value}
```

### Array type

```aski
{Array U32 16}
{Array {Array U8 8} 8}
{Array Cell BoardSize * BoardSize}
```

The second arg is a const-eval `U32` expression.

## Struct construction

`{ :Type (:Field Expr) ... }` — constructs an instance.

```aski
{Point (Horizontal 3.0) (Vertical 4.0)}

{Page
  (Content "")
  (Orientation Portrait)
  (Margin {Margin (Top 10) (Bottom 10) (Left 5) (Right 5)})}
```

## Binary operators

Precedence, low → high:

```
||
&&
== != <= >= < >
+ -
*
/ %
```

```aski
(a self.Left + self.Right)          # BinAdd
(b self.Left - self.Right)          # BinSub
(c self.Left * self.Right)          # BinMul
(d self.Left / self.Right)          # BinDiv
(e self.Left % self.Right)          # BinMod
```

Comparison produces `Bool`:

```aski
self.Score == other.Score           # BinEq
self.Score != other.Score           # BinNotEq
self.Score <  other.Score           # BinLt
self.Score >  other.Score           # BinGt
self.Score <= other.Score           # BinLtEq
self.Score >= other.Score           # BinGtEq
```

Logical:

```aski
(self.Active && other.Active) || self.Override
```

## Bitwise operations

Bitwise ops are stdlib methods, not operators. Reusing `&` or `|` as bitwise would collide with borrow and logical-or.

```aski
(flags    Permission:Read.bitOr(Permission:Write))
(readable flags.bitAnd(Permission:Read).ne(0))
(shifted  byte.shiftLeft(4))
(masked   word.bitAnd(0xFF))
(inverted word.bitNot)
```

Stdlib trait:

```aski
# BitOps.trait
(bitAnd     &self &other Self Self)
(bitOr      &self &other Self Self)
(bitXor     &self &other Self Self)
(shiftLeft  &self &bits U8 Self)
(shiftRight &self &bits U8 Self)
(bitNot     &self Self)
```

Impls on `U8`–`U64`, `I8`–`I64`.

## Unary operators

```aski
(offset I32 -42)                    # literal negation
(neg -x)                            # on a local
(shift -self.Count)                 # on a field access

(valid !self.Failed)
(| !self.Ready
  (true)  ^Option:None
  (false) Unit
|)
```

## Deref

`*x` dispatches to the stdlib `Deref` trait's method.

```aski
(derefed *boxedValue)                # dispatches to Box:Deref:deref
(payload *self.Inner)                # deref a field
```

Deref applies to smart-pointer types (`Box`, `Rc`, future `Arc`) — any type with a `Deref` impl. Separate from raw pointers (which are not in v0.21).

## Range expressions

```aski
0..10                               # half-open
0..=10                              # inclusive

{| 0..10.step
  [StdOut:print(step)]
|}

(window self.Cursor..self.Cursor + 16)
```

## Dyn trait types

`?{Trait}` at type position marks "unknown concrete type that satisfies Trait." Requires a pointer carrier (`&`, `~&`, `Box`, …).

```aski
(emit ~&writer {?Writer} :msg String [~writer.write(msg)])
(nextToken ~&src {?Iterator Token} {Option Token}
  [~src.next])
(boxed {Box {?Callable U32 U32}} ...)
```

### Types vs values — the key rule

**Sema can reference dyn types in signatures; sema cannot store dyn values.**

A dyn type in a signature is a type expression — sema is describing code, and signatures are metadata about what exists. No fat pointer is involved.

A dyn *value* (a fat pointer `(data_ptr, vtable_ptr)`) is process-local — the vtable pointer has no meaning across serialization. `veric` enforces that no field of a serialized type has a `?{Trait}` type.

This is the ordinary distinction between *talking about* something and *storing an instance of* it. Dyn dispatch works normally at runtime (vtable-pointer representation); dyn values just cannot cross the sema-byte boundary. Use cases:

- **OK**: `?{Trait}` in function parameter types, return types, local variable types.
- **Rejected by veric**: `?{Trait}` as a field of a struct/enum that gets serialized.

### What dyn is for

Same problems as Rust: open-world heterogeneity.

- Heterogeneous collections (`Vec` of different concrete types).
- Functions returning different concrete types from different branches.
- Recursive trees where nodes are any impl of a trait.
- Callback / event-handler storage where caller type is varied.

Alternatives where applicable: generics + trait bounds, or an enum of specific types. Dyn is only needed when the set of concrete types is open.

### Object safety

Standard object-safety constraints apply (no methods returning `Self`, no generic method params without `Sized` bounds, etc.). `veric` checks.

## Closures

Closures are named types that impl the stdlib `Callable` trait. Zero grammar change — a closure in Rust is an ad-hoc named struct in aski, with an explicit `Callable` impl.

```
Increment.struct
```

```aski
(@Amount U32)
```

```
Callable[U32,U32]~Increment.impl
```

```aski
(call &self &input U32 U32 [input + self.Amount])
```

At a call site:

```aski
(items self.Nums.map(&Increment {Amount 1}))
```

Stdlib trait:

```aski
# Callable.trait
{$Input $Output}
(call &self $Input $Output)
```

Inline closure sugar (`|x| body`) is not currently in v0.21 — see [16-open-questions §Closure sugar](16-open-questions.md#closure-sugar).

## Literal patterns

LiteralPattern covers `Int`, `Float`, `Str`, and `Bool` at match-arm position.

```aski
(| code
  (0)       "pending"                # IntMatch
  (200)     "ok"
  (3.14)    "tau-adjacent"           # FloatMatch
  ("hello") "greeting"               # StrMatch
  (true)    "on"                     # BoolMatch
  (false)   "off"
  (_)       "other"
|)
```

`Char` is not a LiteralPattern — matched via path patterns on the Char library: `(Char:Upper:A)`.

## Postfix operators

Unchanged from the body grammar. Left-to-right chaining.

```aski
self.stage1(input).stage2.stage3(self.Config)
```

| Form | Meaning |
|---|---|
| `expr.Field` | field access (Pascal suffix) |
| `expr.method(args)` | method call (camel suffix) |
| `expr?` | try-unwrap (on `Result`/`Option`) |

## Expression atoms

| Form | Name |
|---|---|
| `&instance` | BorrowExpr |
| `~&instance` | MutBorrowExpr |
| `self` | SelfRef |
| `:instance` | InstanceRef |
| `:Type:method(args)` | PathCall |
| `:Type:Variant` | PathVariant |
| `:Variant` | BareVariant |
| `42`, `"hi"`, `true` | LiteralExpr |
| `[ <Body> ]` | InlineEval (block as expression) |
| `(\| <Match> \|)` | MatchExpr |
| `[\| <Loop> \|]` | LoopExpr |
| `{\| <Iter> [body] \|}` | IterExpr |
| `{ :Type +(:Field <Expr>) }` | StructExpr |
