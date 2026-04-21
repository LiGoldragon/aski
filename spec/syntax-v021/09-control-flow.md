# Control flow

All body-level control flow uses delimiter-disambiguated forms. No keywords.

## Match

`(| scrutinee arms |)` is the match form.

```aski
(describe &self Quality (|
  ([Fire Air])      Active
  ([Earth Water])   Receptive
|))
```

### Match arm forms

| Form | Name |
|---|---|
| `_` | WildcardPattern |
| `:Variant` | VariantMatch |
| `:Variant @binding` | VariantBind (binding is camel-of-payload-type) |
| `[:Var1 :Var2]` | VariantAlt (or-pattern over variants) |
| `"literal"` | StringMatch |
| `42` / `3.14` | IntMatch / FloatMatch |
| `true` / `false` | BoolMatch |

## Conditionals — match on Bool

No `if` keyword. Every conditional is a match.

```aski
(| self.ready
  (true)   self.run
  (false)  self.wait
|)
```

### if-let idiom

```aski
(| self.result
  (Some value) [self.useValue(value)]
  (_)          Unit
|)
```

### while-let idiom

The while loop's body contains the match that extracts and either runs or continues.

```aski
[| ? self.queueHasWork
  (| self.dequeue
    (Some task)  [self.handle(task)]
    (None)       Unit
  |)
|]
```

## Loops

Two loop forms, both delimited by `[| |]`.

**Infinite loop** — no condition:

```aski
[| body |]
```

**While loop** — `?` prefix marks the condition:

```aski
[| ? cond body |]
```

First-token decidable at loop-body-open: `?` means a condition follows; anything else means the body starts directly (infinite).

### Examples

```aski
(runForever ~&self Never [|
  [self.tick]
|])
```

```aski
(skipWhitespace ~&self [| ? self.atEnd.not
  (| self.peek
    (Newline) self.advance
    (Space)   self.advance
  |)
|])
```

The `?` sigil is also used for try-unwrap (postfix on expression) and dyn types (prefix on `{Trait}` at type position) — see [00-overview §Sigils](00-overview.md#sigils) for the full disambiguation table.

## Iteration

`{| source.binding body |}` — the source's iterator yields one element per step, bound to `binding`.

```aski
(printAll &self {| self.List.item
  [StdOut:print(item.Name)]
|})
```

The bit after `.` is a single camelCase binding name — one name, one element per iteration. For paired values, the source yields structured types (not tuples):

```aski
# over a Vec of IndexedItem (a named struct):
{| self.Items.enumerate.pair
  [StdOut:print(pair.Index pair.Item.Name)]
|}
```

There is no tuple-valued iteration source in aski — streams of paired values are streams of named structs.

## Range expressions

`..` and `..=` produce range values usable as iteration sources or general expressions.

```aski
{| 0..10.step
  [StdOut:print(step)]
|}

{| 0..=max.stepIncl
  [self.process(stepIncl)]
|}

(window self.Cursor..self.Cursor + 16)
```

## ExprStmt

A side-effectful expression used as a statement is wrapped in `[...]`:

```aski
[self.loadConfig]
[self.connect]
[~counter.set(total)]
```

## Early return

`^expr` at statement position returns from the enclosing method.

```aski
(find &self &key String {Option String} [
  (| self.containsKey(key)
    (false) ^Option:None
  |)
  Option:Some(self.get(key))
])
```

## Try-unwrap

Postfix `?` on a `Result` or `Option` expression:

```aski
(result self.compileFiles(files)?)
```

If the value is `Err`/`None`, the enclosing method returns it; otherwise the `Ok`/`Some` payload flows through.

## Break and continue

Not currently in v0.21. See [16-open-questions §Break and continue](16-open-questions.md#break-and-continue).
