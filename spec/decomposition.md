; Aski Decomposition — The Filesystem Is the Identifier Graph

*2026-04-21 · Foundational II-L (Identity-is-Location) research. This
document is the reasoning that led to v0.21 — see
[syntax-v021.md](syntax-v021.md) for the canonical current spec.*

---

# 0. Preface — why this document exists

An earlier multi-surface proposal (per-concern surfaces —
`.types` / `.traits` / `.impls` / `.effects` / `.derivations` /
`.test-impls` / platform-impl surfaces) listed eight surface
decisions, each defended on its own merits: paradigm
enforcement, coherence relaxation, effect tracking, named impls,
derivations, platform swapping, and so on. A later round of discussion
extended the proposal in directions the surface docs only hinted at:
one public object per file, the filename IS the object's name, a
per-kind extension tells you WHAT KIND the object is, the outer
source-level delimiter disappears because the file itself IS the
delimiter, private files carry an underscore prefix, directories are
modules, a dedicated `imports` file sits at the directory level, and
complex sub-structures split into sibling files via filename sigils.

Nine decisions. Eight surfaces plus all of the filesystem
conventions. Twelve if you count test-impls, bench-impls, platforms,
derivations, effects, async-impls, unsafe-impls individually.

Listing them is not the point. The previous pass enumerated them
and stopped there. This document looks for the **single principle**
from which every one of those decisions is a corollary. If the
principle exists, it replaces the enumeration. If it does not, the
decisions are merely convergent and we should stop calling them a
pattern.

The principle exists. It is sharp. It explains every decision. And
once stated, it explains why this specific language can commit to
it — aski's other axioms leave a space exactly this shape.

---

# 1. The principle

## 1.1 One sentence

> **A name is a place. A place is a path. A path is a filesystem
> path. Therefore the filesystem is the program's identifier graph,
> and source files hold only what has no name of its own — their
> bodies.**

Three clauses, each reducing the previous to the next.

- *A name is a place.* An identifier in a program is not a token
  repeated in many contexts; it is a location where exactly one
  thing lives.
- *A place is a path.* Locations in a program form a tree —
  modules contain types, types contain variants, variants contain
  fields. A location in a tree is a path.
- *A path is a filesystem path.* The filesystem is a
  universally-supported, tool-addressable tree. Every path is a
  first-class object for every tool the ecosystem knows.

Combined: a name is a filesystem path. The filesystem is where
identity lives. Source files are where bodies live, because bodies
are the only program content that has no name — a body is what a
name refers to.

## 1.2 The crisp form

A shorter restatement, for the slogan:

> **Identity is location. Location is path. A source file is what a
> path refers to — its body, and nothing else.**

Call this the **Identity-Is-Location principle**, or II-L for
shorthand.

## 1.3 Four framings that yield the same principle

### Information-theoretic framing

Every program construct carries several kinds of metadata:
- Its *name* (what to call it).
- Its *kind* (enum vs struct vs trait vs impl vs const).
- Its *visibility* (public vs private).
- Its *module* (where it lives in the namespace).
- Its *context* (what other names it depends on).
- Its *body* (what it actually computes or describes).

Shannon-wise, these are separable channels. Some are small and
uniform: kind is one of ten-ish values; visibility is one bit;
name is a string from a constrained alphabet. Body is unbounded.

A layout decision is a decision about where each channel lives.
Rust puts all channels into the source file, disambiguated by
keyword tokens and sigils (`pub`, `fn`, `enum`, `impl`, `mod`,
`use`). A layout that wastes the file on low-entropy metadata costs
the reader — their eyes parse boilerplate instead of semantics.

II-L says: **every channel whose values are drawn from a finite
tree-shaped name space lives in the filesystem; only the body lives
in the file.** Kind, name, visibility, module, and even imports
are small and tree-shaped. Body is unbounded and non-tree-shaped.
Therefore: everything but the body becomes part of the path.

### Ontological framing

What IS a program under II-L?

A program is a finite tree whose non-leaf nodes are **named
containers** and whose leaves are **bodies**. The tree is
literalized as the filesystem. Each non-leaf node is a directory.
Each leaf is a file. The body inside a file is the text you write.

There are no "modules you declare in source." There are no "traits
you open with a delimiter and close with another." A module EXISTS
because a directory exists. A trait EXISTS because a `.trait` file
exists at a path. The program's shape IS the filesystem's shape.

This inverts the usual model. In most languages, the filesystem
is a crude approximation of the program's real structure, which
lives in the source text. II-L reverses the primacy: the
filesystem IS the real structure, and source text is what fills in
the leaves.

### Operational framing

How is a program under II-L edited, navigated, and built?

- **To name a thing:** choose a path.
- **To rename a thing:** move or rename its file/directory.
- **To delete a thing:** `rm` its file/directory.
- **To change a thing's kind:** change its file extension.
- **To make a thing public:** remove the underscore prefix from its filename.
- **To import a thing:** add a line to the directory's `imports` file.
- **To add a new thing:** create a new file with the right path and extension.
- **To find a thing:** search the filesystem.

Every one of these operations is a filesystem operation. Every
filesystem-native tool — the shell, git, ripgrep, the editor,
the LSP, the agent — speaks this vocabulary natively. The language
inherits half its tooling from the OS.

### Categorical framing

Objects in the program category are **named paths** in the
filesystem. Morphisms are **dependency edges** — encoded in the
per-directory `imports` file, inherited down the tree. Coproducts
(enum-like choice between things) are **directories of siblings
with the same stem but different file extensions** (e.g., all the
impls of a given trait, or all the variants of a given enum, split
out). Products (struct-like composition) are **directories** (the
module as a product of its exports).

The functor from the program category to the filesystem category
is the identity. There's nothing to translate; the program IS the
filesystem.

## 1.4 Why the principle is irreducible

Strip out any one clause and something breaks:

- *"A name is a place"* — if a name is not a place, the same name
  can live in two places, and aski's rule "two different things
  have different names" (design.md §Names Are Meaningful)
  degenerates.
- *"A place is a path"* — if a place is not a tree-path, then
  place identity requires some other global registry, and we've
  reintroduced the very name-lookup problem filesystems solve.
- *"A path is a filesystem path"* — if paths are filesystem-like
  but not actually filesystem paths, we've re-invented the
  filesystem poorly and lost all tool support.

Each clause is doing structural work. The composition is the
smallest consistent model in which every other axiom on this page
falls out. That is the definition of a principle.

## 1.5 Deriving every settled decision from the principle

This is the key test. A pattern that explains some decisions but
not others is merely a correlation. II-L must explain every settled
decision, not as separate choices, but as corollaries.

### 1. Multi-surface architecture (`.types`, `.traits`, `.impls`, …)

> From II-L: every name has a kind; kind is part of the path; kind
> is encoded as the file extension.

A surface is the set of files sharing a kind-suffix. `.types` is
the surface of all type-declaration paths; `.traits` the surface of
all trait-declaration paths; `.impls` the surface of all
implementation paths. The surfaces are not "eight independent
design choices"; they are the enumeration of kinds in the program's
ontology. Every kind gets its suffix. Eight kinds, eight suffixes.

Corollary: adding a new kind to aski means adding a new file
extension. Removing a kind means removing an extension. The
surface count equals the kind count, by construction.

### 2. File-per-public-object

> From II-L: a name is a place; a place is a path; therefore a name
> is a file (or directory).

If each name maps to a unique path, and paths are filesystem
paths, then each name maps to a unique file. Multiple names per
file would mean multiple paths per file, which collapses the
bijection. Enforce it: one public top-level declaration per file.

The filename IS the name. There is nowhere else for the name to
be, because in-source name declaration would duplicate the
filesystem path.

### 3. Per-kind extensions

> From II-L: kind is a component of the path; file extensions are
> the natural place in the filesystem to encode a path-adjacent
> typed marker.

`.enum`, `.struct`, `.newtype`, `.trait`, `.impl`, `.const`,
`.effect`, `.derivation` — each is one kind. The extension is the
only place on a filesystem path where a typed marker conventionally
lives. Extensions are for kinds. This is already how the whole OS
is organized.

Note: `.types` (plural, from 01-surfaces) and `.enum` / `.struct` /
`.newtype` / `.const` (per-kind, from the later push) are two
different decompositions. The per-kind form is stricter: it
says "kind is EXACTLY the extension, no further internal
disambiguation." `.types` keeps four kinds inside one file kind,
which requires intra-file delimiter disambiguation. II-L prefers
per-kind because it pushes one more channel to the filesystem.

### 4. File = outer delimiter (unwrapping)

> From II-L: the file has an identity (its path). The body is what
> the identity refers to. The outer delimiter in source was the
> syntactic device that tied a name to a body; the file's path
> already ties the two.

In v0.20, a trait decl reads:

```aski
@[| Iterator
  Item
  (next ~&self {Option self:Item})
|]
```

The `@` is visibility. `[|` is the root delimiter that opens a
trait decl. `Iterator` is the name. The body follows. The closing
`|]` closes the decl.

Under II-L, the file lives at `Iterator.trait` in the directory
whose `imports` or ambient module context makes the dependencies
visible. The filename provides `Iterator`; the extension provides
`trait`; the directory provides the module; the `_` prefix (absent
here) provides public. The entire outer wrapper — `@[|` ... `|]` —
has moved to the path. The file contains:

```aski
Item
(next ~&self {Option self:Item})
```

Just the body. The file IS the delimiter.

This is not a cosmetic cleanup. It is the elimination of a
redundant channel. The outer delimiter in source was the
grammatical tie between "this is a trait decl" and "Iterator is
its name and here is its body." The tie now runs through the
filesystem. There are two wires carrying the same signal; II-L
removes one.

### 5. Private helpers via underscore prefix

> From II-L: visibility is part of the path; file-system-visible
> filenames default to public; prefix a filename with `_` to mark
> it private.

Unix filesystem convention already uses `.hidden` files for
"meta / don't-show-by-default." Programming conventions already
use `_helper` or `__private` inside source. II-L uses the existing
convention at the file level: `_Helper.struct` is a private
struct; `Helper.struct` is public.

The `@` sigil inside source — which v0.20 introduced for
visibility — becomes redundant, because the filename already says
it. The sigil disappears. (Modulo a nuance for struct fields; see
§4.)

### 6. Directory = module

> From II-L: modules are internal nodes of the name tree; internal
> nodes of the filesystem tree are directories.

A module is a named container of definitions. A directory is a
named container of files. One-to-one correspondence. The
directory's name IS the module's name. No `(ModuleName ...)` header
line anywhere, because the header line would duplicate the
directory name.

### 7. `imports` file per directory

> From II-L: imports are context; context is inherited down the
> tree; a per-directory file is the natural place to inherit.

Imports in Rust appear at the top of every file, duplicated across
dozens of sibling files in the same module. They are a
context-carrying channel whose values are shared across all files
in a directory. II-L factors this shared context into a single
file at the directory level. Sub-directories inherit the parent's
imports; they add only what they need beyond the parent.

This is not merely a convenience. It is the same principle applied
to imports: imports are a named channel; the channel's value is a
tree (per-directory inheritance); therefore the channel is a file
in the tree.

### 8. Recursive file split via filename sigil

> From II-L: sub-structures of a named thing are themselves
> addressable; their addresses are sub-paths.

Consider a struct with a large method on it. In v0.20, the method
body lives inside the impl body inside the file. Under II-L, if
the method is individually nameable — which it is, because it
has a name — then it is individually addressable. The filesystem
path for the method is a sub-path of its owner.

One possible encoding: dotted filename sigil.
`FastIter.next.method` — the `next` method body of `FastIter`.
Or: sub-directory. `FastIter/next.method`.

The choice between dotted names and sub-directories is a
filesystem-ergonomics question, not a principle question; II-L
says only that the sub-structure has a path.

Same for a variant payload: `Shape.Rectangle.struct` is the
Rectangle struct-variant payload of the Shape enum. The parent-
child relationship is encoded in the filename segments.

### 9. LLM-ergonomics as first-class argument

> From II-L: the program is the filesystem; agents that read
> filesystems read programs; the language's notation is native to
> those agents.

LLMs, IDEs, code-search tools, version-control systems, filesystem
watchers, and build systems all operate on files. A program whose
identifier graph IS a filesystem inherits all of their tooling
for free. This is not a side effect of II-L; it is the reason II-L
is operationally dominant right now.

A language that moves its structure out of plain-text grammar and
into the filesystem is a language that moves forward with the
tools, instead of against them.

## 1.6 The principle stands

Every settled decision in the multi-surface + file-per-object
program is a corollary of II-L. Nothing in the settled list is
independent of the principle; nothing in the settled list is
unsupported by the principle. The nine-decision enumeration
collapses to one clause.

This is what "find the pattern" meant: not a common theme, not a
shared intuition, but a literal principle from which everything
else deductively follows.

---

# 2. Precedent — what has been tried, where aski goes further

II-L is not novel at every level. Its components have been tried
by many languages and systems. What makes aski's version distinct
is the *completeness* of the commitment. Most precedents moved
one channel to the filesystem while leaving others in source. II-L
pushes every tree-shaped channel onto the filesystem.

## 2.1 Java — one public class per file

Java requires the file's name to match the name of its one public
class. This is II-L for the name-channel only, and only for one
kind (class). Inner classes, interface declarations, and default
imports all stay in-source. The file extension `.java` is kind-
agnostic.

What Java got right: filenames ARE identifiers; the filesystem
enforces uniqueness; tools learn from the filename.

What Java left on the table: other kinds (interface, enum, record,
annotation) share the `.java` extension; visibility is in-source
via `public`/`private` keywords; imports remain in every file;
package declarations are in-source even though they duplicate the
directory path.

Aski goes further: per-kind extensions push the kind-channel onto
the path; underscore-prefix pushes visibility onto the path;
per-directory `imports` file pushes the imports-context onto the
path.

## 2.2 Smalltalk — the class browser

Smalltalk treats classes as locations, not text files. The class
browser IS the primary editing interface; there are no ".st" files
you grep. Each class, each method, each category is its own
addressable node. Navigation and editing happen at the node level.

What Smalltalk got right: identity IS location. A method is a
node, not a line in a file. The IDE understands the object graph
natively because the object graph IS the editing medium.

What Smalltalk left on the table: the locations live in a
proprietary image, not the filesystem. Tool support is
Smalltalk-specific. Version control of Smalltalk code is
notoriously hard because git doesn't see into the image.

Aski goes further: the locations ARE the filesystem. Git, ripgrep,
and every shell tool see them natively. The "class browser" is the
filesystem tree.

## 2.3 OCaml — `.mli` / `.ml` pairing

OCaml separates interface (`.mli`) from implementation (`.ml`).
Signatures in the `.mli`; implementations in the `.ml`. Two
files, one module name, enforced at the filesystem level.

What OCaml got right: surface decomposition. The interface is a
different surface from the implementation. Each file contains
one contribution to the module.

What OCaml left on the table: only two surfaces. Types,
constructors, and values all share the `.mli` extension and all
share the `.ml` extension. Inner modules duplicate the structure
inside files. Visibility is by-signature, not by-filesystem-prefix.

Aski goes further: N surfaces per kind (`.trait`, `.impl`, `.enum`,
`.struct`, `.newtype`, `.const`, `.effect`, `.derivation`), not
two. Visibility is filesystem-prefix, not in-source annotation.
Module structure is directory structure, not nested-module
declarations.

## 2.4 Plan 9 — everything is a file

Plan 9 generalized the Unix "everything is a file" principle to
include network connections, window systems, and process controls.
Every resource got a filesystem path. Tool support compounded:
shell utilities operated on every resource through one uniform
interface.

What Plan 9 got right: the filesystem as a universal interface.

What Plan 9 left on the table: Plan 9 didn't go after source
code. Source code stayed plain-text C. The filesystem was the
system interface, not the program's own structure.

Aski goes further: the "everything is a file" principle applied
inside the program. Types are files. Traits are files. Impls
are files. Imports are files. The philosophy that underlay Plan 9
now underlies aski's own program structure.

## 2.5 Unison — content-addressed definitions

Unison abandons names entirely for the storage representation:
every function is stored by the hash of its body, and "names" are
labels attached at use-site, not intrinsic to the definition.
Two functions with different names but identical bodies are the
same object. Renaming costs nothing. Refactoring is structural.

What Unison got right: the insight that names are cheap, bodies
are expensive. Identity can be content-addressed.

What Unison left on the table: the tooling gap is vast. No
filesystem representation of Unison code looks like anything
humans grew up with. Editors, version control, search — all need
custom Unison support.

Aski's middle ground: names ARE identity (II-L says so), AND
names are filesystem paths (so the tooling is standard). Renaming
costs a `git mv`. Refactoring is a directory-level operation.

Aski does not adopt content-addressing. If two bodies are
identical but live at different paths, they are different objects.
The path is the name is the identity.

## 2.6 Hazel — structure editing

Hazel makes structure editing first-class: you cannot type a
syntactically invalid program because the editor only lets you
navigate and fill holes in a typed structural tree. "No syntax
errors possible" is the direction.

What Hazel got right: the program is a tree, not text. Editing
the tree directly removes an entire category of errors.

What Hazel left on the table: structure editing requires a
custom editor. The filesystem is secondary; the tree lives in the
editor's data model.

Aski's fit: II-L makes the *outer* tree (the name tree) editable
as a filesystem, while leaving the *inner* tree (the body) editable
as plain text. Hazel-style structure editing could sit on top of
the body; II-L already provides the outer structure.

This is a useful decomposition: structure editing is hard when
everything is structure. II-L limits what's structure (the path
tree) and what's text (the body). The hard parts of editing are
confined to bodies — which is what structure editors like Hazel
are designed for.

## 2.7 Lisp / Scheme — one syntactic form

Lisps collapse syntax to s-expressions. One form handles every
language construct; no disambiguation between "if" and "for" and
"function definition" because they're all the same shape.

What Lisp got right: syntactic parsimony is power. If everything
is one form, every tool that handles one form handles everything.

What Lisp left on the table: Lisp uses its parsimony to keep
structure in source. Filenames in Lisp projects are conventional,
not structural.

Aski's contrast: aski keeps its multi-delimiter structure in-source
(six delimiter pairs with position-defined meaning) AND uses II-L
to externalize the identifier graph. Lisp chose parsimony of form;
aski chose parsimony of *channel*.

## 2.8 Darklang — structure editor + database of code

Dark stores code in a database, not the filesystem. Edits are
operations on the database. Deployment is a database state change.
Version control is database-level.

What Dark got right: the storage medium for code shouldn't be
text files if the structure is richer than text. A database
preserves more structure.

What Dark left on the table: Dark's database is proprietary. Tool
support is Dark-specific. Migration away from Dark is expensive.

Aski's alternative: the filesystem IS a database, one that every
tool knows. Directories are tables. Files are rows. Extensions
are column values. Everything is queryable with find, grep, and
git.

## 2.9 Clojure — one namespace per file

Clojure convention is one namespace per file, with the filename
matching the namespace. Not enforced by the language, but by
culture. Imports (`:require`) are in-file.

What Clojure got right: the convention of one namespace per file.
It discovered the bijection without mandating it.

What Clojure left on the table: it's a convention, not a rule.
Nothing prevents a Clojure file from having two namespaces;
tools don't enforce one namespace per file. Imports remain
per-file.

Aski goes further: enforce the bijection; push imports to the
directory level.

## 2.10 Elm — one module per file, enforced

Elm enforces one module per file, and the module name matches the
file path. No multi-module files. Imports per file.

What Elm got right: strict bijection between files and modules,
at the language level, not just convention.

What Elm left on the table: only module-level bijection. Inside
a module, functions, types, and type aliases still share the file.
Visibility is in-source (`exposing`). Imports per file.

Aski goes further: bijection not only at the module level but at
the object level. Visibility on the filename. Imports per
directory.

## 2.11 Precedent synthesis

Each precedent moved one dimension of program structure onto the
filesystem or a structural medium. II-L moves every dimension
whose values form a finite tree.

| Precedent | Channel moved to filesystem | Dimension count moved |
|-----------|-----------------------------|----------------------|
| Java | Name (for classes) | 1 |
| OCaml | Surface (interface / impl) | 1 |
| Smalltalk | Everything, but in a proprietary image | many (non-filesystem) |
| Plan 9 | System resources (not code) | 0 for code |
| Unison | None — content-addressed | 0 (replaced) |
| Hazel | Body structure, in-editor | 1 (non-filesystem) |
| Lisp | None | 0 (syntactic parsimony instead) |
| Darklang | Everything, in a proprietary DB | many (non-filesystem) |
| Clojure | Namespace (by convention) | 1 |
| Elm | Module (enforced) | 1 |
| **Aski (II-L)** | **Name, kind, visibility, module, imports, sub-structure** | **6+** |

Aski is the first language (that I can identify) that pushes six
channels onto the standard filesystem, simultaneously, and
deliberately, and uses only standard filesystem operations to
manipulate them.

No predecessor has done this. This is why the pattern feels new
even though each individual piece isn't: the piece combinations
are novel.

---

# 3. Grammar delta — before/after under full decomposition

The grammar consequence of II-L is not cosmetic. Entire rule
families disappear. This section enumerates them.

## 3.1 Before — v0.20 root grammar

From `Root.synth` for the aski surface (v0.20), root constructs
are:

```
Module            (@ModuleName <Module>)
Enum              (@EnumName <Enum>) or @(@EnumName <Enum>)
Struct            {@StructName <Struct>} or @{@StructName <Struct>}
Newtype           (| @NewtypeName <Type> |) or @(| @NewtypeName <Type> |)
Const             {| @ConstName <Type> <Literal> |} or @{| … |}
TraitDecl         [| @TraitName <Trait> |] or @[| … |]
TraitImpl         [@TraitName <Target> [+<TraitImplItem>]] or @[@… <Type> …]
```

Six root constructs plus Module. Each has a unique opening
delimiter because first-token-decidability demands it. Visibility
`@` is a prefix sigil that can appear before any of them. Name
appears immediately after the opener. Body follows.

## 3.2 What the path encodes under II-L

Given a source file at path `foo/bar/Iterator.trait`:

- `foo` — outer module name
- `foo/bar` — inner module name (nested module)
- `Iterator` — the object's name
- `.trait` — the object's kind (TraitDecl)
- (no `_` prefix) — visibility public

That's five pieces of metadata, all from the path. No keywords,
no sigils, no in-source declaration.

If the file were `foo/bar/_Iterator.trait`, the only difference is
private visibility.

If the file were `foo/bar/Iterator.impl`, the kind changes to
TraitImpl.

## 3.3 After — II-L root grammar

For a `.trait` file, the entire file contents is `<TraitBody>`:

```
// Iterator.trait (file contents)
Item                                   ;; associated type (bare Pascal)
(next ~&self {Option self:Item})       ;; method signature
```

No opener. No closer. No name. No visibility sigil. The root
nonterminal of the `.trait` surface is:

```
Root.synth (.trait surface):
    #TraitBody#*<TraitItem>
```

That's it. The file itself is the trait body.

For a `.impl` file (single-impl convention):

```
// FastIter.impl  — filename provides ImplName=FastIter
// ambient imports provide Iterator, TokenStream
Iterator TokenStream                   ;; trait + target, one line each
(next ~&self {Option Token} [ ... ])   ;; method body
(Item Token)                           ;; associated type binding
```

Root nonterminal of `.impl` surface:

```
Root.synth (.impl surface):
    #ImplBody#<TraitName> <Target> *<TraitImplItem>
```

Still no opener, no closer. Name is the filename. ImplName
doesn't appear inside the file because it's the filename.

Note the position-positional-ness: the first two tokens of the
file are the trait name and target type. This is I-L-compatible
but carries a design choice: do `.impl` files encode
`(TraitName Target)` inside, or is *that* also in the path?

One option: `FastIter.impl` with trait/target on the first line.
Another option: `Iterator/TokenStream/FastIter.impl` — a
directory hierarchy encoding (Trait, Target, ImplName).
Pick one; II-L doesn't decide between them. The second is purer
(every nameable thing has its own path) but deeper.

Provisional pick for this analysis: flat
`impls/FastIter.impl` with `TraitName Target` as the first two
tokens inside the file. Balance of aesthetics and filesystem
navigability.

## 3.4 Root-grammar delta table

| Construct | v0.20 root form | II-L filename | II-L file contents |
|-----------|-----------------|---------------|--------------------|
| Module | `(Name [imports…])` first in file | directory | (no file) |
| Imports | `[Source Name Name …]` in module header | `imports` file in directory | one `[Source Name …]` per line |
| Public Enum | `@(Name …body…)` | `Name.enum` | `…body…` |
| Private Enum | `(Name …body…)` | `_Name.enum` | `…body…` |
| Public Struct | `@{Name …body…}` | `Name.struct` | `…body…` |
| Private Struct | `{Name …body…}` | `_Name.struct` | `…body…` |
| Public Newtype | `@(\| Name Wrapped \|)` | `Name.newtype` | `Wrapped` |
| Private Newtype | `(\| Name Wrapped \|)` | `_Name.newtype` | `Wrapped` |
| Public Const | `@{\| Name Type Literal \|}` | `Name.const` | `Type Literal` |
| Private Const | `{\| Name Type Literal \|}` | `_Name.const` | `Type Literal` |
| Public TraitDecl | `@[\| Name …items… \|]` | `Name.trait` | `…items…` |
| Private TraitDecl | `[\| Name …items… \|]` | `_Name.trait` | `…items…` |
| Public TraitImpl | `@[ImplName Trait Target […body…]]` | `ImplName.impl` | `Trait Target …body…` |
| Private TraitImpl | `[ImplName Trait Target […body…]]` | `_ImplName.impl` | `Trait Target …body…` |

Every root-level syntactic form loses its outer delimiter. Every
root-level form loses its name declaration. Every root-level form
loses its visibility sigil. Every root-level form loses its module
declaration.

**Root nonterminals vanish. File nonterminals remain.** The
grammar for a `.enum` file is no longer a rule that opens with
`(`; it is a rule that describes what lives inside an enum body.

## 3.5 Body nonterminals that survive

Inside a `.enum`, the file is a list of variants:

```
Root.synth (.enum surface):
    #EnumBody#*<Variant>
```

`<Variant>` is unchanged from v0.20's `<EnumVariant>` — the
internal construction of an enum variant doesn't change, because
those constructs (bare variant, data variant, struct variant,
nested enum, nested struct) live below the root. II-L only reaches
as deep as the root; inside each body, existing grammar carries
on.

Same for `.struct`:

```
Root.synth (.struct surface):
    #StructBody#{<GenericSlot>?} *<Field>
```

The outer `{` is gone — the file IS the struct. Inside, the generic
slot and fields are positional. The first item, if it's a
`{$Param …}` group, is the generic slot; everything after is
fields.

Wait: an edge case. For a struct with no generic slot, the first
item is a field. For a struct with a generic slot, the first item
is `{$Param}`. This is first-token-decidable (curly brace vs other)
so still honors design.md §No Complex Lookahead.

Same for `.trait`:

```
Root.synth (.trait surface):
    #TraitBody#{<GenericSlot>+<SuperTraitBound>}? *<TraitItem>
```

Generic slot + super-traits are the initial optional `{…}` block.
Trait items follow. First-token-decidable.

Same for `.impl`:

```
Root.synth (.impl surface):
    #ImplBody#{<GenericSlot>}? :TraitName <TargetType> *<TraitImplItem>
```

Optional generic slot, then trait name, then target type, then
body items. Note `:TraitName` for Pascal reference syntax; sigils
stay consistent with v0.20 grammar conventions.

## 3.6 What survives inside files

The full list of nonterminals that remain inside-file:
- `<EnumVariant>` — bare, data, struct, nested.
- `<Field>` — typed, self-typed.
- `<TraitItem>` — associated type, associated const, method sig.
- `<TraitImplItem>` — method body, associated-type binding,
  associated-const binding.
- `<Type>` — named, applied, borrowed, parameter, self-assoc.
- `<GenericSlot>` — `{$Param …}`.
- `<SuperTraitBound>` — bound references.
- `<Statement>` — local decl, expr-stmt, mutation, early-return.
- `<Expr>` — atoms, postfix, binary, match, loop, iteration.
- `<Pattern>` — wildcard, variant, variant-bind, or-pattern,
  string-literal, (future) int/float/bool literal.
- `<Body>` — a sequence of statements terminating in an expression.

**Every "in-body" nonterminal survives exactly as in v0.20.** Only
the root-level nonterminals die, because only root-level
nonterminals are about name/kind/visibility/module/imports — the
path-encoded channels.

This preserves v0.20's investment in expression, statement, body,
and type grammar. The 5 DSLs (core, aski, synth, exec, rfi) turn
into many surfaces, but the body-side grammar of the aski surface
transfers unchanged to each new per-kind surface.

---

# 4. What files contain — the irreducible body grammar

Once metadata moves to the filesystem, files contain only bodies.
What IS a body, precisely?

## 4.1 Taxonomy of body contents

Four body families:

1. **List-of-items bodies** — `.enum` (list of variants),
   `.struct` (list of fields), `.trait` (list of trait items),
   `.impl` (list of impl items), `.imports` (list of imports).
   Grammar: zero or more items of a specific kind.

2. **Singleton-expression bodies** — `.newtype` (one type ref),
   `.const` (one type + one literal). Grammar: a type expression
   and maybe a literal.

3. **Executable bodies** — `.exec` (a program body = a sequence
   of statements), `.method` if we split methods out (a method
   body = same). Grammar: sequence of statements, optional
   tail expression.

4. **Rule bodies** — `.derivation` (a rule: pattern + impl template),
   `.effect` (impl + effect annotations). Grammar: variant of
   `.impl` with a pattern in the target slot.

## 4.2 The body-grammar simplification claim

**Body grammar is significantly simpler than v0.20 root grammar
because bodies don't need to disambiguate between construct
kinds.**

Proof: v0.20's root grammar has ~8 alternatives competing for
first-token-decidability. Every new root-level construct forces a
new unique opening delimiter, and the delimiter budget is six. The
pressure on root grammar is intense: each new kind risks breaking
decidability.

Under II-L, every kind has its own surface with its own root
nonterminal. Inside a `.struct` file, there's no need to disambiguate
from `.enum` — you're already in `.struct`. Field parsing doesn't
need to avoid enum-variant-parsing. The grammar for `.struct`'s
root is a field list, full stop.

Concretely, `.enum`'s root grammar is `*<Variant>`. No openers,
no disambiguation, no visibility modifier (the file's filename
already carries it). The rule is two tokens long.

Contrast v0.20's root grammar: three rule alternatives with
visibility prefixes, each opening with a distinct delimiter. Each
alternative branches further on inner structure. The rule is a
multi-line disjunction.

## 4.3 Example — before and after for `.enum`

### Before (v0.20 root in aski surface)

```synth
Root.synth (aski v0.20):
    ?#Module#(@ModuleName <Module>)
    // *#Enum#_@(@EnumName <Enum>)        ;; public enum
    // *#Enum#(@EnumName <Enum>)           ;; private enum
    // *#Struct#_@{@StructName <Struct>}   ;; public struct
    // ... etc.
```

Module comes first (position 0). Then any number of enum / struct /
newtype / const / trait-decl / trait-impl. The prefix `_@` is the
public marker. The delimiter dispatches on kind.

### After (II-L per-kind surfaces)

`Enum.aski`, the `.enum` surface root:

```synth
Root.synth (.enum surface):
    #EnumBody#?<GenericSlot> *<Variant>
```

One rule. No alternatives at the root. Generic slot is optional.
Variants follow.

No module. No visibility. No kind. Nothing but the body.

`Struct.aski`, the `.struct` surface root:

```synth
Root.synth (.struct surface):
    #StructBody#?<GenericSlot> *<Field>
```

Same shape. Different body nonterminals.

`Trait.aski`, the `.trait` surface root:

```synth
Root.synth (.trait surface):
    #TraitBody#?<GenericAndSuperBounds> *<TraitItem>
```

`Impl.aski`, the `.impl` surface root:

```synth
Root.synth (.impl surface):
    #ImplBody#?<GenericSlot> :TraitName <TargetType> *<TraitImplItem>
```

Four surfaces, four one-rule root grammars. Compare to v0.20's
one surface with six-plus root alternatives.

## 4.4 Nested structures inside bodies

The body of a `.enum` file can still contain `(| Nested …|)` and
`{| Nested …|}` — the nested-enum and nested-struct inner forms.
II-L does *not* force every nested type to its own file. Nested
types can stay inline inside their parent's body, as today.

Why? Because "nested" in design.md §Scopes Are a Tree means a type
that is *scoped under* its parent, accessed as `Parent.Inner`. The
parent-child relationship is part of its identity. The path
`Shape.Rectangle` — whether it's a file at `Shape/Rectangle.struct`
or an inline `{| Rectangle … |}` inside `Shape.enum` — is the
same identity either way.

II-L says every nameable thing HAS a path. It does not say every
nameable thing lives at a file-granularity path. A nested type can
live inside its parent file; its address is still
`Shape.Rectangle`, just resolved inside the file rather than at
the filesystem level.

When does the split from inline to file-level make sense?

- **When the nested type is itself complex** — dozens of variants
  or a large body — splitting gives it its own file for editing
  ergonomics.
- **When the nested type is referenced from outside the parent
  file** — giving it a path that tools can navigate directly.
- **When the nested type has its own impls** — the impl file's
  Target needs a path to reference, and `Shape/Rectangle.struct`
  is cleaner than "the Rectangle nested struct defined inside
  Shape.enum at line 42."

So inline and file-level forms are both legal. II-L gives the
option; authors pick per-type.

## 4.5 Method body split

A method body inside an `.impl` can be large. Should it split to
its own file?

Proposal: `FastIter/next.method`. Directory `FastIter` carries the
impl's full identity (with the `.impl` file inside specifying trait
+ target + other items), and the `next.method` file carries only
that one method's body.

Grammar of `.method` file:

```
Root.synth (.method surface):
    #MethodBody#<Signature> <Body>
```

Signature (params + return type) on one logical line, body
expression/statement list after. The method's name comes from the
filename.

The `.impl` file at `FastIter.impl` (or `FastIter/impl` if we
treat it as a directory) then lists items by reference:

```
// FastIter.impl (or FastIter/impl at directory root)
Iterator TokenStream                      ;; trait + target
next                                       ;; method name; body lives at FastIter/next.method
(Item Token)                               ;; associated type binding
```

The name `next` at body position is a reference to `./next.method`.
The engine resolves the reference through the filesystem.

Whether methods routinely split out of impls or only when large is
a judgment call; II-L gives the mechanism.

## 4.6 Summary of body grammar

II-L's net effect on body grammar:
- Root nonterminals shrink to one rule per surface.
- Body-side nonterminals (variant, field, item, statement, expr,
  pattern, type) survive unchanged from v0.20.
- Nested-type forms remain as options alongside file-split forms.
- Methods remain inline in impl bodies or split to their own
  files, author's choice.

The irreducible body: what cannot be named because IT IS the
referent of the name. Everything else goes to the path.

---

# 5. LLM-native programming — first-class argument

This section builds out the LLM-ergonomics case to its full weight.
Li's instruction frames aski as a language for the next 50 years.
Computing for the next 50 years is filesystem-native, agent-
augmented, and AI-authored in significant part. A language whose
*structure* is its *filesystem* compounds that advantage.

## 5.1 One file = one unit of change

Every refactor, every patch, every code-review atom operates on a
unit of change. In mainstream languages the unit varies: sometimes
a function inside a file; sometimes a whole file; sometimes a module
across multiple files.

Under II-L, the unit is deterministic: one file per named object.
- A targeted refactor is a patch to one file.
- A rename is a `git mv`.
- A kind change is a file-extension rename.
- A visibility change is an underscore-prefix addition or removal.
- A module change is a directory rename.

All of these are operations every file-aware tool already knows
how to do. Diff, merge, blame, log, bisect, revert — each works
on files. An LLM-generated refactor patch targets one file and
needs no other context beyond the directory's `imports` file.

## 5.2 Context window fit

Modern LLMs have 200k–1M-token context windows. Most useful work
happens when you can fit the relevant code AND the task into the
window.

Under II-L, a typical file is small. A single trait declaration is
10-30 lines. A single struct is 5-40 lines. A single impl is
50-300 lines. A method-split file is 10-100 lines.

Compare to a Rust module that bundles N types + M traits + K impls
in one 2000-line file: the LLM either ingests irrelevant code or
fragments its view.

II-L files are pre-partitioned for context windowing. An agent
asked to modify `FastIter.impl` reads exactly `FastIter.impl` plus
the directory's `imports` file plus any referenced type files. The
surface of what-it-sees matches the surface of what-it-changes.

## 5.3 Find-and-replace via filesystem

Cross-cutting refactors are a classic pain point. "Rename trait
`Iter` to `Iterator`" under a source-text model requires AST-aware
rewriting tools because the name appears in many contexts.

Under II-L:
- `git mv Iter.trait Iterator.trait` — renames the declaration.
- `git mv Iter/* Iterator/` — renames any method-split subtree.
- ripgrep `Iter` in `*.impl` files — finds references.
- `sed -i s/Iter/Iterator/g` on matched files — rewrites references.

The name tree IS the filesystem. Name manipulation IS filesystem
manipulation. This is not a hack; it is the architectural
guarantee.

## 5.4 Agent parallelism

With one public object per file, multiple agents can work on
multiple files in parallel without collision. Each agent takes a
file; each file has one author at a time; merges rarely conflict
because changes localize.

This is exactly the pattern git was designed for. A language whose
atomic unit of change IS a git-trackable file scales to
many-agents-at-once workflows that merge cleanly.

Compare: a monolithic source file with fifty public items. Fifty
agents, one file, constant merge conflicts. No amount of fancy
merging tooling overcomes the fact that the source IS not
partitioned into independent units.

II-L partitions the source along the SAME lines agents naturally
partition work: by object.

## 5.5 Error localization

A syntax error in a v0.20 file under the combined surface affects
the whole file — the parser can't skip past the broken construct
to reach subsequent constructs reliably. Error recovery in
combined grammars is hard.

Under II-L, a syntax error in `FastIter.impl` affects only
`FastIter`'s impl. Every other file in the module parses
independently. Build-time feedback localizes.

An agent that breaks a file fails fast on that file alone. The
rest of the project keeps working. Test suites keep running. The
break is localized to its object.

## 5.6 Code review per object

Pull-request hygiene: smaller PRs, each doing one thing. Under
combined-file layouts, "one thing" is hard to separate from "one
file"; a PR that touches one concept often touches many files, or
one large file in many places.

Under II-L, "one thing" IS one file (or a small set of related
files — e.g., a new trait + its first impl is two files). A PR
per object is the natural granularity. Reviewers see exactly the
change.

## 5.7 Version history per object

`git log FastIter.impl` gives the complete history of the
FastIter impl. Not "every change to the file FastIter lived in."
The object's history IS its file's history, because the file IS
the object.

Compare to Rust: `git log` on a 2000-line file gives the history
of everything that ever touched that file, regardless of whether
the change was to FastIter or SomethingElse. To get the history of
a single impl inside a combined file, you need git-blame + AST
tooling + heuristics. Not trivial.

Object-granular history is a property of II-L, not a feature you
build.

## 5.8 AI-authored code matches file-per-object output modality

Generative models output tokens sequentially. When an agent
produces code, it produces one object at a time, coherently.
Multi-object output at once is where AI codegen gets flakiest —
the coherence across objects is hard to maintain.

File-per-object matches the AI's natural output modality. Produce
one file; produce another; produce a third. Each file is a
self-contained generation. The file boundary IS the generation
boundary.

This is one of those "the tool fits the hand" observations. Aski
files under II-L are exactly what agents write naturally. The
friction that exists today — agents producing code fragments that
have to be inserted into larger files — disappears.

## 5.9 Tool support is already here

Editors (vim, emacs, vscode, nvim, zed), IDEs (IntelliJ, Xcode),
language servers (rust-analyzer, clangd, pyright), code search
(ripgrep, ag, grep), version control (git, hg, pijul), linters,
formatters, build systems (cargo, bazel, nix) — all operate on
files natively. Every tool. Every ecosystem. No exceptions.

A language that operates on files natively inherits every tool.
II-L inherits: one public object per file means every tool
targets one object. Every tool becomes aski-aware without any
aski-specific work.

A language that operates on something else — image, database,
custom structure — has to bring its own tooling. Dark brought its
own; Unison brought its own; Smalltalk brought its own. Tools
haven't crossed over. aski takes the opposite bet: use what
exists; compound the advantage.

## 5.10 The compound effect over 50 years

Fifty-year-horizon thinking: tooling has a scale-free power-law
distribution. Filesystem-native tools compound every year. The
filesystem will be here in 50 years; so will grep; so will git-or-
its-successor. Every year, the filesystem accrues more tooling,
more agents, more automation.

A language that encodes structure in the filesystem starts at
year zero with all of that tooling working. Fifty years later,
the advantage has compounded enormously.

A language that hides structure from the filesystem (most
languages today) needs custom tooling to recover what the
filesystem already gives you. That custom tooling has to be
maintained year-over-year. As the ecosystem changes, the
tooling has to change.

II-L positions aski to ride the filesystem's gravitational well.
As long as filesystems exist, aski's structural tooling doesn't
need maintenance. Everyone else's does.

## 5.11 "Aski is AI-native by architecture"

The strongest form of this argument:
- LLMs read files.
- LLMs write files.
- LLMs rename files.
- LLMs delete files.
- LLMs organize files into directories.

An LLM producing an aski program under II-L produces files in
directories. That IS an aski program. There's no transformation
from "LLM output" to "program source"; they are the same thing.

Contrast: Rust or Python or TypeScript, where LLM output is text
that gets inserted INTO files that contain other things, where
the LLM has to consider coherence across insertion points, and
where the file boundary is orthogonal to the concept boundary.

II-L says: the file boundary IS the concept boundary. An LLM
producing a concept produces a file. Done.

## 5.12 The aesthetic alignment

There's an aesthetic thread here too. Aski already commits to
"names are meaningful" — no single letters, every name describes
what it is. II-L takes this one step further: not only is every
name meaningful, but every name is a first-class, addressable,
path-routed, tool-accessible entity.

A language that insists its names mean something should also
insist its names be findable, movable, and versionable as things
in their own right. II-L is the operational extension of §Names
Are Meaningful.

---

# 6. Edge cases — pressure-testing the principle

Every principle meets resistance. This section takes II-L to the
hardest cases and finds where it flexes, where it breaks, and
what refinements keep the core clean.

## 6.1 Mutually recursive types

A classic test: `Tree`/`Branch`/`Leaf` where `Branch` holds
`{Box Tree}`.

```aski
// Tree.enum
(Leaf {| (Value U32) |})
(Branch {Box Tree})
```

II-L handling: `Tree` is one file. Its variants live inside.
Mutual recursion within a type is not a problem for II-L; the type
IS one thing and its variants are parts of that thing.

If `Leaf` and `Branch` were themselves non-trivial and grew their
own impls, they could be split to their own files:
`Tree/Leaf.struct`, `Tree/Branch.struct`. The inline form in
`Tree.enum` then becomes a reference:

```aski
// Tree.enum
Leaf                                   ;; reference to Tree/Leaf.struct
Branch                                 ;; reference to Tree/Branch.struct
```

Does II-L survive? Yes. The mutual recursion is internal to the
tree of `Tree`'s sub-parts; all parts share the `Tree` directory
path.

## 6.2 Generic types with phantom parameters

`Handle<T>` — typed handle that doesn't actually use `T` in its
fields.

```aski
// Handle.newtype (actually a phantom-carrying struct, generic)
{$Value}
HandleId U32
```

File says: this is generic in `$Value`; body says it holds a
`HandleId`. The `$Value` is phantom — no field uses it — but the
file's generic slot declares it.

II-L survives: generic params are part of the body, not the
metadata. The slot `{$Param}` lives in the body. No reason for it
to live on the path (parameters are unbounded; the filename
shouldn't grow).

## 6.3 Type families / associated type dependencies

Consider a trait `Iterable` with associated type `Item`. An impl
of `Iterable for Collection` binds `Item = Thing`. Another impl
of some `Process for Thing` depends on `Thing` existing.

```
mod/
  imports
  Iterable.trait                       ;; Item associated type
  Thing.struct                         ;; the bound type
  Iterable-for-Collection.impl         ;; binds Item=Thing
  Process-for-Thing.impl                ;; uses Thing
```

II-L handling: associated types in trait decls live in the trait
file's body. Bindings in impls live in the impl file's body. The
types referenced (like `Thing`) are separate files. The dependency
graph between files is resolved at veric link time through the
standard import mechanism.

Does II-L survive? Yes. Associated types are not separate nameable
things outside their declaring trait; they're trait items. They
stay inside the trait file. No path pollution.

## 6.4 Cross-module coherence

veric verifies coherence: exactly one impl of each (Trait, Target)
pair is active in each scope. Under II-L, impls are files scattered
across the project. How does veric find them?

Option A: veric walks the full filesystem tree, reading every
`.impl` file, building the global (Trait, Target) → Set<ImplName>
index. This is the straightforward implementation. Filesystem walks
are fast; a medium project has thousands of files; modern
filesystems index them effortlessly.

Option B: veric relies on an incremental build cache that tracks
which files contribute impls for which pairs. Invalidate a file,
invalidate its index entries, re-parse just that file.

Option A is fine for correctness. Option B is the production
optimization. II-L doesn't prescribe which; it makes both possible.

**Scalability:** 10,000-file projects are routine in Rust or Java.
Modern filesystems + indexers (fsevents on macOS, inotify on
Linux) handle them. veric's coherence check is O(N) in files plus
O(M) in impl-pair instances, both small.

## 6.5 Impl overloads — multiple impls per (Trait, Target)

The core named-impl model (§3 in 00-vision): multiple impls of the
same (Trait, Target) coexist.

Under II-L, each impl is a file. The filename IS the impl name.
Two files can both declare an impl of `Iterator for TokenStream`
— they're `FastIter.impl` and `SafeIter.impl`, both at the same
directory level. No conflict.

Activation at a call site selects which impl is used. That's
scope-based (see 04-impls.md), not file-based. The file just
DECLARES the impl exists with a name.

II-L fit: perfect. Impl names are paths. No impl conflicts because
no path collides.

Question raised: "where does the coherence query run?" Answer:
veric walks `*.impl` in the program; finds all impls for a given
(Trait, Target); checks that each active scope has exactly one
activated.

## 6.6 Nested types with their own impls

Suppose `Shape.Rectangle` (the Rectangle variant of Shape, as a
struct) has its own impls. Where do they live?

```
mod/
  imports
  Shape.enum                           ;; defines Rectangle inline
  Area-for-Rectangle.impl               ;; impl references Rectangle
```

Inside `Area-for-Rectangle.impl`, the target is `Shape.Rectangle`
(a compound path). The path-resolution engine walks: find `Shape`
(it's `Shape.enum` in this directory), then find the `Rectangle`
item inside it (it's a struct variant in the body).

If `Rectangle` grows, extract it to its own file:
`Shape/Rectangle.struct`. Now `Area-for-Rectangle.impl` references
`Shape/Rectangle` via the same `:`-path notation.

II-L handling: the target's path in the impl body is a dotted or
colon-separated name. The resolution machinery reads that name,
walks the filesystem, finds the file. No path ambiguity.

Does II-L survive? Yes. The path notation inside source files
(already present in v0.20 as `Type:method`, `Type::Variant`)
generalizes to filesystem paths seamlessly.

## 6.7 Derivation application

A derivation rule matches many types. `DebugStruct` matches every
struct. When the derivation fires, does it emit synthetic impl
files on disk?

Option A: Yes. Derivations generate real `.impl` files in a build-
output directory. Those files participate in coherence just like
hand-written impls. The `imports` of the target's directory can
reference derived-impls-only directories.

Option B: No, in-memory only. veric materializes derivations as
in-memory impl records, checks coherence against both hand-written
and in-memory impls, emits no files.

Option A is filesystem-native and fits II-L's spirit. Option B is
faster and more traditional.

Mixed option: generate files in `.build/derivations/` that humans
can inspect but the build system manages. Humans don't hand-edit
them; they're derivation outputs. But they're on the filesystem,
so every tool sees them, and coherence works uniformly.

Provisional pick: Option C (mixed), because it preserves II-L's
property that everything is filesystem-visible while being
practical about build artifacts.

## 6.8 Incremental compilation

File granularity is a perfect incremental-build primitive. Change
a file → recompile just that file's output.

Two wrinkles:
- **Imports file invalidation:** if `imports` in a directory
  changes, every file in that directory (and transitively, every
  sub-directory) needs to rebuild its name resolution.
- **Public API changes:** if a public struct changes, every impl
  file that uses it needs rebuilding.

Wrinkle 1: imports-file changes ripple downward. Mitigation:
imports-file invalidation re-runs name resolution only (cheap);
type-checking re-runs only if a used name's type changed
(rarer). In practice, adding a new import doesn't invalidate
anything (new imports don't break existing references); only
removal or renaming invalidates.

Wrinkle 2: this is standard. Any language with separate
compilation handles this. It's the whole point of interface files
in OCaml. The II-L equivalent: the `.struct`'s shape is its
interface. Any impl referencing it has a dependency; any shape
change invalidates the impl.

Both wrinkles are tractable with standard incremental-build
techniques. II-L doesn't introduce a new problem; it slots into
the existing solution.

## 6.9 Tooling load — 10k files

Medium project: 10k files. Filesystem overhead?

- Directory reads: inode caches serve these in constant time after
  the first read. Modern OSes handle 10k directory entries
  trivially.
- Filesystem walks: ripgrep handles 100k-file repos in <1s.
- Git tracking: git's internals scale to kernel-repo-sized projects
  (~80k files). 10k is comfortable.

The only concern is pathologically deep directory trees. If
project hierarchy is ten levels deep, path strings grow long.
Mitigation: no deeply-nested default conventions; projects stay
broad-and-shallow.

II-L's filesystem scale is orders of magnitude below filesystem
scale limits. Not a problem.

## 6.10 Version control

Per-object git log is a feature. Per-object rename tracking is
weaker — git tracks file-level renames, but chains of renames
(FastIter → QuickIter → FastIter) can confuse history tools.

Mitigation: aski's rename operations become single git mv commands,
and git's rename detection is fine for single renames. Long chains
are rare. Where they matter, git log --follow handles them.

Alternative: tooling on top of git to track object identity across
renames explicitly. But that's optional; baseline git is usually
enough.

II-L survives: the price paid is the small rename-history weakness
in git, mitigated by standard git practice. No architectural
problem.

## 6.11 Package / crate boundaries

Directory = module works within a project. What about cross-project
boundaries — published libraries?

Option A: a package IS a top-level directory, versioned and
published. Importing a package means importing its directory tree.

Option B: packages are a separate concept (a manifest file), and
the language's directory structure lives inside a package's
src/ directory.

Rust uses Option B (Cargo.toml + src/). Most languages do.

II-L is neutral here. The package-boundary concept lives at a
level above II-L. II-L describes the language-internal structure;
packages are the distribution unit above that.

A library's public surface IS the set of files where the filename
doesn't start with `_`. That's the API contract. Consumers import
public names from the library; private names (underscore prefix)
are inaccessible.

No conflict with II-L. The package system layers on top.

## 6.12 Pathological files — file count vs. project size

Concern: does file-per-object produce absurd file counts?

A small project (10 types, 5 traits, 20 impls, a few consts) is
~40 files. That's 40 items total. A large project (1000 types,
100 traits, 5000 impls) is 6000 files. Rust standard library-sized.

Rust's standard library is 500k+ lines of source across thousands
of .rs files. II-L's aski stdlib at equivalent scope would be
thousands of files too — same order of magnitude. The file:line
ratio is similar.

What's different: under II-L, tools open one file per object,
which is better than opening one file per module under Rust. File
counts go UP; file sizes go DOWN. Net: roughly neutral total
weight; better cache-window, better find-what-you-want.

## 6.13 The directory-explosion worry

If every named thing is a directory (its own file plus optionally
sub-files for method splits), projects can get directory-heavy.

Mitigation: directories are optional. A trait without split methods
is one file. Only when a trait's methods split out does the trait
become a directory with a `.trait` file and method-files inside.
Most traits stay single-file.

Same for impls. Most impls stay single-file; only huge impls
split.

II-L gives the option; doesn't force every object to be a
directory. Directory explosion is a project-author choice, not an
architectural consequence.

## 6.14 Conflicts with the filename alphabet

File systems have filename restrictions: no slashes inside names,
no colons on some systems, length limits, case-insensitivity on
macOS default filesystems, etc.

Concern: aski names use Pascal and colons (`:`). Can
`Char:Upper:A` be a filename?

Good question. `Char:Upper:A` as a filename would depend on the
filesystem. macOS is case-insensitive by default, which is okay
here (the name isn't case-colliding). Colons aren't valid on
Windows.

Mitigation: II-L says a path is a filesystem path; we choose a
concrete encoding that fits cross-platform filesystems. Pascal
stays; colons become slashes: `Char/Upper/A`. Nested enums become
directories.

This works and is consistent: the nested-enum path `Char:Upper:A`
in source IS the directory path `Char/Upper/A` on disk. The
source notation is a view of the filesystem; navigation in source
corresponds to navigation in the filesystem.

## 6.15 The mutable world — hot reload, live updates

Smalltalk's class browser supported live updates: change a method,
running code sees the change immediately. Is II-L compatible with
hot reload?

Yes. A filesystem watcher sees file-level changes. Each changed
file triggers recompilation of its affected outputs. For a dev-
server-style hot reload, file-granularity is ideal: swap the
updated method's bytecode, keep everything else live.

II-L's file-per-object unit is exactly the reload unit Smalltalk
needed. Plus the filesystem is durable: you can close the dev
server and the code's still on disk.

## 6.16 Summary — edge cases handled

Every edge case either flexes cleanly (mutual recursion,
associated types, nested types) or integrates with existing
infrastructure (version control, packaging, incremental build,
tool scale). No case breaks the principle; a few case require
implementation choices (derivation output, method split
granularity) that II-L leaves open and lets authors decide.

---

# 7. Anti-patterns — what the grammar must reject

If the filesystem IS the identifier graph, certain operations
would break the graph. The grammar and build system must reject
them.

## 7.1 Multiple public top-level objects per file

**Rejection mechanism:** the `.enum` / `.struct` / `.trait` /
`.impl` surface root has exactly one body. Two declarations in
the file would be a parse error.

Under II-L's root grammar (per §3.3), the root nonterminal for
`.enum` is `#EnumBody#?<GenericSlot> *<Variant>` — one body, one
variant list. There's no way to have two enum-level declarations
because the root grammar doesn't branch.

## 7.2 Filename-name mismatch

**Rejection mechanism:** the file's filename IS the object's name.
There's no in-source name to mismatch against.

There's a subtler version: what if the content in the file
references itself as `Foo`, but the filename is `Bar.enum`? The
answer: the file doesn't *contain* a self-reference by name,
because there's no top-level name declaration in the file. The
filename is the only place the name exists.

Inside-body self-references (`self`, `Self`) are fine; they're
positional, not name-based.

## 7.3 Extension-kind mismatch

**Rejection mechanism:** the file's extension dispatches to a
surface; the surface's root grammar describes exactly that kind.
A `.struct` file with enum-variant content would fail to parse.

If a `.struct` file body contained `(Fire Earth Air Water)` (the
form of bare enum variants), the `.struct` grammar would reject
it because variants aren't fields.

Kind is encoded in the extension; content must match.

## 7.4 Circular import dependencies within a directory

**Rejection mechanism:** the `imports` file is declarative, not
imperative. Circularity manifests as "module A imports module B
imports module A," which the link-time resolver sees and rejects.

Within a single directory, there's no imports question — all files
in a directory share the ambient context. Between directories,
the parent-child inheritance is strictly downward, never sideways.
No circularity possible.

## 7.5 Any construct requiring out-of-band metadata

**Rejection mechanism:** II-L says everything that isn't a body
lives in the path. If a proposed construct required metadata NOT
expressible in the path (e.g., a priority annotation, a feature
flag gate), the language refuses it.

If someone wanted `@[priority=100] FastIter Iterator TokenStream`
— priority as a first-class attribute — the answer is: either the
priority is part of the name (`FastIter-100.impl`? no, ugly), or
it's part of a file in the directory that annotates priorities,
OR the construct isn't needed (scope activation does the selection
work). No out-of-band metadata.

This is a sharp test for new proposals: if the proposal requires
information that doesn't fit the path and doesn't fit the body,
II-L refuses it. The proposer refines until it fits.

## 7.6 Inline modules

**Rejection mechanism:** modules are directories. In-source module
declarations (`mod foo { … }` in Rust) would create a module
whose path is inside a file, violating "directory = module." The
grammar has no form for inline modules.

Rust has inline modules partly for convenience, partly for visibility
scoping. II-L handles visibility scoping via the underscore prefix;
inline modules are unnecessary.

## 7.7 Hidden re-exports

**Rejection mechanism:** imports are declared in the `imports`
file. There's no in-source `pub use` form that re-exports a name
from one module through another. Names live where their files
live; aliases are either filesystem symlinks (discouraged) or
don't exist.

Aski accepts that re-export chains in Rust are often a sign that
the code lives in the wrong place. II-L forces the question:
where does this name really belong? Put it there.

## 7.8 Anonymous items

**Rejection mechanism:** every file has a name (its filename).
Every object has a name (its file). There are no anonymous traits,
anonymous impls, anonymous types.

Rust's `impl Trait` as return type is a form of anonymous type.
Aski's version (if any) would have to be named or re-framed. The
existential bound would live as a named trait in the codebase;
`impl Trait` collapses to a path reference.

Closures? Same issue. Aski's direction (paradigm.md §S4, open
question) is toward named types for callable behavior. II-L
reinforces that direction: if a closure has behavior, that
behavior is a named impl on a named type with a named file.

## 7.9 Same name in two kinds

Can `Foo.enum` and `Foo.struct` coexist? They're in the same
directory, both named `Foo`, but different kinds.

**Answer: no.** The name `Foo` is a path. The path is the
filesystem name. If `Foo.enum` and `Foo.struct` coexist, both
claim the name `Foo`, and the path is ambiguous.

The filesystem resolves this by treating them as separate files
(different extensions), but II-L treats the name-not-including-
extension as the object's identity. Two objects named `Foo`
collide.

Enforcement: veric refuses duplicate names within a directory,
regardless of extension.

## 7.10 Symlinks, hardlinks, and other filesystem trickery

**Rejection mechanism:** file-walking tools have to decide whether
to follow symlinks. veric's walk should NOT follow symlinks by
default, to keep the program's identifier graph well-defined.
Hardlinks are invisible at the filesystem API level (they look
like separate files), so they're fine.

If a symlink were followed, the same file could appear under two
paths, producing duplicate identity. Not acceptable.

## 7.11 Summary — anti-pattern enforcement

| Anti-pattern | Enforcement |
|--------------|-------------|
| Multiple public objects per file | Surface root grammar, one body per file |
| Filename ≠ object name | No in-source name; filename IS name |
| Extension ≠ kind | Surface grammar rejects mismatched content |
| Circular imports | `imports` file resolver rejects cycles |
| Out-of-band metadata | No construct without path-or-body encoding |
| Inline modules | No inline-module grammar |
| Hidden re-exports | No re-export form; name lives where file lives |
| Anonymous items | Every object has a filename |
| Name collision across kinds | veric refuses same-stem duplicates |
| Symlink-following duplicates | veric doesn't follow symlinks |

Every anti-pattern has a single-line enforcement. The system is
tight.

---

# 8. Bootstrap analysis — what `.core` already teaches

Aski has been running a narrow version of II-L at the bootstrap
level for the entire v0.18 → v0.20 evolution. The `.core` surface
is types-only; corec consumes `.core` and emits rkyv-deriving
Rust; askic / veric / semac / domainc all consume the rkyv that
corec produces.

What does the bootstrap teach us about II-L?

## 8.1 Lesson 1 — A narrow surface is a maintainable surface

corec is small. The `.core` grammar is ~5 alternatives at the
root. Refactoring corec is tractable. Adding new `.core` features
is local. Testing corec is tractable.

**Why it works: the surface is narrow.** `.core` doesn't try to
handle methods, impls, effects, derivations. It does types. Narrow
surface ≡ narrow grammar ≡ narrow code.

II-L generalizes: every surface is narrow. Each surface has its
own grammar, its own root nonterminal, its own body type. Each is
small. Each is maintainable.

If `.core` could be a one-purpose surface for the bootstrap, every
other kind can be a one-purpose surface for the user code. The
generalization is direct.

## 8.2 Lesson 2 — A narrow surface composes cleanly

corec feeds askic; askic feeds veric; veric feeds semac; semac
feeds domainc and rsc. Each stage consumes one surface and
produces another (or consumes multiple and produces one). The
pipeline works.

Why: the surfaces are independent. The interface between two
stages is an rkyv contract over a narrow surface's types. Stages
don't share state beyond the rkyv handoff.

**II-L reading: surfaces are not just organizational boundaries;
they are compositional primitives.** A surface is an interface.
Multiple surfaces compose because each has a well-defined contract
(its rkyv types, its root grammar).

Adding a new surface doesn't perturb existing surfaces. This is
crucial for II-L's stability: as new kinds arise (`.async-impls`,
`.unsafe-impls`, `.capability-impls`), they layer onto existing
surfaces without breaking them.

## 8.3 Lesson 3 — File-level granularity is already the norm

The `.core` files are small, each holding one concern:
`domain.core` for domains, `trait.core` for traits, `expr.core`
for expressions. It's not *one type per file*; it's one *concern*
per file. Already more structured than Rust's typical module file.

II-L takes the existing file-per-concern tendency and sharpens
it to file-per-*object*. The direction is the same; the sharpness
is different.

`domain.core` today holds multiple related types (Domain, Enum,
Struct, Newtype, plus variants). Under full II-L, these split:
`Domain.enum`, `Enum.struct`, `Struct.struct`, `Newtype.struct`,
with nested variant/field types inline. Five files instead of
one.

Trade-off: more files, smaller files. Per §5, this is exactly
what LLM-era tooling prefers.

Is the bootstrap behind on II-L? Slightly. But the bootstrap's
`.core` granularity is already decidedly finer than Rust's
module-per-file convention. The full II-L jump is a refinement,
not a revolution.

## 8.4 Lesson 4 — The pipeline is a surface-passing chain

From 08-bootstrap.md:
```
core/*.core → corec → synth-core rkyv
synth/*.synth → askicc → dsls.rkyv
aski/*.{core,aski,synth,exec,rfi} → askic → per-module rkyv
per-module rkyv → veric → program.rkyv
program.rkyv → semac → .sema
program.rkyv + .sema → domainc, rsc, askid
```

Every arrow is "consume one surface, emit another surface." The
pipeline IS a surface-passing chain.

**II-L reading: the pipeline already operates at surface
granularity.** Adding more surfaces (e.g., user-facing
`.types`/`.traits`/`.impls`) just adds more nodes in the chain,
with the same rkyv-handoff pattern.

corec ⊂ askicc ⊂ askic in the sense that each consumes a broader
set of surfaces. Under II-L, askic grows to handle `.types`,
`.traits`, `.impls`, `.effects`, etc. But the pattern is
unchanged: surface-in, rkyv-out.

## 8.5 Lesson 5 — The "we already did this" argument

The objection to II-L is "it's a big restructure." The bootstrap
evidence says otherwise: the pipeline is already surface-
structured. Extending from 5 surfaces (core, aski, synth, exec,
rfi) to 12 (adding types, traits, impls, effects, derivations,
test-impls, bench-impls) is an extension of a pattern that's
been working since v0.18.

**Nothing in the bootstrap opposes II-L; the bootstrap IS II-L in
miniature.**

## 8.6 Where the bootstrap falls short of full II-L

The bootstrap's surfaces are kind-granular but not object-granular.
`.core` files bundle multiple types per file. `.synth` files
bundle multiple rules per dialect. `.aski` files bundle multiple
definitions per module.

Full II-L: one public object per file. The bootstrap doesn't
commit to this.

Why doesn't it? Historical: the bootstrap was engineered before
the principle crystallized. The bundling-by-concern is a local
optimum, good enough until II-L spells out the larger optimum.

**Fix: refactor the bootstrap's `.core` files into per-object
files.** Instead of `aski-core/core/domain.core` containing
Domain + Enum + Struct + Newtype + EnumVariant + ..., split into
`aski-core/core/Domain.enum`, `aski-core/core/Enum.struct`,
`aski-core/core/Struct.struct`, `aski-core/core/Newtype.struct`,
`aski-core/core/EnumVariant.enum`, etc.

This refactor does not change corec's behavior; it changes the
input layout. corec loads all `.enum` / `.struct` / `.newtype`
files in a directory and processes them together. Same rkyv
output.

## 8.7 Bootstrap under full II-L — what it would look like

```
aski-core/
  spec/
    design.md                              ;; unchanged
    ...
  source/                                   ;; II-L layout
    imports                                 ;; [core Domain Type …]
    Module.struct                           ;; Module struct def
    Domain.enum                             ;; Enum / Struct / Newtype / Const variants
    Domain/
      Enum.struct                           ;; data for enum
      Struct.struct                         ;; data for struct
      Newtype.struct                        ;; data for newtype
      Const.struct                          ;; data for const
    Variant.enum                            ;; BareVariant / DataVariant / StructVariant / NestedEnum / NestedStruct
    Variant/
      BareVariant.struct
      DataVariant.struct
      StructVariant.struct
      NestedEnum.struct
      NestedStruct.struct
    Field.struct                            ;; Field with name + type
    Type.enum                               ;; Type variants
    Type/
      Named.struct
      AppliedType.struct
      ...
    ...
```

Same types, same rkyv output. Different layout: one per file.

corec walks the directory, picks up every `.enum` / `.struct` /
`.newtype` / `.const` file, emits Rust. The walk replaces the
previous "read `domain.core`, parse top-to-bottom" loop with a
"walk directory, parse each file" loop. Engineering complexity is
similar; tooling gains are real (per-type edit, per-type history,
per-type review).

## 8.8 Interaction with the existing synth-core pipeline

synth-core defines the rkyv types for synth files (Dialect,
Rule, Pattern, etc.). These types are read by askicc (which
produces dsls.rkyv) and askic (which consumes dsls.rkyv).

Under full II-L, synth-core follows the same layout pattern:

```
synth-core/
  source/
    imports
    Dialect.struct
    Rule.struct
    Pattern.enum
    Pattern/
      Literal.struct
      Variable.struct
      Repetition.struct
      ...
    ...
```

Same approach. Walk the directory. Generate rkyv types. No change
to upstream tools.

## 8.9 Aski's source — the next step

Once aski-core/synth-core/veri-core are II-L-refactored, the next
step is the user-facing aski surfaces under the same discipline:

```
aski/source/                                ;; example aski library
  imports
  Counter.struct
  Counter/
    tick.method                             ;; if tick is a method body
  Describe.trait
  Describe-for-Element.impl                  ;; named impl (with its target)
  Read-for-File.effect                       ;; effectful impl
```

This is what `06-derivations-and-testing.md`, `08-bootstrap.md`,
etc., have been pointing at from different angles.

## 8.10 Summary — bootstrap affirms II-L

The bootstrap already uses surface-granular kinds (`.core`,
`.aski`, `.synth`, `.exec`, `.rfi`). II-L extends this: kind
granularity plus object granularity. The bootstrap is a valid but
coarser instance of II-L; full II-L is the refinement.

Nothing in the bootstrap opposes II-L. The "we already did this"
argument from 08-bootstrap.md holds: II-L is not a new pattern;
it's the formalization of the existing pattern at finer
granularity.

---

# 9. Transition plan — realistic waves

This section sketches how aski transitions from v0.20 to full
II-L. Each wave is locally reversible and independently useful.

## 9.1 Wave 0 — grammar split (already in flight)

**What:** Extract the aski surface into per-kind surfaces
(`.types`, `.traits`, `.impls`, `.effects`, etc.) as currently
proposed in 01-surfaces through 07-sema-specialization.

**Status:** Proposed but not landed. Awaiting Li's sign-off on the
multi-surface proposal.

**Scope:** `.aski` files become multiple files with different
extensions but still potentially-multi-object per file. Outer
delimiters still present.

**Value alone:** Paradigm enforcement, surface-level coherence,
ecosystem clarity. Explains 00-vision through 07.

**Reversibility:** Trivial; concatenate the files back into one
`.aski`.

## 9.2 Wave 1 — one public object per file

**What:** Enforce that every `.types` / `.traits` / `.impls` /
etc. file contains exactly one public top-level declaration.
Multiple private declarations still allowed if they're clearly
helper scoped (tension point; resolved in wave 2).

**Grammar change:** Surface Root.synth for each kind is restricted
to `#SingleDecl#<Kind>Body`. Multi-decl files become multi-file.

**Tooling change:** Formatters refuse multi-decl. CI enforces.

**Value alone:** Per-object git history, per-object PR
granularity, per-object LLM context.

**Reversibility:** Straightforward; file concatenation scripts.

## 9.3 Wave 2 — filename is name, extension is kind

**What:** Remove the in-source name and outer delimiter. The file
is named `FastIter.impl`; the file's content is the body directly.

**Grammar change:** Surface root nonterminals shrink to bodies
only. No name, no outer delimiter in source.

**Tooling change:** askic reads the filename as the object's name;
dispatches by extension to the body grammar; parses body only.

**Value alone:** Radical reduction in source-file overhead;
everything II-L promises about filesystem-as-identifier-graph.

**Reversibility:** Tooling to add back the outer wrapper from
filename + extension. Round-trippable.

## 9.4 Wave 3 — private underscore prefix

**What:** Remove the in-source `@` visibility sigil at the root.
Files prefixed `_` are private; unprefixed files are public. (The
`@` sigil survives for struct-field visibility, where sub-file
visibility doesn't apply.)

**Grammar change:** Root grammar doesn't consume an `@` prefix;
visibility is path-level only.

**Tooling change:** askic checks filename for `_` prefix.

**Value alone:** Cleaner source; visibility operationally
filesystem-level.

**Reversibility:** Tooling to prepend `@` or `_` based on filename.

## 9.5 Wave 4 — directory is module, imports file per directory

**What:** Remove in-source `(Name [imports])` module header.
Directory path IS module path. `imports` file at directory root
holds per-directory imports, inherited downward.

**Grammar change:** Module grammar vanishes from file root.
`imports` file gets its own minimal grammar (list of imports).

**Tooling change:** askic walks directories; imports are resolved
per-directory with inheritance.

**Value alone:** Files become even simpler; imports stop being
boilerplate.

**Reversibility:** Tooling to inline imports per file and write
module headers.

## 9.6 Wave 5 — recursive split (optional, per-object)

**What:** Enable file-per-sub-object splits for types with complex
nested content. Methods can split to `.method` files. Variants
can split to `Parent/Child.struct` files.

**Grammar change:** New `.method` surface; generalize nested-
type-as-file-reference.

**Tooling change:** askic resolves name references through the
filesystem when a name points to a sub-file.

**Value alone:** Author choice; available when needed; not forced.

**Reversibility:** Tooling to inline sub-files back into parents.

## 9.7 Wave 6 — bootstrap refactor

**What:** Apply full II-L to aski-core / synth-core / veri-core
`source/` directories. Each type in its own file. Each impl (when
impls land for the bootstrap rkyv types) in its own file.

**Scope:** Self-application of II-L to the bootstrap. Validates
II-L at scale by putting the language's own definitions through
it.

**Value alone:** Dogfooding. Catches II-L tooling gaps. Sets the
example for user code.

## 9.8 Wave 7 — full ecosystem

**What:** Every library published, every program written, uses
II-L by default. Tooling (build systems, package managers, IDEs)
is II-L-aware.

**Scope:** The aski ecosystem at 1.0.

## 9.9 Wave ordering rationale

Waves are ordered for:
1. **Independence** — each wave is useful alone; doesn't require
   later waves.
2. **Reversibility** — each wave's change is machine-reversible.
3. **Risk containment** — grammar-heavy waves (2, 4) are in the
   middle, bracketed by lighter waves.
4. **Value delivery** — each wave delivers user-visible improvement.

The ordering is a suggestion, not a mandate. If Wave 2 (filename-
is-name) seems too aggressive before Wave 1 (one-per-file) is
stable, delay it. If Wave 3 (underscore prefix) is fine to land
alongside Wave 2, combine them.

## 9.10 Non-waves

Things that are NOT in the transition:

- Mass rename of existing `.aski` test files in the bootstrap —
  those can stay in the legacy format until their host repos
  adopt the new layout.
- Changes to the rkyv contract types themselves — II-L rearranges
  source files; the rkyv output stays the same shape.
- Changes to semac or the sema format — these are downstream of
  the source format and unaffected.

## 9.11 Milestones

Wave 0 — multi-surface proposal approved → 01-surfaces landed in spec.
Wave 1 — one-public-per-file → grammar restriction in a specific surface (`.types` first, since simplest).
Wave 2 — filename-is-name → removal of outer delimiter in `.types`; extend to `.traits`, `.impls` as confidence grows.
Wave 3 — underscore-prefix visibility → parallel to Wave 2.
Wave 4 — imports-file → separate milestone, no grammar dependency on Wave 2/3.
Wave 5 — recursive split → opt-in per project; optional forever.
Wave 6 — bootstrap refactor → after Waves 0–4 stabilize.

---

# 10. Integration with aski principles — conflicts and resolutions

II-L adds "the filesystem IS part of the grammar" to aski's axiom
list. Does this clash with the existing axioms?

## 10.1 No keywords (§Delimiter-First)

**Axiom:** aski has no keywords; delimiters and sigils distinguish
constructs.

**II-L effect:** II-L REMOVES material from source; it does not
add keywords. The filename carries what keywords would have carried
in other languages (e.g., `enum`, `struct`, `pub`, `mod`). Aski
never had those keywords; II-L doesn't introduce them.

**Conflict? No.** II-L works with §Delimiter-First by pushing
MORE channels out of source. Source becomes simpler, not more
ornamented.

## 10.2 Names are meaningful

**Axiom:** every name describes what it is; no single letters
except literal letter references.

**II-L effect:** filenames ARE names. Under II-L, a file named
`x.struct` is a struct named `x`, which is a Pascal-violating name.
This would fail aski's case rule.

Clarification: filenames for Pascal-categorical things (types,
traits, modules) are Pascal. Filenames for camel-categorical things
(if any exist at file granularity; most camel things are locals
or methods, which are sub-object-level) would be camel.

Typical case: every file is a Pascal-named type/trait/impl, so
filenames are Pascal by default. Exception: an `imports` file
(lowercase, a non-object meta-file). That's a category of its
own; the lowercase signals "meta, not a normal object."

**Conflict? Resolved** by the convention that filenames follow
aski's case rule based on what they name. Pascal for types and
similar; lowercase-reserved-name for meta-files like `imports`.

## 10.3 Types all the way down

**Axiom:** everything is a type; variables are local type
declarations.

**II-L effect:** files are instances of their kinds
(`FastIter.impl` is an instance of kind `impl`). This fits "types
all the way down" — the kind is the type of the file.

Even stronger: the whole filesystem is a typed tree. Each node is
typed by extension. Each leaf is a body conforming to that type's
body grammar.

**Conflict? No.** II-L is a deep application of "types all the
way down" — it types the filesystem itself.

## 10.4 No newline significance

**Axiom:** newlines are never significant; parsing is token-based.

**II-L effect:** the file boundary IS significant. One file ends
where another begins. Is this "like a newline being significant"?

Subtle. Newlines inside a file carry no meaning; they're just
whitespace. But file-endings DO carry meaning: a body ends when a
file ends.

**Conflict? Not quite, but subtle.** Aski's rule is about
tokenization. Token-based parsing doesn't care about newlines
within a stream. A file IS a stream; II-L treats the file
boundary as the stream boundary, not as a newline. The parser
reads to EOF; EOF marks the end.

Formally: "no newline significance" means whitespace is a token
separator only. File boundaries aren't whitespace; they're
separate streams. No conflict.

## 10.5 Every construct is delimited

**Axiom:** every construct has explicit delimiters so the engine
always knows what it's reading.

**II-L effect:** under II-L, the file IS the delimiter. A `.trait`
file is a trait; the file boundary delimits it. There's no
in-source opener/closer.

**Conflict?** This is the subtle one. "Every construct is
delimited" was written assuming in-source delimiters. II-L moves
the delimiter to the filesystem level. The construct is still
delimited — by the file boundary, not by a token pair.

Resolution: generalize the axiom. "Every construct has a
delimiter" — a pair of tokens, OR a file boundary, OR a directory
boundary. The specific form is a choice; the constraint is that
construct boundaries are unambiguous.

Under II-L's generalization: in-body constructs still have token-
pair delimiters (match, loop, struct, etc.); file-level constructs
have file boundaries. Both are delimiters. Both enable first-
token decidability (at their respective levels).

No structural conflict; an axiom refinement that makes II-L
compatible.

## 10.6 No complex lookahead

**Axiom:** aski's grammar is first-token-decidable at every choice
point; escape valve is creating a new DSL/surface.

**II-L effect:** every file's root grammar is even simpler than
before, because the kind is already known from the extension. The
first token in a `.struct` file is the first field (or `{$Param}`
if generic) — decidable with zero lookahead.

Across files: each file stands alone grammatically. No cross-
file lookahead needed at parse time. Coherence across files is
semantic (veric), not syntactic.

**Conflict? No.** II-L makes the "no complex lookahead" axiom
easier to satisfy, not harder.

## 10.7 Scopes are a tree

**Axiom:** names live in a scope tree; nested definitions create
scopes; names can shadow.

**II-L effect:** the scope tree IS the filesystem tree. Module
scopes are directories. Type scopes (for nested types) are
sub-files or in-body nesting. Name resolution walks the filesystem
tree, then walks into file bodies for inner scopes.

**Conflict? No.** II-L LITERALIZES the scope tree as the
filesystem. The mental model ("names live in a tree") is now the
operational model ("names ARE filesystem paths").

## 10.8 Position defines meaning

**Axiom:** the same delimiter means different things in different
positions; synth dialects are the authority.

**II-L effect:** position is preserved at two levels — the file's
extension defines the surface (which defines the grammar); the
position inside the file defines the construct within that
grammar. Two-level position.

**Conflict? No.** II-L adds one more level of positional context
(the surface/extension) without changing how within-file position
works.

## 10.9 Data-tree is the parser state

**Axiom:** the data-tree built by askicc IS the parsing state
machine.

**II-L effect:** under II-L, the outer shape of the data-tree
(module-level names) comes from the filesystem walk, not from
parsing in-source tokens. The inner shape (body contents) is
built by askic as before.

**Conflict? Refined.** The data-tree is built from two sources:
filesystem structure (outer) and file contents (inner). Both
contribute. The ultimate rkyv tree is a merge of both sources.

askic gains a "scan filesystem, enumerate files per surface"
phase before "parse each file's body into a sub-tree." The
output is the same: an rkyv data-tree.

## 10.10 Summary — principle integration

| Aski axiom | II-L effect | Conflict? |
|------------|-------------|-----------|
| No keywords | Pushes more out of source | No; reinforces |
| Names meaningful | Filenames are names | Resolved (case rule on filenames) |
| Types all the way down | Typed filesystem | No; extends |
| No newline significance | File boundary = stream boundary | No; orthogonal |
| Every construct delimited | File = delimiter | Refined axiom |
| No complex lookahead | Even simpler grammar | No; eases |
| Scopes are a tree | Filesystem IS the scope tree | No; literalizes |
| Position defines meaning | Two-level position | No; extends |
| Data-tree IS parser state | FS + file contents merge | Refined |

No axiom is broken. Two axioms (every-construct-delimited, data-
tree-is-parser-state) receive natural generalizations. The rest
integrate directly.

II-L is consistent with all of aski's existing design commitments.
It strengthens the spirit of several of them (Names Meaningful,
Types All The Way Down, Scopes Are a Tree). It is, in a precise
sense, the destination aski's axioms have been pointing at.

---

# 11. Open questions — what's still unsettled

II-L answers the big structural questions. Several details remain
open and need Li's call.

## 11.1 Filename conventions

**Q1.** Should filenames use Pascal or the object's case exactly?

Types are Pascal; filenames like `Counter.struct` are Pascal.
Methods are camel; filenames like `tick.method` are camel.
What about:
- `Counter/tick.method` — `Counter` dir (Pascal, type-scoped)
  containing `tick.method` (camel, instance-level). Consistent.
- `Counter/_tick.method` — private method. The underscore prefix
  applied at method level. Consistent.

Settles cleanly. Just confirming.

**Q2.** How are colons in aski names (e.g., `Char:Upper:A`)
mapped to filesystem paths?

Proposal: colons map to directory separators. `Char:Upper:A`
becomes `Char/Upper/A.enum` (or whatever the leaf kind is).
Nested-enum variants in source map to directories on disk.

Alternative: keep colons in filenames on filesystems that allow
them; map to another character (e.g., `.` or `_`) where colons
aren't allowed.

Pick one. The first is more II-L-aligned; the second is simpler
for one-layer names.

**Q3.** Should impl filenames encode trait + target? E.g.,
`Iterator-for-TokenStream.impl` or just `FastIter.impl`?

v0.20 names impls with a distinct name (FastIter); the trait +
target live inside. II-L with trait+target inside the file is
fine. But a naming convention like `FastIter-Iterator-TokenStream.impl`
would make the full identity visible at a glance. Trade-off:
longer filenames vs. self-documenting path.

Pick one. Probably the shorter form; the inside-file contents
carry the rest.

## 11.2 Nested types — file vs. inline

**Q4.** When does a nested type become its own file versus
staying inline?

Heuristic: by size and reuse. Small, used-only-here: inline. Large
or referenced from outside: its own file. Currently an author
choice; II-L could specify a guideline or leave it fully open.

## 11.3 Method splits

**Q5.** Should methods of an impl be split to their own files by
default, only for large methods, or never (impls always one file)?

Three options:
- Always split: every method is a `.method` file.
- Sometimes split: at author discretion, above some line count.
- Never split: methods stay inside the `.impl` file.

II-L allows the first and second; the third is a subset of II-L.
Pick a default convention; let authors override.

## 11.4 Derivation output location

**Q6.** Do derivations emit synthetic `.impl` files on disk, or
just in-memory records in veric?

See §6.7 for the analysis. Mixed option (emit files in
`.build/derivations/` but manage them automatically) is
II-L-aligned. Pick one.

## 11.5 Package boundary

**Q7.** Is a package a top-level directory, or is there a manifest
file above the directory?

Convention in other languages is the manifest (Cargo.toml etc.).
II-L doesn't require a manifest, but a build system likely does.
Where does the manifest live? How is the library's name declared?

Provisional: manifest at project root (e.g., `lojix.toml`
alongside `source/`). Library's name from the manifest or from
the root directory's name. Details open.

## 11.6 Cross-file forward references

**Q8.** If file `Foo.struct` references `Bar`, is `Bar`'s file
parsed first or does the reference resolve lazily?

Two-pass compilation: first pass walks the filesystem and builds
the name table; second pass parses each body and resolves
references against the name table. Standard; II-L doesn't break
this.

If `Bar` doesn't exist (no `Bar.struct` or `Bar.enum` or `Bar.newtype`
anywhere reachable), the reference fails at the second pass. Same
as Rust's "cannot find type `Bar`" error.

## 11.7 File name conflicts across kinds

**Q9.** Is `Foo.struct` + `Foo.enum` in the same directory a hard
error or allowed (they're different extensions)?

§7.9 recommended: hard error. Confirming.

## 11.8 Symlink policy

**Q10.** Does veric follow symlinks when walking the filesystem?

§7.10 recommended: no. Confirming.

## 11.9 File encoding

**Q11.** Filenames must be UTF-8 encodable? ASCII only? Specific
character set?

Recommendation: ASCII only, for cross-platform reliability. Pascal
names already ASCII-first. Non-ASCII content in bodies (string
literals) is fine; filenames stay ASCII.

Mostly settles automatically — Li's names have been ASCII
throughout. Just confirming.

## 11.10 Import file grammar

**Q12.** What's the grammar of the `imports` file itself?

Proposal: one `[Source Name Name Name]` group per line, matching
v0.20's in-source import syntax. Same grammar as v0.20's module-
header imports; just in its own file.

## 11.11 Per-surface root grammar, once-more

**Q13.** For each kind, spell out the final body-root grammar.
§3 sketched the root grammars for `.enum` / `.struct` / `.trait` /
`.impl`; the full set needs filling in:
- `.newtype` → `#NewtypeBody#<Type>`
- `.const` → `#ConstBody#<Type> <Literal>` (or `<Expr>` if const
  expressions land)
- `.effect` → same as `.impl`; extension-marks-effect-status
- `.derivation` → pattern-based impl; detailed in 06
- `.test-impls` → same as `.impl`; extension-marks-test
- `.bench-impls` → same as `.impl`; extension-marks-bench
- `<platform>.impl` → same as `.impl`; platform-carrying extension

Mostly mechanical. Each is a one-line root grammar. Needs
assembling into a single per-surface grammar table.

## 11.12 Sub-directory inheritance rules for imports

**Q14.** If parent directory's `imports` provides `Vec`, and
a sub-directory's `imports` provides `Vec2` (a different type
with same first characters), are both visible in the sub-
directory?

Proposal: yes; the sub-directory's `imports` adds to the parent's
without replacing. Both names are in scope. Name collision across
levels (parent has `Vec`, child has `Vec`) is the standard
shadowing question; design.md §Scopes Are a Tree handles it.

## 11.13 Dead-file detection

**Q15.** Can the build tool detect files that no longer correspond
to a live object (e.g., an orphan `.impl` whose trait was
deleted)?

Yes, as a side effect of coherence checking. If an impl's trait
doesn't resolve, veric reports an error. Standard dangling-
reference detection.

## 11.14 Summary of open questions

All are detail questions, not principle questions. The principle
(II-L) stands regardless of how these are answered. Each answer
is an authoring convention or build-system detail.

---

# 12. Closing — what the principle buys us

Aski's existing axioms (no keywords, names meaningful, delimiter-
first, types-all-the-way-down, scopes-as-trees) carve out a space
with a specific shape: a language that wants every piece of
information EXPLICIT, every name MEANINGFUL, every structure
VISIBLE.

II-L is the observation that the filesystem fits that shape. A
filesystem is:
- Explicit — every path is a first-class name.
- Meaningful — by convention, paths describe what's there.
- Visible — tooling universally sees paths.
- Tree-structured — matches aski's scope tree.
- Typed (via extensions) — matches aski's types-all-the-way-down.

It would be strange, given aski's other commitments, NOT to use
the filesystem as the identifier graph. II-L is the answer to
"where should aski's identifiers live?" — they should live where
everything else that matters to aski already lives.

The previous analysis enumerated features because features were
visible. The underlying reason they all fit together is that each
is a filesystem channel: the filename is one channel; the extension
is another; the path hierarchy is another; the per-directory
imports file is another. All channels are orthogonal. All channels
are tree-shaped. All channels move cleanly from in-source
encoding to filesystem encoding.

When you look at a v0.20 `.aski` file and ask "what does this file
hold that the filesystem couldn't hold equivalently?" — the answer
is: just the body. Everything else (name, kind, visibility, module,
imports) is metadata that the filesystem can carry.

II-L is the observation that we should let the filesystem carry it.

---

# 13. One-sentence summary

> Aski's decomposition principle: **identity is location, location
> is path, and a path is a filesystem path — so the filesystem
> becomes the program's identifier graph and source files hold
> only the irreducible bodies those paths refer to.**

Everything on this page is a consequence.

---

*End.*
