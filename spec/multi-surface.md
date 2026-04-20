# Multi-Surface Aski — The Series

*2026-04-20 · a pitch for what aski can become.*

Aski's `core` DSL is not an exception. It is the **precursor**. A types-
only surface has been bootstrapping the language from day one: `.core`
defines the rkyv contracts; corec reads them and emits Rust; every
downstream tool consumes those types. That pattern — one surface
feeding another — is what makes the whole pipeline work.

The question this series asks: **what if every concern got its own
surface?** Types separate from traits separate from impls separate
from effects separate from derivations separate from tests. Each
surface with its own grammar, its own parser dialect, its own rkyv
contract, composing into one program.

What you get is not "Rust with extra files." What you get is a
language where **every file commitment carries meaning**, where the
link graph IS the program's architecture, and where features Rust
can't express — named impls, scoped coherence, effect tracking at
the link level, platform specialization, first-class derivation —
become natural.

This series makes the case.

---

## The docs

- **[00-vision.md](multi-surface/00-vision.md)** — the pitch.
- **[01-surfaces.md](multi-surface/01-surfaces.md)** — the inventory.
- **[02-types.md](multi-surface/02-types.md)** — `.types` surface and every Rust type in aski.
- **[03-traits.md](multi-surface/03-traits.md)** — `.traits` surface and every Rust trait feature.
- **[04-impls.md](multi-surface/04-impls.md)** — `.impls` + named impls + global coherence.
- **[05-effects-and-platforms.md](multi-surface/05-effects-and-platforms.md)** — effect surfaces and capability systems.
- **[06-derivations-and-testing.md](multi-surface/06-derivations-and-testing.md)** — `.derivations` and `.test-impls`.
- **[07-sema-specialization.md](multi-surface/07-sema-specialization.md)** — same source, different sema.
- **[08-bootstrap.md](multi-surface/08-bootstrap.md)** — `.core` was the first. Self-hosting by surface.
- **[09-rust-complete.md](multi-surface/09-rust-complete.md)** — every Rust feature mapped into aski.
- **[10-transition.md](multi-surface/10-transition.md)** — how aski v0.20 grows into this.

---

## Claim

Through multi-surface design, aski can **express all of Rust** except
what its paradigm deliberately rejects (free functions, nameless
tuples, shadowing). Everything else Rust has — traits, generics,
lifetimes, async, closures, dyn dispatch, macros, unsafe — has a
natural home in some surface. Many of those things become cleaner
than in Rust: coherence that relaxes the orphan rule, effect tracking
without monads, capability systems without ports runtime, derivation
that's first-class.

And the precedent is already shipping: the `core` DSL proved it works.
