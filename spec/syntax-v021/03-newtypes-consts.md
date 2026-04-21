# Newtypes and consts

## Newtypes

Newtypes live in `[_]Name.newtype` files.

**Content grammar:** `?<GenericSlot> <Type>` — the wrapped type is a single type expression.

Transparency — whether the wrapped value is publicly readable — is marked with `@` on the wrapped type.

### Transparent newtype (wrapped value public)

```
Counter.newtype
```

```aski
@U32
```

```rust
pub struct Counter(pub u32);
```

### Opaque newtype (wrapped value private)

```
OpaqueCount.newtype
```

```aski
U32
```

```rust
pub struct OpaqueCount(u32);
```

### Private newtype

```
_InternalCount.newtype
```

```aski
@U32
```

```rust
struct InternalCount(pub u32);
```

The leading `_` on the filename makes the newtype private to its module. The wrapped `U32` remains publicly readable *within* the module because `@` marks transparency at the wrapped-type level.

### Generic newtype

```
Items.newtype
```

```aski
{$Value}
@{Vec $Value}
```

```rust
pub struct Items<T>(pub Vec<T>);
```

### Newtypes for physical units

```
Seconds.newtype
```

```aski
@F64
```

```
Meters.newtype
```

```aski
@F64
```

```rust
pub struct Seconds(pub f64);
pub struct Meters(pub f64);
```

Two distinct types. No accidental substitution across units.

## Consts

Consts live in `[_]Name.const` files.

**Content grammar:** `<Type> <Expr>` — the file holds the const's type followed by its value. The RHS is a full expression; `veric` const-evals at build time.

### Literal consts

```
MaxSigns.const
```

```aski
U32 12
```

```rust
pub const MAX_SIGNS: u32 = 12;
```

```
Pi.const
```

```aski
F64 3.14159
```

```
Greeting.const
```

```aski
String "hello"
```

### Private const

```
_InternalTuningFactor.const
```

```aski
F64 1.618
```

```rust
const INTERNAL_TUNING_FACTOR: f64 = 1.618;
```

### Const expressions

The RHS can reference prior consts and use arithmetic.

```
MaxUsers.const
```

```aski
U32 100
```

```
MaxSessions.const
```

```aski
U32 MaxUsers * 4
```

```
BufferSize.const
```

```aski
U32 {(MaxUsers + MaxSessions) * 8}
```

```rust
pub const MAX_USERS: u32 = 100;
pub const MAX_SESSIONS: u32 = MAX_USERS * 4;
pub const BUFFER_SIZE: u32 = (MAX_USERS + MAX_SESSIONS) * 8;
```

Operands must be prior consts or literals in scope. `veric` validates the const-eval.
