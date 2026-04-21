## SELF IN EXPRESSIONS

`self` is an expression atom. `self.Field` is field access;
`self.method(args)` is a method call on self.

  (offset &self &delta Point Point
    {Point (Horizontal self.Horizontal + delta.Horizontal)
           (Vertical self.Vertical + delta.Vertical)})

Unchanged from v0.20.

## MUTATION (N3 — MERGED 2026-04-21)

`~name.method(args)` is a mutation statement — the mutation
marker `~` at expression position on a method call.

  (tick ~&self [
    [~self.Count.addAssign(1)]
    [~self.Last.set(Time:now)]
    self.Count
  ])

`~` never stands alone. It always modifies the thing being
made mutable: a local declaration (`~counter` — at the
declaration site), a borrow (`~&self`), or a method call
(`~counter.set(...)`).

Mutation is method-only. Stdlib trait `Counter $Value` carries
the general mutation surface:

  ;; Counter.trait file content (stdlib):
  {$Value}
  (set       ~&self &value  $Value)
  (addAssign ~&self &delta  $Value)
  (subAssign ~&self &delta  $Value)
  (mulAssign ~&self &factor $Value)

Impls on U8–U64, I8–I64, F32, F64.

Assignment `=` and compound `+=` are not grammar. Mutation
flows through method calls on mutable locals, on `~&self`, or
on stdlib primitive methods like `U32:set(...)` /
`U32:addAssign(...)`.

;; MERGED FROM N3 — see gap-analysis.md §N3 and
;; bridge/clear.md §N3. U7 (bare = and compound +=) remains
;; open — see outliers-v021.md.

## CAST / CONVERSION (S7 — MERGED 2026-04-21)

Zero grammar change. Stdlib traits `From` / `Into` / `TryFrom`
across numeric primitives. Narrowing conversions use explicit
lossy method names so the semantics are visible at the call
site.

  (widened   U32:from(byte))                          ;; widen U8 -> U32
  (narrowed  U8:truncate(wide))                       ;; explicit lossy
  (converted {Result U32 ConversionError}
             U32:tryFrom(big))                        ;; fallible

Stdlib traits (paths in stdlib):

  ;; From.trait
  {$Source}
  (from :value $Source Self)

  ;; Into.trait
  {$Target}
  (into self $Target)

  ;; TryFrom.trait
  {$Source $Failure}
  (tryFrom :value $Source {Result Self $Failure})

Narrowing operations use method names per op:
  truncate  — drop high bits (wrap modulo 2^N)
  saturate  — clamp to target min/max
  wrap      — explicit wrap-around (same as truncate for unsigned)

;; MERGED FROM S7 — see gap-analysis.md §S7 and
;; bridge/clear.md §S7. Narrowing form is (a) explicit lossy
;; method names — Li to confirm (a) vs (b) single TryFrom
;; vs (c) both; see outliers-v021.md.

## PATH SYNTAX

Paths use `:` as the separator.

  Element:Fire                       ;; variant of an enum
  Option:None                         ;; bare variant
  Option:Some(42)                     ;; data variant with arg
  Counter:new(0)                      ;; type-path method call
  U32:zero                            ;; type-path constant/method
  self:Item                           ;; trait's associated type (inside trait/impl)
  Shape:Rectangle                     ;; nested enum variant
  Token:Delimiter:LParen              ;; chained-nested variant
  Char:Upper:A                        ;; chained path through the Char library

Cross-module access uses `:` too — the module IS a name in
the same namespace as the type, because both are paths:

  shapes:Shape                        ;; type Shape in module shapes
  shapes:Shape:Rectangle              ;; nested variant of a cross-module type

Filename-level `@` (impl files only — `Trait@Module`) is
filesystem syntax; source-level path syntax uses `:` only.
