## MATCH, LOOP, ITERATION, EXPRSTMT, OR-PATTERN, EARLY RETURN, TRY-UNWRAP — unchanged body grammar

All the in-body forms from v0.20 survive identical in v0.21.
These appear inside method bodies in `.impl` / `.effect` /
`.test-impl` / `.bench-impl` / `.derivation` / `.exec` files.

Match (inside a method body in Describe~Element.impl):

  (describe &self Quality (|
    ([Fire Air])      Active
    ([Earth Water])   Receptive
  |))

Match arm forms:
  _                       — WildcardPattern (C1, landed 2026-04-19)
  :Variant                — VariantMatch
  :Variant @binding       — VariantBind (binding = camel-of-payload-type)
  [:Var1 :Var2]           — VariantAlt (or-pattern)
  "literal"               — StringMatch

Struct destructuring pattern (U11 — PICK-AND-MERGE) --------

Recommended shape (Option A — pun on field name): the binding
name is derived from the field name, lowercased. Field `Width`
→ binding `width`; Field `Height` → binding `height`.

  ( Rectangle { Width Height } )     ;; binds width: F64, height: F64
  ;; in arm body: width * height

Full explicit form also available when rename is needed:

  ( Rectangle { Width w Height h } ) ;; explicit rename (if A allows)

Grammar sketch (under Option A):
  #StructPattern#{ :Type *( :FieldName ?@binding ) }
  #StructVariantBind#:Variant { *( :FieldName ?@binding ) }

;; PICK-AND-MERGE — Li to confirm Option A (pun on field) vs
;; B or C; see gap-analysis.md §U11 and
;; bridge/big-decisions.md C2+S10+N10.

if / if-let / while-let idiom (C4 — MERGED 2026-04-21) ------

No `if` grammar. Every conditional form is a match on Bool or
on Option/Result variants.

if / else (via match on Bool):

  (| self.ready
    ( True )   self.run
    ( False )  self.wait
  |)

if-let (via match with wildcard):

  (| self.result
    ( Some value ) [self.useValue(value)]
    ( _ )          Unit
  |)

while-let (while-loop whose body includes the match):

  [| self.queueHasWork
    (| self.dequeue
      ( Some task )  [self.handle(task)]
      ( None )       ^^
    |)
  |]

No grammar change — these are documentation of the idiom.
;; MERGED FROM C4 — see gap-analysis.md §C4 and
;; bridge/clear.md §C4.

Loop (inside a method body):

  (skipWhitespace ~&self [| self.atEnd == False
    [(| self.peek
      (Newline) self.advance
      (Space) self.advance
    |)]
  |])

Infinite loop pattern today is `[| true body |]`. See
gap-analysis.md §U19 for open alternatives.

Iteration:

  (printAll &self {| self.List.item
    [StdOut:print(item.Name)]
  |})

Iteration binding (N10 — clarification) ---------------------

The bit after `.` is a single camelCase binding name — one
name, one element per iteration. For iterating with an index
or with tuple-valued streams, the source expression must yield
a single structured type per step, not a pair:

  ;; over a Vec of IndexedItem (a named struct):
  {| self.Items.enumerate.pair
    [StdOut:print(pair.Index pair.Item.Name)]
  |}

There is no tuple-valued iteration source in aski — streams of
paired values are streams of named structs. Struct-destructure
inside the arm (U11) can unpack when that lands.

;; MERGED FROM N10 — see gap-analysis.md §N10.

Range expressions (S2 — MERGED 2026-04-21) -----------------

`..` and `..=` are multi-char operators at expression position.
Produce a range value usable as an iteration source or as any
expression.

  {| 0..10.step
    [StdOut:print(step)]
  |}

  {| 0..=max.stepIncl
    [self.process(stepIncl)]
  |}

  (window self.Cursor..self.Cursor + 16)  ;; bind a range

Grammar:

  ;; ExprRange.synth — new dialect between ExprCompare and ExprAnd
  <ExprCompare> #Range#_.._ <ExprCompare>
  <ExprCompare> #RangeIncl#_.._=_ <ExprCompare>
  <ExprCompare>

  ;; ExprAnd.synth — chain descends into ExprRange
  <ExprRange> #BinAnd#&& <ExprAnd>
  <ExprRange>

Lexer adds `..` and `..=`. Aski-core adds `Expr::Range {Start End}`
and `Expr::RangeIncl {Start End}`.

;; MERGED FROM S2 — see gap-analysis.md §S2 and
;; bridge/clear.md §S2.

ExprStmt (side effect in body, wrapped in `[...]`):

  [self.loadConfig]
  [self.connect]
  [~counter.set(total)]

Early return (`^expr` statement form):

  (find &self &key String {Option String} [
    (| self.containsKey(key)
      (False) ^Option:None
    |)
    Option:Some(self.get(key))
  ])

Try-unwrap (postfix `?` on Result/Option):

  (result self.compileFiles(files)?)

Break / continue / labeled break (U13 — PICK-AND-MERGE) -----

Three candidate spellings; Li picks one.

Candidate 1 — `^`-family composed (from small-decisions.md §S3):
  [| true [^^result] |]              ;; break-with-value
  [| cond [^^] |]                    ;; bare break
  [| cond [^~] |]                    ;; continue
  [| 'outer true [^^'outer result] |]  ;; labeled break

Candidate 2 — `<<` / `>>` bigrams:
  [| true [<<result] |]              ;; break-with-value
  [| cond [<<] |]                    ;; bare break
  [| cond [>>] |]                    ;; continue

Candidate 3 — method-style on a loop handle:
  [| 'loopHandle true [~loopHandle.break(result)] |]
  [| 'loopHandle cond [~loopHandle.continue] |]

;; PICK-AND-MERGE — Li to pick one candidate; see
;; gap-analysis.md §U13 and bridge/small-decisions.md §S3.
