; File-per-Public-Object — A Deep Analysis
; 2026-04-21 · research, not proposal

[← index](../multi-surface.md)

---

# What this doc is

A deep research pass on an **extreme design step** for aski: combining
the per-concern surfaces proposed in docs 00–10 with an even stronger
physical commitment — **one public top-level declaration per file**,
with the filename matching the declaration's name. The filesystem
becomes the namespace.

Concrete examples:

```
shapes/Shape.types        ;; contains exactly @(Shape ...)
shapes/Circle.impls       ;; contains exactly one @[... Circle]
iteration/Iterator.traits ;; contains exactly @[| Iterator ... |]
iteration/FastIter.impls  ;; contains exactly @[FastIter Iterator TokenStream [ ... ]]
config/MaxUsers.types     ;; contains exactly @{| MaxUsers U32 100 |}
```

This is **a step further than the multi-surface proposal**. The surface
split says "per-concern files, many declarations per file permitted."
File-per-object says "per-concern files, exactly one public
declaration per file, filename = declaration name."

The two commitments are orthogonal but compose. This doc studies how.

This is **analysis only**. Nothing here is a decision. No claim is
made that Li has approved any of this; every proposal is framed as
"would this work?" not "this is how it is."

---

# Table of contents

- §A. What file-per-object unlocks beyond per-concern
- §B. Grammar implications
- §C. Imports and references
- §D. Private helpers
- §E. Directory organization
- §F. Tooling and ecosystem
- §G. Edge cases
- §H. Risks and costs
- §I. Precedent
- §J. Integration with the per-concern proposal
- §K. Verdict: pros, cons, open questions
- §L. Transition sketch

---

# §A. What file-per-object unlocks that per-concern surfaces alone don't

The per-concern surfaces split a `.aski` file three ways — `.types` +
`.traits` + `.impls`. But within each of those, many declarations
coexist. A project might have `shapes.types` containing Shape, Quality,
Element, and ten others. The type definitions are still "a blob of
code in one file."

File-per-object takes the split one axis further: **each declaration
moves into its own file, named after itself.** The implications are
qualitatively different from merely splitting by concern.

## A1. Filesystem as namespace — imports machinery collapses

In the multi-surface proposal, every file begins with a module header
that names the module and lists imports:

```aski
;; parser.types
(Parser [shapes Shape Quality] [iteration Iterator])
@{Parser (@Stream TokenStream) ...}
```

If `Parser.types` only ever contains `Parser`, the filename already
says the module/declaration name. The `(Parser ...)` header duplicates
information the filesystem already encodes. Candidate simplification:
**the module header becomes the imports line only**, and the
declaration name drops because the filename supplies it.

```aski
;; parser/Parser.types
([shapes Shape Quality] [iteration Iterator])     ;; just imports
@{(@Stream TokenStream) ...}                       ;; name comes from filename
```

Or even: no header at all, with imports in a sibling file (see §C).

Either way, the cost of "module-header bureaucracy" falls because
identity lives in the path.

## A2. Grammar simplification — zero intra-file disambiguation

Today a `.types` file's Root.synth has four top-level alternatives
(Enum, Struct, Newtype, Const) plus a Module header. With
file-per-object, each file's root grammar has **exactly one alternative**:

- `Shape.types` → root = Enum
- `Point.types` → root = Struct
- `Counter.types` → root = Newtype (or Struct — but only one choice per file)
- `MaxUsers.types` → root = Const

The grammar would need either (a) an extra hint (e.g. `.enum.types`,
`.struct.types`) or (b) the first-token dispatch remains, but only
ONE top-level item is accepted.

Path (b) is lower-cost: keep today's first-token dispatch but enforce
"exactly one top-level construct, and its declared name must equal
the filename stem." Trivial check; no grammar change.

Gain: tooling can cache per-file rkyv with zero risk of "which decl
in this file changed?" — it's the one decl, identified by filename.

## A3. Mechanical refactoring — rename a type = rename a file

Today: rename `Shape` to `Form` means find every occurrence across
the codebase and rewrite. The declaration site is one of many textual
sites and a modern IDE handles it — but the textual duplication of
"which file declares Shape" is lost in the source.

With file-per-object: **the declaration site IS the filename**. A
rename is a `git mv Shape.types Form.types` plus ripgrep over uses.
Even without an IDE, the rename is mechanically complete because the
canonical declaration site is uniquely identified.

Extension: tools like `aski-rename Shape Form` become trivial to
write — find the file, rename it, grep for the old name in other
files, rewrite.

## A4. Precise dependency graph — per-object rebuild

veric today can cache per-file. With per-object files, cache
granularity matches **declaration granularity** — the unit of change.
Change `Shape.types`, only consumers of `Shape` rebuild. Change
`Circle.impls`, only things touching `Circle:describe` rebuild.

Rust's compile-time cost at the crate level stems partly from "one
file changes, many declarations revalidate." File-per-object dissolves
this: the change set is the file set.

## A5. Version control per-object history

`git log Shape.types` shows every change to Shape specifically —
not "every change to shapes.types that mentioned Shape alongside
other types." History becomes **declaration-scoped**.

For code review: diffs are about one declaration. For archaeology:
"who added this variant?" returns a precise answer. For blame: line
numbers stay small per-file, improving `git blame` usefulness.

## A6. Tooling find-by-name — trivial

"Find Shape" → `find . -name 'Shape.types'`. No parsing required.
No LSP index required. The filesystem IS the index.

"Find all Iterator impls" → `find . -name '*.impls' | xargs grep -l
'Iterator'`, or if the convention is `<ImplName>.impls` and the impl
name is first token after `[`, then `find . -name '*.impls' | xargs
rg '^\[(@)?[A-Z]\w* Iterator'`. Even more reliable: if impl files
follow a convention like `FastIter-for-TokenStream.impls` (target-aware
filenames), grep becomes near-O(1).

## A7. Natural ownership boundaries

Distributed teams carve up codebases by CODEOWNERS files. If every
public object has its own file, CODEOWNERS entries become precise:
`Shape.types @graphics-team`, `Iterator.traits @runtime-team`. No
shared-file conflicts.

## A8. Documentation per-object

If every public object has a file, attaching documentation (a leading
comment, a sibling `.md`, a `.doc` file) becomes natural. A tool can
generate per-object pages from `Shape.types` alone — it's the entire
definition.

## A9. What the per-concern split alone doesn't give you

The per-concern split gives you **categorical separation** (types vs
traits vs impls) but leaves **identity** diffuse inside each file.
File-per-object takes the separation down to the atomic unit.

These are complementary, not redundant. Per-concern says "what kind
of declaration"; file-per-object says "which declaration."

---

# §B. Grammar implications

## B1. The trait delimiter question

Today's v0.20 trait form:

```aski
@[| Iterator
  Item
  (next ~&self {Option self:Item})
|]
```

The `[|...|]` delimiter exists because at root level in a `.aski`
file, multiple top-level constructs can coexist — Enum, Struct,
TraitDecl, etc. — and each needs a distinct opener. `[|...|]` for
TraitDecl was chosen so every root construct has a unique first-token
(design §Delimiter-First).

If `.traits` files contain exactly one trait, and the filename is the
trait name, **the delimiter's purpose collapses**. There's no
disambiguation to do. Alternative grammars become possible:

**Option B-α: delimiters retained, no name inside**

```aski
;; iteration/Iterator.traits
@[|
  Item
  (next ~&self {Option self:Item})
|]
```

The trait name `Iterator` is supplied by the filename. `@` still
marks public. `[|...|]` still marks trait body. Grammar stays
identical to v0.20 except the trait-name slot is gone.

**Option B-β: no delimiter, just content**

```aski
;; iteration/Iterator.traits
@
Item
(next ~&self {Option self:Item})
```

The file IS the trait body. First character (`@` or nothing) = vis.
Rest of file = items. No opening or closing delimiter at root.

This is the most radical step. It breaks design.md's §Delimiter-First
commitment at the root level. But the rationale for §Delimiter-First
is that **position-plus-delimiter disambiguates categories**. If the
file extension plus filename already picks the category and name,
delimiters at root are redundant noise.

**Option B-γ: delimiter optional, canonical with**

Accept both. Style guide says "include the delimiters for consistency
with nested forms"; tooling normalizes.

Recommendation among these: **B-α** is the safest. Preserves the
grammar structurally, eliminates redundancy, doesn't break other docs
or habits. B-β is cleaner aesthetically but forks too far from today.

## B2. Struct example before/after

Today (multi-surface proposal):

```aski
;; shapes.types
(ShapesModule [core Quality])

@{Point (@Horizontal F64) (@Vertical F64)}

@{Counter (@Count U32) (Cache U32)}

@{Drawing (@Shapes {Vec Shape}) @Name}
```

Under file-per-object with option B-α:

```
shapes/
  Point.types
  Counter.types
  Drawing.types
  _imports.types      ;; or sibling file with imports, see §C
```

```aski
;; shapes/Point.types
@{(@Horizontal F64) (@Vertical F64)}
```

```aski
;; shapes/Counter.types
@{(@Count U32) (Cache U32)}
```

```aski
;; shapes/Drawing.types
@{(@Shapes {Vec Shape}) @Name}
```

Each file holds one decl. `@{...}` with no name slot. Filename = name.

## B3. Enum example

Today:

```aski
@(Shape
  (Circle F64)
  {Rectangle (Width F64) (Height F64)}
  (Triangle F64))
```

File-per-object:

```aski
;; shapes/Shape.types
@(
  (Circle F64)
  {Rectangle (Width F64) (Height F64)}
  (Triangle F64))
```

The name `Shape` is supplied by `Shape.types`. The leading `@`
still marks public; the enum body follows. The first `(Circle ...)`
is a variant, not the name — the grammar knows this because it's in
a `.types` file whose root is "one enum" and expects variants
immediately after `@(`.

## B4. Generic slot

Today generics are a slot after the decl name:

```aski
@(Option {$Value} (Some $Value) None)
```

With no name, generics become the first slot:

```aski
;; collections/Option.types
@({$Value} (Some $Value) None)
```

The grammar says: after `@(` optionally read `{...}` as generics, then
read variants. No change in complexity; just the decl name is
dropped.

## B5. Trait with associated types and generics

Today:

```aski
@[| Ord {PartialOrd Eq}
  (compare &self &other Self Ordering)
|]
```

File-per-object (B-α):

```aski
;; cmp/Ord.traits
@[| {PartialOrd Eq}
  (compare &self &other Self Ordering)
|]
```

Super-traits and generic params still live in `{...}` as the first
slot inside the trait delimiter — same syntax, just the name slot
is elided.

## B6. Impl file — the trickiest case

An impl file carries **two names in addition to the file stem**: the
trait and the target type. The impl name itself is the third. File-per-
object has to pick which one the filename encodes.

Today (multi-surface):

```aski
@[FastIter Iterator TokenStream [
  (next ~&self {Option Token} [ ... ])
]]
```

Three names: `FastIter` (impl name), `Iterator` (trait), `TokenStream`
(target). Candidate filename schemes:

**Scheme 1: Filename = impl name**

```
impls/FastIter.impls
```

```aski
;; impls/FastIter.impls
@[Iterator TokenStream [
  (next ~&self {Option Token} [ ... ])
]]
```

Filename gives impl name. Inside: trait + target + body.

**Scheme 2: Filename = impl + trait + target, three-part**

```
impls/FastIter-Iterator-TokenStream.impls
```

More explicit but filenames get long. Wins: grep-by-trait and
grep-by-target become trivial — `ls impls/*-Iterator-*.impls` finds
all Iterator impls.

**Scheme 3: Directory-encoded**

```
impls/Iterator/TokenStream/FastIter.impls
impls/Iterator/TokenStream/SafeIter.impls
impls/Iterator/Bytes/DefaultBytes.impls
```

Directory is `Trait/Target/ImplName.impls`. Filesystem IS the impl
graph. `ls impls/Iterator/TokenStream/` lists every impl of
Iterator-for-TokenStream — exactly the coherence query veric does.

**Scheme 4: Directory-encoded, flipped**

```
impls/TokenStream/Iterator/FastIter.impls
```

Filesystem groups by target type first. Useful for "show me every
trait this type implements."

Either Scheme 3 or Scheme 4 makes the filesystem literally represent
the impl graph. Scheme 3 reads better if the primary question is
"who implements this trait?" (the ecosystem angle). Scheme 4 reads
better if the primary question is "what does this type do?" (the
object-oriented angle).

Analysis conclusion: **Scheme 3** (Trait/Target/Impl.impls) aligns
best with aski's trait-first paradigm. Every trait becomes a
directory; every target gets a subdirectory; every named impl is a
leaf file.

## B7. Impl body without the opening metadata

With Scheme 3, the file becomes tiny:

```aski
;; impls/Iterator/TokenStream/FastIter.impls
@[
  (next ~&self {Option Token} [ ... tight loop ... ])
]
```

No impl name, no trait name, no target — all in the path. Only the
body (and the public/private `@`) inside.

Is this still `[...]` style? The outer delimiter has nothing left to
disambiguate. A reasonable alternative:

```aski
;; impls/Iterator/TokenStream/FastIter.impls
@
(next ~&self {Option Token} [ ... ])
```

Drop the outer delimiter. The file IS the impl body. Each top-level
`(methodName ...)` form is an impl item. Associated-type bindings
(`(Item Token)`) and associated-const bindings (`{| BatchSize U32
256 |}`) appear at file level.

This is analogous to the trait case (B-β). Clean. Aggressive.

## B8. The "surface + filename = (kind, name)" principle

A pattern emerges: **surface (extension) encodes kind; filename
encodes name.** Body is the structural content, with no name in it.

- `.types` surface, Enum-first: Enum declaration, name from filename
- `.types` surface, Struct-first: Struct declaration
- `.types` surface, Newtype-first: Newtype
- `.types` surface, Const-first: Const
- `.traits` surface: one trait, name from filename
- `.impls` surface: one impl, keys from path, name from filename

If we want each `.types` file to be unambiguous, we need further
split: `.enum.types`, `.struct.types`, etc. — OR accept that the
first-token-inside-file disambiguates (currently `(`, `{`, `(|...|)`,
`{|...|}`).

Alternative: **sub-extensions**.

```
shapes/Shape.enum.types
shapes/Point.struct.types
shapes/Counter.newtype.types
shapes/MaxUsers.const.types
```

Kind-specific sub-extension + filename = name. Grammar per file is
a single alternative. Tooling sees the kind without parsing.

This is more verbose but more honest. Style choice.

---

# §C. Imports and references

## C1. The core question

If the filesystem IS the namespace, do files still need `use` /
`import` / module headers?

## C2. The default — yes, but shorter

Even with file-per-object, a file that references `Shape` needs to
tell the compiler where `Shape` lives. The filesystem has many
possible `Shape` files; resolution needs a scheme.

### Option C2-α — explicit imports per file

Keep today's module header, minus the module-name slot (because the
file IS the module):

```aski
;; impls/Iterator/TokenStream/FastIter.impls
([shapes Shape] [lex Token TokenStream])
@
(next ~&self {Option Token} [ ... ])
```

Each file declares what it pulls in. Disadvantage: every file needs
its own import block, duplicating imports across impls of the same
type/trait.

### Option C2-β — per-directory imports

One `_imports.types` or `.imports` file per directory supplies
imports for every file in that directory:

```
impls/Iterator/TokenStream/
  _imports                ;; [shapes Shape] [lex Token TokenStream]
  FastIter.impls
  SafeIter.impls
```

Shared imports in `_imports`; per-file overrides possible.

### Option C2-γ — absolute paths

No imports; every reference is a path from the project root:

```aski
;; impls/Iterator/TokenStream/FastIter.impls
(next ~&self {Option lex/Token} [ ... ])
```

`lex/Token` directly references the file `types/lex/Token.types` (or
similar — resolution rules TBD).

Disadvantage: paths pollute source code. Advantage: never ambiguous,
no import section to maintain.

### Option C2-δ — glob/index inference

The compiler walks the project tree, indexes every public declaration
by name, and resolves bare references automatically. Name collisions
across directories surface as errors; the user disambiguates with a
path prefix only when needed.

This is Rust-style `use` inference carried to its extreme. Python
and Go touch on this; Java does not.

## C3. Recommendation

**Option C2-δ (name-indexed) with C2-γ path escape** is likely the
sweet spot:

- Compiler indexes every `<Name>.<kind>.<surface>` file in the project.
- Bare names resolve via the index.
- Ambiguity (two `Shape` files in different directories) → error,
  requires path-qualified form.
- Cross-project imports (from dependencies) use explicit paths.

Example:

```aski
;; impls/Iterator/TokenStream/FastIter.impls
@
(next ~&self {Option Token} [        ;; Token resolves via project index
  (buf self.buffer)                    ;; Local, no resolution needed
  (cur self.cursor)
  ...
])
```

No import block. Name resolution is project-wide first, explicit-path
fallback.

## C4. Name collisions across directories

With name-indexed resolution, two `Shape.types` files in different
directories cause an **ambiguity error**. Disambiguation:

- `shapes/Shape` vs `drawings/Shape` — full path from project root.
- Rename one of them.

aski's §Names Are Meaningful already leans against this: if you have
two different Shapes they have different roles; rename to
`GeometricShape` and `UiShape` per role.

The design pressure is toward **globally unique names**. This is a
stronger version of what aski already believes.

---

# §D. Private helpers

aski's §No Free Functions says every callable is a trait method.
Rust allows private helper functions alongside a public struct in the
same file; aski's equivalent is private impls (private trait method
definitions or private impl types on an anonymous trait).

The question: in file-per-public-object, where do private helpers
live?

## D1. Option D-α — sibling file with underscore prefix

```
shapes/
  Shape.types
  _ShapeHelper.impls          ;; private helper impl
  _normalizeShape.impls       ;; private helper
```

Leading underscore = private (Python convention). Scope: the helper
is visible only to files in the same directory.

Issue: `_` is a valid aski pattern (wildcard), and by case rule,
file names follow the declaration names inside — so if the declaration
is `@(Shape ...)` the filename is `Shape`; if a helper is
`(normalizeShape ...)` — but wait, helpers in aski are impls, not
free functions. Let me rephrase.

A private helper in aski is either:
1. A private trait declaration + private impl (very formal).
2. A private method on an existing trait's impl of the type (lives
   in the same impl).

If the helper genuinely belongs to one type/trait, it lives in that
file — adding another method to an existing impl. If it's a
cross-cutting helper, it becomes its own private trait + impl.

For private trait + impl:

```
iteration/
  Iterator.traits              ;; public trait
  _cursor-advance.traits       ;; private helper trait (leading _)
  _cursor-advance.impls        ;; private impl
```

The `_` prefix on the filename marks the object as private. Grammar
doesn't parse `_` as visibility (that's `@`), but the filesystem
convention says "files starting with `_` are private, never importable
across directories."

Question: is this different from the `@` visibility sigil? Two
orthogonal mechanisms:
- `@` inside the file → "exported from THIS module" (file-level vis)
- `_` prefix on filename → "module-private convention"

A public `@` inside `_cursor-advance.impls` would still be visible
within the directory (other files in the same dir can reference it)
but not across directories (filesystem convention blocks).

## D2. Option D-β — a dedicated `_private/` subdirectory

```
iteration/
  Iterator.traits
  TokenStream.types
  _private/
    cursor-advance.traits
    cursor-advance.impls
```

Files under `_private/` are scoped to the enclosing directory. Cross-
directory access disallowed. Clean but adds a layer.

## D3. Option D-γ — inlined as nested types

aski already has nested types (`(|...|)` and `{|...|}`). A private
helper could be a nested trait or nested impl inside the public file:

```aski
;; iteration/Iterator.traits
@[|
  Item
  (next ~&self {Option self:Item})

  [|
    ;; private nested helper trait
    ...
  |]
|]
```

Issue: today's spec doesn't allow nested traits or nested impls.
Would need to add that, carefully.

## D4. Option D-δ — case-rule coherence

Per aski's case rule: Pascal = structural compile-time things; camel =
instances. A file named `Shape.types` declares the Pascal structural
object `Shape`. A private helper that's not a type or trait is **not
Pascal-structural** — but aski has no free functions, so every helper
IS a trait/impl pair, which is Pascal.

Thus every aski file (public or private) names a Pascal thing. The
`_` prefix (or `_private/` directory) is a **filesystem-level
visibility marker** orthogonal to the Pascal content rule. The case
rule is unaffected.

## D5. Recommendation

**Option D-β (`_private/` subdirectory)** is the cleanest. Avoids
ambiguity with wildcard `_`, avoids polluting filenames with a
prefix, and scopes privacy at the directory level — which matches
how most languages treat private (crate-private, package-private).

---

# §E. Directory organization

## E1. The file-count problem

A project with 200 public items = 200 files. Plus impls (potentially
many per (Trait, Target) pair). Plus derivations. Plus platform
variants. A real codebase could hit 1000+ files easily.

This is real cost. Rust projects top out around dozens of files per
crate; file-per-object could 10–50× that.

Mitigation must come from directory structure.

## E2. Recommended layout

```
my-project/
  src/
    types/
      geometry/
        Point.types
        Circle.types
        Rectangle.types
        Shape.types
      collections/
        Vec.types
        Option.types
      tokens/
        Token.types
        TokenStream.types
    traits/
      iteration/
        Iterator.traits
        DoubleEndedIterator.traits
      comparison/
        Ord.traits
        PartialOrd.traits
      display/
        Debug.traits
        Display.traits
    impls/
      Iterator/
        TokenStream/
          FastIter.impls
          SafeIter.impls
        Vec/
          VecIter.impls
      Ord/
        Counter/
          Default.impls
    effects/
      filesystem/
        LocalFs.effects
      clock/
        SystemClock.effects
    derivations/
      debug/
        DebugStruct.derivations
        DebugEnum.derivations
    test-impls/
      Iterator/
        TokenStream/
          Mock.test-impls
    exec/
      Main.exec
    rfi/
      posix/
        FileSystem.rfi
        Time.rfi
```

Three levels deep typical. Level 1 = surface. Level 2 = conceptual
grouping (geometry, tokens). Level 3 = for impls, Trait/Target. Level
4 = impl/test/bench variant.

## E3. "Module" redefined

In today's aski, a module is a `.aski` file (one per module). With
file-per-object, the concept of "module" shifts: **a directory
becomes the module**, and files inside are the module's declarations.

This aligns with Rust's `mod shapes;` pointing at `shapes/` directory
containing multiple files (or `shapes.rs` with multiple items). File-
per-object dogmatically picks "directory is module."

Cross-module dependency: reference `types/geometry/Shape` from an
impl in `impls/...`. Directory nesting = module hierarchy.

## E4. Surface-first vs concept-first top-level split

Two choices for level 1:

**Surface-first** (shown above):

```
src/types/geometry/Shape.types
src/traits/iteration/Iterator.traits
src/impls/Iterator/TokenStream/FastIter.impls
```

Navigation: "show me all types" = `ls src/types/`.

**Concept-first**:

```
src/geometry/types/Shape.types
src/geometry/traits/Shape2d.traits
src/geometry/impls/Shape/Default.impls
src/iteration/types/TokenStream.types
src/iteration/traits/Iterator.traits
src/iteration/impls/Iterator/TokenStream/FastIter.impls
```

Navigation: "show me everything about geometry" = `ls src/geometry/`.

Surface-first favors **cross-cutting surface operations** (audit all
effects, generate all trait docs). Concept-first favors **cross-cutting
concept operations** (refactor geometry package, move geometry to a
new repo).

Mature codebases typically want both views. Tooling can provide both
(virtual views over either layout). The on-disk layout picks one.

Recommendation: **surface-first** at top-level; concept directories
inside each surface. Matches the multi-surface proposal's emphasis
on surface as the unit of architectural truth.

## E5. Cross-directory dependencies

With directory-as-module, a dependency from `types/geometry/Shape`
to `types/geometry/Quality` is intra-module (same directory) — bare
name resolves.

A dependency from `impls/Iterator/TokenStream/FastIter` to
`types/tokens/Token` is cross-module — requires full path or a
project-wide name index.

veric enforces surface-ordering rules (§01-surfaces §Import model):
.types can import only from .types, etc. Those rules carry over
unchanged. The per-object split is orthogonal.

---

# §F. Tooling and ecosystem

## F1. IDE go-to-definition

Go-to-definition becomes **filesystem lookup**:

- Click `Shape` anywhere → open `types/geometry/Shape.types`.
- Click `Iterator:next` → open `traits/iteration/Iterator.traits` +
  scroll to `next` method signature.
- Click `tokens.iter` → resolve Iterator impl on TokenStream in scope
  → open `impls/Iterator/TokenStream/<ActiveImpl>.impls`.

No LSP indexing needed for the first lookup — it's just path resolution.

## F2. Rename refactoring

As discussed in A3, a rename is:

1. `mv Shape.types Form.types`
2. `rg -l Shape src/ | xargs sed -i 's/\bShape\b/Form/g'` — or a
   structured aski-aware rewrite.

Compare to Rust: rename needs full syntax-aware traversal because the
name appears in many files without filesystem anchoring. aski's
file-per-object makes the declaration site unique.

## F3. Build system — file-level caching

Every `Shape.types` compile produces one `Shape.types.rkyv`. Cache
key: file content hash + imports closure hash. Change `Shape.types`
→ only that one rkyv invalidates. Downstream rebuild is precisely
the set of files depending on `Shape`.

Comparable to Rust's incremental compilation but at declaration
granularity instead of crate granularity. Fine-grained.

## F4. Version control

### F4-a. Merge conflicts

Merge conflict on `Shape.types` means two people edited `Shape`. Merge
conflict rate drops because "edit different things" = "edit different
files."

But: lots of small files create **many small commits**. A PR that
touches ten objects touches ten files. Reviewers see ten diffs.

Mitigation: tooling summarizes per-concern ("this PR modified 3 types,
2 traits, 5 impls") instead of per-file.

### F4-b. Bulk operations

"Rename all fields Horizontal → Width across the project" touches
dozens of files. A single textual sed command crosses all of them.
No worse than today. Maybe better: the diff is trivially auditable
per file.

### F4-c. History exploration

Per-object `git log` is a win (A5). Per-project `git log` with
10,000 files has many entries but filtering by directory
(`git log src/impls/Iterator/`) is precise.

## F5. Package/crate structure (lojix)

If aski gets a package manager (`lojix`), the manifest expresses:

```
[my-crate]
version = "0.1.0"

[exports]
types = "src/types/"
traits = "src/traits/"
impls = "src/impls/"
effects = "src/effects/"

[imports]
std = { package = "aski-std", version = "0.1" }
collections = { package = "collections-aski", version = "0.2" }
```

A consumer of `my-crate` imports specific types by path:

```aski
;; consumer impl
(processPoint &self &point my-crate/types/geometry/Point ... )
```

Or with a bare-name project index (C2-δ), the `my-crate` import is
registered globally and `Point` resolves without path.

`lojix` becomes a tree-mounting tool: your dependencies' `src/types/`
trees get grafted under your project's name-resolution space, with
namespacing by crate name.

---

# §G. Edge cases

## G1. Mutually recursive types — same file? Separate?

```rust
enum Tree<T> {
    Leaf(T),
    Branch(Box<Tree<T>>, Box<Tree<T>>),
}
```

Tree references itself. Under file-per-object, `Tree.types` contains
the Tree enum. Self-reference is fine — the name `Tree` inside the
file refers to the declaration the file holds (the same binding).

Multi-type mutual recursion:

```rust
enum Expr { Literal(i64), Block(Block) }
struct Block { stmts: Vec<Stmt>, result: Box<Expr> }
struct Stmt  { ... }
```

`Expr.types`, `Block.types`, `Stmt.types` — three files. Each
references the others by name. Name resolution walks the project
index to find them. No file-level ordering issue because aski doesn't
have "forward declarations" — types are resolved after full parse.

veric must tolerate circular import graphs among types, which it does
already (type definitions don't compute state during load; they
declare shape).

## G2. Generics referring to the declaring type

```rust
struct Pair<A, B> { left: A, right: B }
```

`Pair.types` declares `Pair`. The type parameters `$Left`, `$Right`
are local to the declaration — they're just slot-fillers, not
project-wide names. No file needed for them.

No issue.

## G3. Nested types — files or inline?

Today's aski permits nested enums `(|...|)` and nested structs
`{|...|}` inside a parent:

```aski
@(Token
  (Ident String)
  (| Delimiter LParen RParen |)
  Newline)
```

`Delimiter` is nested inside `Token`; it's accessed as
`Token.Delimiter.LParen`.

Under file-per-object, two choices:

**Option G3-α — nested stays inline**

The nested `Delimiter` stays inside `Token.types`. Its identity is
"Delimiter inside Token" — it's not a top-level object, so the
file-per-OBJECT rule doesn't apply (the rule is about top-level
public declarations).

This preserves aski's scope-as-a-tree model. Nested types are
natural children of their parent; promoting them to siblings would
lose the ownership relationship.

**Option G3-β — nested becomes `Token/Delimiter.types`**

Promote the nested type to its own file in a subdirectory named after
the parent:

```
types/tokens/
  Token.types                  ;; (Ident String) ... (Delimiter goes in Token/)
  Token/
    Delimiter.types            ;; nested type, now its own file
```

Access: `Token/Delimiter:LParen`. The parent-child scope becomes the
directory nesting.

This is elegant but loses the `(|...|)` vs `{|...|}` sigils. It also
changes how scope resolution works — scope becomes directory-path,
not lexical.

**Recommendation**: **Option G3-α** (nested stays inline). The
file-per-object rule targets **top-level public declarations**. Nested
types are not top-level; they're scoped to their parent. Keep them
in the parent's file.

This means `Token.types` might contain more than one structural
decl (the outer enum plus nested types/structs). That's OK — they
all belong to `Token`. The "one public declaration" rule means one
**top-level exportable name**; nested names are accessed via the
parent.

## G4. Impls revisited — what does FastIter.impls contain?

Under Scheme 3 (Trait/Target/ImplName.impls):

```
impls/Iterator/TokenStream/FastIter.impls
```

The file says "FastIter is an impl of Iterator for TokenStream."
Content:

```aski
@
(next ~&self {Option Token} [ ... body ... ])
(Item Token)
```

No ambiguity. FastIter's trait (Iterator) is in the path; the target
type (TokenStream) is in the path; the impl name (FastIter) is the
filename.

## G5. Trait objects / dyn — how does veric find all impls?

veric walks `impls/Iterator/*/` to enumerate every (target, impl) pair
for Iterator. Each subdirectory = one target type. Each file = one
named impl.

```
impls/Iterator/
  TokenStream/
    FastIter.impls
    SafeIter.impls
  Bytes/
    DefaultBytes.impls
  Vec/
    VecIter.impls
```

For `dyn Iterator`, veric needs the full list of types implementing
Iterator — which is `ls impls/Iterator/`. Directory-is-the-query.

For coherence per (Iterator, TokenStream), veric reads
`impls/Iterator/TokenStream/*.impls` — the precise coherence query.

Each coherence check is a directory listing. No whole-project scan.

## G6. Blanket impls

A blanket impl is `impl<T: Bound> Trait for T`. Its target is a
generic parameter, not a concrete type. Directory placement:

```
impls/Iterator/$Any/BlanketAny.impls
```

Reserved directory name `$Any` (or similar) represents "any type
matching the bound." File contains the blanket impl with its bound
constraint.

Or: blanket impls get a flat sibling directory:

```
impls/Iterator/_blanket/BlanketAny.impls
```

Subtle; requires decision.

## G7. Derivations

A derivation rule is "for every type matching shape X, synthesize
impl Y." It doesn't bind to a specific target. Placement:

```
derivations/
  Debug/
    DebugStruct.derivations
    DebugEnum.derivations
  Clone/
    CloneStruct.derivations
  JsonSerialize/
    JsonSerializeStruct.derivations
```

One directory per trait the derivation produces impls of. One file
per rule.

---

# §H. Risks and costs

## H1. File count explosion

Analyzed in §E1. A 200-object project becomes 200+ files. Plus impls,
tests, derivations. Realistic: 500–2000 files for a mid-size project.

**Costs:**
- Filesystem operations (ls, grep without --mmap) slower.
- Some editors (VSCode, IntelliJ) handle 10k-file projects fine;
  some (older Atom, Nano) struggle.
- Backup/sync tools (Dropbox, OneDrive) flail on many-small-files.

**Mitigations:**
- Directory depth keeps per-directory count sane (100s per dir).
- Monorepo tools (Buck, Bazel) handle millions of files — not a
  scaling wall.
- Build caching is per-file, which is a win not a loss.

## H2. Directory navigation becomes critical

"Where do I put this file?" becomes a daily decision. Without
discipline, directories drift.

**Mitigations:**
- Strict layout convention (like §E2).
- Linter rejects files in wrong directories (check filename stem
  matches declaration name; check surface matches extension).
- Tooling provides "new declaration" command that places the file
  correctly.

## H3. Editor struggles with many tabs

If every edit opens a new tab, editors crowd. But: editors have had
solutions (fuzzy file-finders, tab stashing) for decades. Not a real
concern.

## H4. Merge conflicts become noisy

Discussed in F4-a. Small files mean many tiny commits for large
refactors. Tooling summarization helps.

## H5. Learning curve

Newcomers face a bigger filesystem upfront. "Where does this go?" is
a question they don't have in Rust.

**Mitigations:**
- Starter templates with standard layout.
- Per-surface subdirectory convention teaches by structure.
- Multi-surface (which is already a paradigm step) already asks this
  question — file-per-object is a refinement of discipline, not a
  new paradigm.

## H6. IDE and LSP work

Most LSPs assume file-level or crate-level scope. Per-object scope
needs:
- Project-wide name index (fast).
- Per-file incremental parse/typecheck.
- Cross-file symbol resolution without re-parsing everything.

aski's rkyv-per-file pipeline already supports this. The LSP server
caches per-file rkyv; opening a file re-parses it; cross-references
query the name index.

## H7. Granularity vs readability trade-off

Reading a type family in Rust: open one file, see Shape + its variants
+ related helpers in context. Reading the same family in file-per-
object aski: navigate a directory tree, open multiple files.

For small related groups, the split can hurt readability. For large
groups, it helps.

**Mitigations:**
- Tooling "collect view" that reconstructs a virtual single-file view
  of a directory.
- IDE "show all in module" feature.

## H8. Version churn

A refactor that renames a type touches one file (the declaration) plus
all consumers. Under Rust, the declaration file is one of many; under
file-per-object, it's a `git mv`. Churn in the consumer files is the
same order of magnitude — the new name has to propagate either way.

Net neutral.

---

# §I. Precedent

## I1. Java — one-public-class-per-file

Java enforces: "one public class per file, filename = class name."
It works at massive scale (tens of thousands of classes per large
enterprise project). Tooling (IntelliJ, Eclipse) is mature around it.

Learnings from Java:
- Good IDE is non-negotiable. File-per-class without good navigation
  is painful.
- Directory hierarchy matches package hierarchy. Java's `com/foo/bar/`
  is exactly aski's proposed `types/geometry/`.
- Inner classes escape the rule (nested classes stay in the parent).
  aski's nested types match this precedent (see §G3).
- Refactoring is mechanical. Rename = file move + content update.

Verdict: **strong precedent for file-per-object at scale**. The
Java ecosystem proves it's not a toy idea.

## I2. Ruby — one-class-per-file convention

Ruby doesn't enforce one-class-per-file but convention is strong.
RubyGems, Rails, and most libraries follow it. Autoloaders depend on
filename = class name (with snake_case file → CamelCase class).

Works because: (1) the ecosystem agreed on convention; (2) Rails
autoload made it the path of least resistance.

Learning: **convention without enforcement drifts**. Java's enforcement
is stronger than Ruby's convention. aski would benefit from
enforcement to preserve the invariant.

## I3. Rust — mod system (file = module)

Rust's file = module, with multiple items per file. Closer to today's
`.aski` than file-per-object. Advantages: compact files, lexical
grouping. Disadvantages: bigger files, less mechanical refactoring.

Rust's `mod` system with `pub use` re-exports tries to give Java's
navigability without the file proliferation. It works but requires
author discipline.

## I4. Smalltalk — class browser

Smalltalk historically stored code in an image (binary blob), not a
filesystem. The class browser navigated by class/method. Filesystem
was irrelevant.

Modern Smalltalks (Squeak, Pharo) have filesystem serialization
(Monticello, Tonel) that's very much file-per-class.

Learning: **the mental model is "objects as primary units, not files"**.
Smalltalk proved this model works for programmers. File-per-object in
aski imports this mindset into a filesystem-native tool.

## I5. OCaml — one module per file

OCaml has one module per `.ml` file (with `.mli` signatures). Modules
contain multiple types/values, so it's not file-per-object. But the
file = module invariant is strong and universally used.

Learning: **file = module is a fine scaling strategy**. aski's "file =
object" refinement is one level deeper.

## I6. Haskell — module-per-file

Haskell modules span one file, contain many declarations. Functional
programming scaled with this without file-per-object. Large Haskell
projects do split by topic (one data type per module is common for
big types).

Learning: **per-object split isn't required**; per-module is enough.
But aski's trait+impl+coherence model gains specific wins from per-
object that Haskell's module model doesn't need.

## I7. Clojure — namespace per file

Clojure has namespaces, one per file by convention. Multiple defs per
file. Similar to Rust.

## I8. Unreal / Unity asset files

Game engines store each asset (texture, mesh, script) in its own file.
The filesystem IS the content index. Asset pipelines (reimport,
rebuild) operate per-asset. Precedent for file-per-thing at massive
scale (AAA games ship with 100K+ asset files).

---

# §J. Integration with the per-concern surface proposal

## J1. How they combine

The multi-surface proposal (docs 00–10) splits by **concern**: types
vs traits vs impls vs effects etc. File-per-object splits by **identity**:
one declaration per file, named by filename.

These are orthogonal axes:
- Multi-surface alone: `shapes.types` + `shapes.traits` + `shapes.impls`
  — three files, each with many declarations.
- File-per-object alone: `Shape.aski` + `Quality.aski` + `Element.aski`
  — many files, but each might hold a type + its impls (no concern split).
- Combined: `types/Shape.types` + `traits/Describe.traits` +
  `impls/Describe/Shape/Default.impls` — many files, each with one
  declaration on one concern.

**The combination is the extreme endpoint**. Every declaration is
(concern, name) uniquely identified, with filesystem encoding both.

## J2. Compatibility

File-per-object respects every constraint the multi-surface proposal
imposes:
- Surface import rules (`.types` imports only `.types`) — preserved.
- Surface-specific grammars — preserved (each file still has one
  decl, parsed by its surface's root).
- Coherence enforcement (global, scope-aware) — preserved, and
  directory structure makes the coherence query trivial (§G5).
- Effect tracking via import closure — preserved, finer-grained.
- Derivation rules — preserved (§G7).

Every multi-surface win holds or improves under file-per-object. The
file-per-object overlay doesn't require changes to the surface
semantics — just to the file organization.

## J3. Competing claims? No

The proposals don't compete. Multi-surface proposes "what kinds of
files exist." File-per-object proposes "how many declarations in each
file." You can pick both, neither, or one.

A project might adopt:
- Multi-surface + many-declarations-per-file (like multi-surface docs
  show) — less extreme, easier transition.
- Multi-surface + file-per-object — maximum discipline, best
  navigability.
- Single-surface + file-per-object — file discipline without concern
  discipline. Possible but loses the paradigm enforcement of
  multi-surface.

Recommendation: **multi-surface first, file-per-object as a later
tightening**. The multi-surface payoff is larger; file-per-object
refines within it.

## J4. What file-per-object adds on top of multi-surface

New wins (not captured by multi-surface alone):
- Filesystem = namespace (§A1)
- Per-object dependency graph (§A4)
- Per-object git history (§A5)
- Trivial find-by-name (§A6)
- Rename = `git mv` (§A3)
- Declaration body without name slot (§B8)
- Directory-as-impl-graph (§G5)

Costs not present in multi-surface alone:
- File count explosion (§H1)
- Navigation discipline requirement (§H2)
- Naming uniqueness pressure (§C4)

---

# §K. Verdict

## K1. Pros

1. **Architectural honesty**: filesystem structure matches program
   structure exactly. No hidden organization in file contents.
2. **Mechanical tooling**: rename, find, navigate become filesystem
   operations. Minimal language-specific tooling needed.
3. **Grammar simplification**: per-file grammars have one top-level
   alternative. Declarations shed their name slot (supplied by
   filename).
4. **Incremental compilation**: per-object rkyv cache granularity.
5. **Coherence as directory listing**: impls/Trait/Target/ subdirs
   make the impl graph literal (§G5).
6. **Version control wins**: per-object history; less merge surface.
7. **Ownership clarity**: CODEOWNERS entries target individual
   objects.
8. **Java/Smalltalk/Unreal precedent**: pattern proven at massive
   scale.

## K2. Cons

1. **File count explosion**: 500–2000+ files typical for mid-size
   projects. Tooling must handle, and convention must guide placement.
2. **Navigation requires discipline**: without an IDE and a strict
   layout, finding things can be slow.
3. **Learning curve**: "where does this file go?" becomes a daily
   question.
4. **Readability of related clusters**: a tight type family spread
   across many files may be harder to read than one file with context.
5. **Naming pressure**: global name uniqueness (or path
   qualification) becomes mandatory.
6. **Merge noise**: many small commits in large refactors.
7. **LSP/indexer complexity**: project-wide name index required from
   the start.

## K3. Open questions

1. **Delimiter question** (§B1): if the file IS the declaration, do
   opening delimiters stay? B-α (keep) vs B-β (drop) vs B-γ
   (optional).
2. **Sub-extensions for kind** (§B8): `.enum.types` vs just `.types`
   with first-token dispatch. Which wins?
3. **Impl filename scheme** (§B6): Scheme 1 vs 2 vs 3 vs 4. Scheme 3
   (Trait/Target/ImplName) leads analytically but needs user feedback.
4. **Import scheme** (§C2-δ vs others): project-wide name index vs
   per-file imports. Trade-off between verbosity and explicitness.
5. **Private helpers placement** (§D): `_private/` dir vs `_` prefix
   vs nested-in-parent. Pick one and enforce.
6. **Nested types** (§G3): stay inline in parent file vs promoted to
   subdirectory. Analysis favors "stay inline"; Li should confirm.
7. **Blanket impls placement** (§G6): `$Any` subdir vs `_blanket`
   subdir. Syntax question.
8. **Does surface-first or concept-first top-level organization win?**
   (§E4). Both viable; analysis favors surface-first.

## K4. Overall

File-per-object is a **legitimate extreme point** in the design
space. The precedent is solid (Java at scale). The wins are real
(mechanical tooling, filesystem-as-namespace, coherence as ls).

The costs are also real: file count, navigation discipline, learning
curve. These are the cost of "architectural honesty at the atomic
level."

For aski's philosophy — "types all the way down, trait-methods as
the only form of behavior, scopes are a tree, names are meaningful" —
file-per-object is **deeply consistent**. It takes every aski
principle and projects it into the filesystem:
- Scopes as tree → directory tree.
- Names meaningful → filenames are names.
- Delimiter-first → file extension as outer delimiter.
- No free functions → every file is a trait/impl/type declaration.
- Single commitment per unit → one declaration per file.

The philosophical alignment is strong. The practical cost is "many
files." Whether the practical cost is worth the philosophical gain
is a judgment call that requires actual codebase experiments.

---

# §L. Transition sketch

If this were ever adopted, the path from v0.20 to file-per-object
would layer ON TOP of the multi-surface transition plan (§10). Add
two optional waves after multi-surface lands:

## Wave FPO-1 — enforce one-public-declaration-per-file (soft)

- Tooling (linter) warns if a `.types` / `.traits` / `.impls` file
  has more than one top-level public declaration.
- Migration tool: `aski-split <file>` splits a multi-decl file into
  per-decl files named by declaration name.
- New projects start compliant. Old projects get warnings but no
  errors.

## Wave FPO-2 — filename = declaration name (hard)

- Grammar enforces: file `Shape.types` must contain an enum/struct/
  newtype/const named `Shape`. If not, error.
- Module header shortens: the name slot drops (filename supplies it).
- Grammar updates: decl forms accept elided name when parsing a file
  whose filename matches the intended name.

## Wave FPO-3 — impl directory structure

- Adopt `impls/Trait/Target/ImplName.impls` convention.
- veric's coherence query becomes a directory listing.
- Tooling: `aski-reorg-impls` moves existing flat impls into the new
  tree.

## Wave FPO-4 — filesystem-as-namespace (name index)

- Compiler builds a project-wide name index.
- Bare-name resolution via the index; path-prefix for disambiguation.
- Module headers become imports-only (no module name).

## Wave FPO-5 — eliminate outer delimiters (aspirational)

- `@[|...|]` on a single-trait file becomes `@...` (Option B-β).
- `@{...}` likewise. Filename + extension carry the delimiter semantics.
- Hardest break from today's grammar; most extreme form.

## Wave FPO-6 — lojix crate layout codifies FPO

- Package manager's crate layout requires FPO.
- Ecosystem pressure: crates that don't comply stand out.

## Reversibility

Every wave except FPO-5 is **locally reversible**. A project can stop
at any wave. FPO-5 breaks grammar compatibility and would need a
dedicated major version of aski.

## Effort estimate (rough, on top of multi-surface's 2–3 months)

- FPO-1 (soft enforcement + split tool): 2–3 weeks.
- FPO-2 (grammar enforces filename = name): 2 weeks grammar work.
- FPO-3 (impl dir structure + reorg tool): 1 week.
- FPO-4 (name index + bare resolution): 3–4 weeks compiler work.
- FPO-5 (outer-delimiter elision): 2 weeks grammar + migration.
- FPO-6 (lojix codification): part of lojix itself.

Total on top of multi-surface: ~2 months additional. Optional; each
wave shippable independently.

---

# The one-sentence closing

File-per-public-object is **the extreme projection of aski's design
principles into the filesystem**: if scopes are a tree, names are
meaningful, and every declaration commits to one thing, then every
declaration deserves its own file, named after itself, in a
directory-graph that mirrors the program's architectural graph —
and the cost of this commitment is paid in file count, repaid in
navigability, grammar simplicity, and version-control precision.

Whether the trade is worth making is a judgment Li gets to make, not
analysis can settle. This doc lays out the terrain. The decision
lives with the human.

---

*End of analysis.*
