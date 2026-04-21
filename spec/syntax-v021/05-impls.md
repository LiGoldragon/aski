# Impls

Trait impls live in `[_]TraitPart~TargetPart.impl` files. The filename encodes the trait + target; the body is the impl body only.

## Filename grammar

```
[_]TraitPart~TargetPart.impl
```

**TraitPart:**

| Form | Meaning |
|---|---|
| `Trait` | bare trait name |
| `Trait[Arg,Arg,...]` | trait with type arguments |
| `Trait@Module` | qualified with module |
| `Trait@A@B` | chained qualifier (`A::B::Trait`) |

**TargetPart:**

| Form | Meaning |
|---|---|
| `Target` | concrete type |
| `Target[Arg,...]` | applied concrete type |
| `Target@Module` | cross-module target |
| `$` | blanket (any type) |
| `$(Bound)` | bounded blanket |
| `$(Bound+Bound)` | multi-bound blanket |

**Separators:** `~` = trait/target separator. `[...]` = argument list (comma-separated). `@` = module qualifier. `$` = blanket target.

## Content grammar

```
?<GenericSlot>
*<TraitImplItem>
```

**TraitImplItem forms:**

| Form | Meaning |
|---|---|
| `(AssocName Type)` | associated type binding |
| `{\| @AssocName Type Value \|}` | associated const binding |
| `(camelName ...body)` | method body |

## Simplest impl

```
Describe~Element.impl
```

```aski
(describe &self Quality (|
  ([Fire Air])      Active
  ([Earth Water])   Receptive
|))
```

```rust
impl Describe for Element {
    fn describe(&self) -> Quality {
        match self {
            Element::Fire | Element::Air => Quality::Active,
            Element::Earth | Element::Water => Quality::Receptive,
        }
    }
}
```

## Impl with associated-type binding and a method

```
Iterator~TokenReader.impl
```

```aski
(Item Token)
(next ~&self {Option Token} [
  (| self.cursor.geq(self.buffer.len)
    (true)  Option:None
    (false) [
      (token self.buffer.at(self.cursor).clone)
      ~self.cursor.addAssign(1)
      Option:Some(token)
    ]
  |)
])
```

```rust
impl Iterator for TokenReader {
    type Item = Token;
    fn next(&mut self) -> Option<Token> {
        if self.cursor >= self.buffer.len() { None }
        else {
            let token = self.buffer[self.cursor].clone();
            self.cursor += 1;
            Some(token)
        }
    }
}
```

## Generic impl

```
Container~RingBuffer.impl
```

```aski
{$Value{Clone}}
(push ~&self :value $Value [
  ~self.buffer.append(value)
])
```

```rust
impl<T: Clone> Container<T> for RingBuffer<T> {
    fn push(&mut self, value: T) {
        self.buffer.push(value);
    }
}
```

The body's generic slot binds `$Value`; both `Container<$Value>` and `RingBuffer<$Value>` share the parameter. The filename is the bare-head form `Container~RingBuffer.impl`; argument application happens in the body.

## Trait type-argument in the filename

```
Iterator[Token]~TokenReader.impl
```

```aski
(Item Token)
(next ~&self {Option Token} [ ... ])
```

Two equivalent encodings coexist:

- `Iterator[Token]~TokenReader.impl` — trait arg in the filename
- `Iterator~TokenReader.impl` — body supplies `Item=Token` via `(Item Token)`

The shorter form is more common; the longer form is self-documenting when scanning the filesystem.

## Trait with multiple type arguments

```
From[String]~Token.impl
```

```aski
(from :source String Token [
  Token:Ident(source)
])
```

```rust
impl From<String> for Token {
    fn from(source: String) -> Token {
        Token::Ident(source)
    }
}
```

Multi-arg example: `Translator[Input,Output]~Pipeline.impl`.

## Blanket impl

```
Describe~$.impl
```

```aski
{$Any{Debug}}
(describe &self Quality [ Active ])
```

```rust
impl<T: Debug> Describe for T {
    fn describe(&self) -> Quality { Active }
}
```

`$` alone at target position = blanket. The generic slot in the body binds the parameter and its bound.

### Bounded blanket via filename

```
Describe~$(Debug).impl
```

```aski
(describe &self Quality [ Active ])
```

Identical semantics to the previous example, but the bound lives in the filename rather than the body.

### Multi-bound blanket

```
Display~$(Clone+Debug).impl
```

```aski
(display &self String [ "bounded blanket Display" ])
```

```rust
impl<T: Clone + Debug> Display for T { ... }
```

## Cross-module impls

**Target in another module:**

```
Describe~Shape@shapes.impl
```

```rust
impl Describe for shapes::Shape { ... }
```

Chainable: `Shape@shapes@drawing` = `drawing::shapes::Shape`.

**Trait in another module:**

```
Describe@external~Element.impl
```

```rust
impl external::Describe for Element { ... }
```

**Both:**

```
Display@std~Shape@shapes.impl
```

```rust
impl std::fmt::Display for shapes::Shape { ... }
```

## Named impls (multiple per (Trait, Target))

The filename stem is the impl's identity. For multiple impls of the same (Trait, Target), append a hyphenated discriminator.

```
Iterator[Token]~TokenReader-fast.impl
Iterator[Token]~TokenReader-safe.impl
```

Activation at a call site (inside a method body):

```aski
{Iterator[Token]~TokenReader-fast}
(tokens self.source.iter)
```

`{...}` at statement position = impl activation directive, scoped to the current block.

## Impl with associated const binding

```
BoundedQueue~FastQueue.impl
```

```aski
(Item Token)
{| Capacity U32 256 |}
(push ~&self :value Token [ ... ])
```

```rust
impl BoundedQueue for FastQueue {
    type Item = Token;
    const CAPACITY: u32 = 256;
    fn push(&mut self, value: Token) { ... }
}
```

## Super-trait chain

```
DoubleEndedIterator~TokenReader.impl
```

```aski
(nextBack ~&self {Option Token} [
  ;; uses self.cursor — Item inherited from Iterator super-trait
  ...
])
```

`Self::Item = Token` is inherited from the `Iterator~TokenReader.impl` sibling; `veric` verifies consistency across impl files.
