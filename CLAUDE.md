# aski — The Aski Language

Aski is a text notation for specifying sema. This repo holds:

- `spec/` — language design, grammar reference, syntax by example,
  Rust-gap analysis, bridge proposals.
- `tree-sitter-aski/` — tree-sitter grammar (for syntax highlighting
  + editor integrations).
- `aski-mode.el` / `aski-ts-mode.el` — Emacs modes for aski source.
- `nix/editor.nix` — Nix derivation for the tree-sitter grammar and
  the Emacs modes.

## What aski is (and isn't)

**Aski is** one frontend for sema — a human-readable, writable-by-hand
text projection of sema's typed binary format. It's the stepping stone
that makes sema visible so the system can be built. Other frontends
may exist.

**Aski is not** the canonical sema representation. `.sema` binary is
canonical; `.aski` is a projection. Aski source is rkyv-serialized as
it moves through the compilation pipeline until semac resolves it
down to pure bytes.

## Role in the pipeline

The aski source is parsed by `askic` (in a separate repo), validated
by `veric`, and compiled to sema by `semac`. The rkyv types that
represent the parse tree live in `aski-core` (a separate Rust crate
repo — the types contract between askic / veric / semac).

```
aski (source) — this repo's spec + grammar define what's legal
  ↓ lexed + parsed by askic, producing aski-core typed rkyv
  ↓ verified + linked by veric, producing veri-core typed rkyv
  ↓ compiled by semac, producing .sema binary
  ↓ domainc + rsc generate Rust; askid generates canonical .aski
```

## Design philosophy (crucial)

Read `spec/design.md` first. It lists the load-bearing constraints:

- Sema is the source of truth; aski is a projection.
- Every syntactic construct is specified by a synth dialect file.
- No newlines significance, delimiter-driven, position-derived meaning.
- No keywords; every symbol carries semantic weight.
- PascalCase = compile-time structural things; camelCase = actual
  instances of a type (see `spec/design.md §PascalCase and camelCase`).

Then read `spec/syntax-v020.aski` for the current language by example
and `spec/bridge/paradigm.md` for the spec-status framework.

## Key docs

### Language spec (authoritative)
- `spec/design.md` — design constraints and rationale
- `spec/synth.md` — synth grammar (the meta-language)
- `spec/architecture.md` — pipeline + surfaces
- `spec/syntax-v020.aski` — current aski syntax by example (v0.20)

### Rust-gap analysis + bridge proposals
- `spec/gap-analysis.md` — catalog of Rust features aski doesn't yet
  cover, with severity and spec-silent-vs-confirmed-OUT distinction.
- `spec/bridge-proposals.md` — index of bridge-proposal docs.
- `spec/bridge/paradigm.md` — ground truth on aski↔Rust relationship
  and spec-status levels (Landed / Proposed / Unspec'd / Confirmed OUT).
- `spec/bridge/clear.md` — items with clear resolution.
- `spec/bridge/small-decisions.md` — items awaiting naming / sigil nod.
- `spec/bridge/big-decisions.md` — items with open design.

## Related repos

- `aski-core` — rkyv types for the parse tree (the contract that
  askic, veric, semac all speak).
- `askicc` — synth compiler: reads `.synth` files from aski's grammar,
  produces `dsls.rkyv`.
- `askic` — aski frontend: reads `.aski` source + `dsls.rkyv`, produces
  per-module aski-core rkyv.
- `veric` — verifier + linker.
- `semac` — sema backend.
- `sema` — top-level Nix aggregator.

## VCS

Jujutsu (`jj`) mandatory. Git is storage backend only.
