## TYPE APPLICATION — {Constructor Args...}

Unchanged from v0.20.

  {Vec U32}
  {Option {Vec String}}
  {Result U32 ConversionError}
  {Map String {Vec Token}}
  {HashMap String {Vec Token}}
  {Box Tree}
  {Tree $Value}

Array type (S11 — MERGED 2026-04-21) -----------------------

Array is a two-arg primitive: `{Array Element Size}`. The
second arg is an integer-const expression that const-evals to
U32. Requires S8 (const expressions) for size expressions.

  (buffer {Array U32 16} Array:fill(16 0))
  (table  {Array {Array U8 8} 8} Table:blank)

  ;; BoardSize.const -> U32 8
  (board {Array Cell BoardSize * BoardSize})

Rust equivalent:
  let buffer: [u32; 16] = ...;
  let table:  [[u8; 8]; 8] = Table::blank();
  let board:  [Cell; BOARD_SIZE * BOARD_SIZE];

Zero grammar change. Add `("Array", 2)` to `Primitive::all()`.
Scope: integer-const size only (U32). No string, no char, no
structured-literal size parameters.

;; MERGED FROM S11 — see gap-analysis.md §S11 and
;; bridge/clear.md §S11. No array-literal expression form —
;; construction via Array:fill / Array:of methods only. Array
;; literal expression syntax stays open (U4) — see
;; outliers-v021.md.

## STRUCT CONSTRUCTION (in expression position)

`{ :Type (:Field Expr) ... }` — unchanged.

  {Point (Horizontal 3.0) (Vertical 4.0)}

  {Page
    (Content "")
    (Orientation Portrait)
    (Margin {Margin (Top 10) (Bottom 10) (Left 5) (Right 5)})}

## BINARY OPERATORS

Precedence, low → high:
  ||, &&, ==/!=/<=/>=/</>, +/-, *, /, %

Division `/` is v0.21-landing (C5, accepted 2026-04-20).
Modulo is `%`.

Example body (inside a method):

  (a self.Left + self.Right)          ;; BinAdd
  (b self.Left - self.Right)          ;; BinSub
  (c self.Left * self.Right)          ;; BinMul
  (d self.Left / self.Right)          ;; BinDiv (v0.21)
  (e self.Left % self.Right)          ;; BinMod

Comparison:
  self.Score == other.Score           ;; BinEq
  self.Score != other.Score           ;; BinNotEq
  self.Score <  other.Score           ;; BinLt
  self.Score >  other.Score           ;; BinGt
  self.Score <= other.Score           ;; BinLtEq
  self.Score >= other.Score           ;; BinGtEq

Logical:
  (self.Active && other.Active) || self.Override

Bitwise operations (S5 — MERGED 2026-04-21) ---------------

Zero grammar change — bitwise ops are stdlib methods on the
`BitOps` trait. Reusing `&` or `|` as bitwise operators would
collide with borrow and logical-or.

  (flags    Permission:Read.bitOr(Permission:Write))
  (readable flags.bitAnd(Permission:Read).ne(0))
  (shifted  byte.shiftLeft(4))
  (masked   word.bitAnd(0xFF))
  (inverted word.bitNot)

Stdlib trait (in stdlib under BitOps.trait):

  ;; BitOps.trait file content:
  (bitAnd    &self &other Self Self)
  (bitOr     &self &other Self Self)
  (bitXor    &self &other Self Self)
  (shiftLeft  &self &bits U8 Self)
  (shiftRight &self &bits U8 Self)
  (bitNot    &self Self)

Impls on U8 / U16 / U32 / U64 / I8 / I16 / I32 / I64.

;; MERGED FROM S5 — see gap-analysis.md §S5 and
;; bridge/clear.md §S5.

## UNARY OPERATORS (C6 — landed 2026-04-20)

Unary `-` and `!` landed in v0.21. Both appear as prefixes on
expressions.

Negation (-):
  (offset I32 -42)                    ;; literal negation
  (neg -x)                            ;; on a local
  (shift -self.Count)                 ;; on a field access

Logical NOT (!):
  (valid !self.Failed)
  (| !self.Ready
    ( True )  ^Option:None
    ( False ) Unit
  |)

Unary deref `*` (U1 — ACCEPTED 2026-04-21) --------------------

`*x` dispatches to the stdlib `Deref` trait's method. Methods-
over-operators direction: the operator is surface, the semantics
are a trait method.

  (derefed *boxedValue)                ;; unary * on a Box,
                                       ;; dispatches to Box:Deref:deref
  (payload *self.Inner)                ;; deref a field

Grammar (ExprUnary dialect):
  #UnaryDeref#_*_ <ExprUnary>

Separate from raw pointers (which stay Unspec'd). Deref applies
to smart-pointer types (Box, Rc, future Arc) — any type with a
Deref impl.
;; MERGED FROM U1 — ACCEPTED 2026-04-21 (see gap-analysis.md §U1)

## METHODS-OVER-OPERATORS RUBRIC (U17 — PICK-AND-MERGE)

S5 bitwise, S7 cast, and N3 assignment all land as stdlib
methods rather than operator syntax. That is consistent with
a proposed standing rubric rule:

  "Methods over operators for bit ops, casts, assignment, and
   similar. Stdlib traits, not new syntax."

Under that rubric, future operator-family additions default to
stdlib trait methods unless Li specifically carves out syntax.

;; PICK-AND-MERGE — Li to confirm this as standing rule; see
;; gap-analysis.md §U17.

## DYN SIGIL (U14 — PICK-AND-MERGE; semantics in outliers)

Syntactic shape (from bridge/small-decisions.md §S6):
`?{Trait}` at type position marks "unknown concrete type that
satisfies Trait."

  (emit ~&writer {?Writer} :msg String [~writer.write(msg)])
  (nextToken ~&src {?Iterator Token} {Option Token}
    [~src.next])
  (boxed {Box {?Callable U32 U32}} …)

Grammar:

  ;; Type.synth — add DynType
  #DynType#_?_{ <TypeApplication> }

Alternatives that were considered: `&{Trait}` (conflicts with
borrow), `{^Trait}` (conflicts with early return), a new
delimiter pair (all six allocated).

;; PICK-AND-MERGE — Li to confirm sigil `?{Trait}`; semantic
;; design (S6 — vtable vs discriminant vs no-dyn vs transient-
;; only) in outliers-v021.md.

## CLOSURES — Position A (S4 — PICK-AND-MERGE; A merged, B/C in outliers)

Position A (named-type impls of Callable) is the zero-grammar-
change baseline. A closure in Rust is an ad-hoc named struct
in aski, with an explicit impl of the `Callable` trait.

Filesystem path:
  Increment.struct

```aski
(@Amount U32)

```
Filesystem path:
  Callable[U32,U32]~Increment.impl

File content:

```aski
(call &self &input U32 U32 [input + self.Amount])

```
At a call site (inside some method body):

  (items self.Nums.map(&Increment {Amount 1}))

Stdlib trait (reference):

  ;; Callable.trait file content:
  {$Input $Output}
  (call &self $Input $Output)

;; PICK-AND-MERGE — Position A merged; Position B (inline
;; closure sugar desugaring to synthetic types) and Position C
;; (explicit-capture shorthand) remain OPEN. See outliers-v021.md
;; and bridge/big-decisions.md §S4.

## LITERAL PATTERN SCOPE (C3 — PICK-AND-MERGE)

LiteralPattern covers Int / Float / Str at match-arm position.
Proposed scope:

  (| code
    ( 0 )    "pending"                 ;; IntMatch
    ( 200 )  "ok"
    ( 3.14 ) "tau-adjacent"            ;; FloatMatch
    ( "hello" ) "greeting"             ;; StrMatch
    ( _ )    "other"
  |)

Bool is NOT a LiteralPattern — matched via variant patterns
`( True )` / `( False )` on a Bool variant-enum. Char is NOT
a LiteralPattern — matched via path patterns on the Char
library (e.g., `( Char:Upper:A )`).

Grammar:
  ;; Pattern.synth — add LiteralPattern, remove StringMatch (subsumed)
  #WildcardPattern#_
  #VariantBind#:Variant @binding
  #VariantAlt#[ +:Variant ]
  #VariantMatch#:Variant
  #LiteralPattern#:Literal    ;; covers Int, Float, Str

;; PICK-AND-MERGE — Li to confirm scope excludes Bool (via
;; variants) and Char (via U16 library). See gap-analysis.md
;; §C3 and bridge/clear.md §C3.

## POSTFIX OPERATORS — field access, method call, try-unwrap

Unchanged from v0.20. Left-to-right chaining.

  self.stage1(input).stage2.stage3(self.Config)

`expr.Field` — FieldAccess (Pascal suffix)
`expr.method(args)` — MethodCall (camel suffix)
`expr?` — TryUnwrap (on Result/Option)

## EXPRESSION ATOMS

Every atom form from v0.20 survives.

  &instance              BorrowExpr (shared borrow of a local)
  ~&instance             MutBorrowExpr
  self                   SelfRef
  :instance              InstanceRef (bare local)
  :Type:method(args)     PathCall
  :Type:Variant          PathVariant
  :Variant               BareVariant
  :Literal               LiteralExpr
  [ <Body> ]             InlineEval (block as expression)
  (| <Match> |)          MatchExpr
  [| <Loop> |]           LoopExpr
  {| <Iter> [body] |}    IterExpr
  { :Type +(:Field <Expr>) }  StructExpr
