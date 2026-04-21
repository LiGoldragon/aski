## NEWTYPES — Name.newtype files

Filename grammar:
  [_]NewtypeName.newtype

Content grammar:
  ?<GenericSlot> <Type>

The wrapped type is a single Type expression. Transparency
(whether the wrapped value is publicly readable) is marked
with `@` on the wrapped type.

Transparent newtype (wrapped value public) -----------------

Filesystem path:
  Counter.newtype

```aski
@U32

```
Rust equivalent:
  pub struct Counter(pub u32);

`@U32` = wrapped type is public. Consumers can read the
underlying U32.

Opaque newtype (wrapped value private) ---------------------

Filesystem path:
  OpaqueCount.newtype

```aski
U32

```
Rust equivalent:
  pub struct OpaqueCount(u32);

Private newtype --------------------------------------------

Filesystem path:
  _InternalCount.newtype

```aski
@U32

```
Rust equivalent:
  struct InternalCount(pub u32);

Leading `_` on filename = newtype itself is private to the
module. The wrapped U32 is publicly readable WITHIN the module
(because `@` marks transparency at the wrapped-type level).

Generic newtype --------------------------------------------

Filesystem path:
  Items.newtype

```aski
{$Value}
@{Vec $Value}

```
Rust equivalent:
  pub struct Items<T>(pub Vec<T>);

Generic slot, then the wrapped type expression.

Newtype for a physical unit --------------------------------

Filesystem path:
  Seconds.newtype

```aski
@F64

```
Filesystem path:
  Meters.newtype

```aski
@F64

```
Rust equivalent:
  pub struct Seconds(pub f64);
  pub struct Meters(pub f64);

Two distinct types, each wrapping F64. No accidental
substitution across units.

## CONSTS — Name.const files

Filename grammar:
  [_]ConstName.const

Content grammar:
  <Type> <LiteralOrExpr>

The file holds the const's type followed by its value. The
RHS can be a literal (v0.20) or an expression (S8 — proposed
in v0.21 but currently literal-only).

Literal const ----------------------------------------------

Filesystem path:
  MaxSigns.const

```aski
U32 12

```
Rust equivalent:
  pub const MAX_SIGNS: u32 = 12;

Filesystem path:
  Pi.const

```aski
F64 3.14159

```
Filesystem path:
  Greeting.const

```aski
String "hello"

```
Private const ----------------------------------------------

Filesystem path:
  _InternalTuningFactor.const

```aski
F64 1.618

```
Rust equivalent:
  const INTERNAL_TUNING_FACTOR: f64 = 1.618;

Const expression (S8 — MERGED 2026-04-21) ------------------

The RHS of a const file is an <Expr>, not only a <Literal>.
veric const-evals the expression at build time. Operands must
be prior consts or literals in scope.

Filesystem path:
  MaxUsers.const

```aski
U32 100

```
Filesystem path:
  MaxSessions.const

```aski
U32 MaxUsers * 4

```
Filesystem path:
  BufferSize.const

```aski
U32 {(MaxUsers + MaxSessions) * 8}

```
Rust equivalent:
  pub const MAX_USERS: u32 = 100;
  pub const MAX_SESSIONS: u32 = MAX_USERS * 4;
  pub const BUFFER_SIZE: u32 = (MAX_USERS + MAX_SESSIONS) * 8;

Grammar change: Root.synth Const's RHS changes from
`@Literal` to `<Expr>`.

;; MERGED FROM S8 — see gap-analysis.md §S8 and
;; bridge/clear.md §S8.
