# Aski v0.21 — Syntax Specification

Aski under **Identity-is-Location (II-L)**. A name is a place. A place is a path. A path is a filesystem path. Source files hold only what has no name of its own — their bodies.

This is the canonical reference, split across [syntax-v021/](syntax-v021/) per section.

## Chapters

| # | File | Contents |
|---|------|----------|
| 00 | [Overview](syntax-v021/00-overview.md) | II-L principle, filesystem layout, imports, delimiters, sigils |
| 01 | [Enums](syntax-v021/01-enums.md) | `Name.enum` — variants, discriminants, nested enums |
| 02 | [Structs](syntax-v021/02-structs.md) | `Name.struct` — fields, generics, self-typed fields, nested types |
| 03 | [Newtypes and consts](syntax-v021/03-newtypes-consts.md) | `Name.newtype`, `Name.const` with const expressions |
| 04 | [Traits](syntax-v021/04-traits.md) | `Name.trait` — assoc types, assoc consts, defaults, super-traits |
| 05 | [Impls](syntax-v021/05-impls.md) | `Trait[Args]~Target.impl` — filename grammar, blankets, named impls |
| 06 | [Effects, derivations, tests](syntax-v021/06-effects-derivations-tests.md) | `.effect`, `.derivation`, `.test-impl`, `.bench-impl` |
| 07 | [Modules and visibility](syntax-v021/07-modules-visibility.md) | Directory = module; `_` prefix = private |
| 08 | [Body basics](syntax-v021/08-body-basics.md) | Literals, local decls, references, origins, views, generics |
| 09 | [Control flow](syntax-v021/09-control-flow.md) | Match, loops, iteration, early return, try-unwrap, or-pattern |
| 10 | [Self, mutation, cast, path](syntax-v021/10-self-mutation-cast-path.md) | `self`, `~` mutation, cast via `From`/`Into`, path `:` |
| 11 | [Stdlib primitives](syntax-v021/11-stdlib-primitives.md) | `Bool`, `Never`, `'Static`, `Char` library, arrays |
| 12 | [Expressions](syntax-v021/12-expressions.md) | Operators, `dyn`, closures, literal patterns, atoms |
| 13 | [RFI and exec](syntax-v021/13-rfi-exec.md) | `.rfi` foreign interfaces, `.exec` entry points |
| 14 | [Scorecard](syntax-v021/14-scorecard.md) | Rust feature coverage table |
| 15 | [Edge cases](syntax-v021/15-edge-cases.md) | II-L edge cases and precedent |
| 16 | [Open questions](syntax-v021/16-open-questions.md) | Items not yet settled |

## Quick jumps by concern

- **Types (shape)** → [01](syntax-v021/01-enums.md), [02](syntax-v021/02-structs.md), [03](syntax-v021/03-newtypes-consts.md), [11](syntax-v021/11-stdlib-primitives.md)
- **Traits (interface)** → [04](syntax-v021/04-traits.md)
- **Impls (behavior)** → [05](syntax-v021/05-impls.md), [06](syntax-v021/06-effects-derivations-tests.md)
- **Layout (filesystem / modules)** → [00](syntax-v021/00-overview.md), [07](syntax-v021/07-modules-visibility.md)
- **Body grammar** → [08](syntax-v021/08-body-basics.md), [09](syntax-v021/09-control-flow.md), [10](syntax-v021/10-self-mutation-cast-path.md), [12](syntax-v021/12-expressions.md)
- **Surfaces (other)** → [13](syntax-v021/13-rfi-exec.md)
- **Reference / audit** → [14](syntax-v021/14-scorecard.md), [15](syntax-v021/15-edge-cases.md), [16](syntax-v021/16-open-questions.md)

## Companion docs

- [design.md](design.md) — load-bearing principles (case rule, delimiter-first, II-L rationale)
- [architecture.md](architecture.md) — pipeline (corec → askicc → askic → veric → semac → …)
- [synth.md](synth.md) — the synth grammar-spec language

Each chapter is self-contained — you can read one without the others and get a working picture of that area. Cross-references use relative markdown links.
