# aski — The Aski Language

Aski is a text notation for specifying sema. This repo holds:

- `spec/` — language design and syntax reference
- `tree-sitter-aski/` — tree-sitter grammar (for syntax highlighting + editor integrations)
- `aski-mode.el` / `aski-ts-mode.el` — Emacs modes for aski source
- `nix/editor.nix` — Nix derivation for the tree-sitter grammar and Emacs modes

## What aski is (and isn't)

**Aski is** one frontend for sema — a human-readable, writable-by-hand text projection of sema's typed binary format. It's the stepping stone that makes sema visible so the system can be built. Other frontends may exist.

**Aski is not** the canonical sema representation. `.sema` binary is canonical; `.aski` is a projection. Aski source is rkyv-serialized as it moves through the compilation pipeline until semac resolves it down to pure bytes.

## Role in the pipeline

The aski source is parsed by `askic` (separate repo), validated by `veric`, and compiled to sema by `semac`. The rkyv types that represent the parse tree live in `aski-core` (a separate Rust crate — the types contract between askic / veric / semac).

```
aski (source)
  ↓ lexed + parsed by askic, producing aski-core typed rkyv
  ↓ verified + linked by veric, producing veri-core typed rkyv
  ↓ compiled by semac, producing .sema binary
  ↓ domainc + rsc generate Rust; askid generates canonical .aski
```

## Reading order

Start with [spec/design.md](spec/design.md) — the load-bearing principles (case rule, delimiter-first, II-L, sema invariant).

Then [spec/syntax-v021.md](spec/syntax-v021.md) for the canonical language spec (split across [spec/syntax-v021/](spec/syntax-v021/) by chapter).

## Spec layout

- [spec/design.md](spec/design.md) — settled design principles
- [spec/syntax-v021.md](spec/syntax-v021.md) + [spec/syntax-v021/](spec/syntax-v021/) — language by example (v0.21, Identity-is-Location)
- [spec/architecture.md](spec/architecture.md) — pipeline (corec → askicc → askic → veric → semac → …)
- [spec/synth.md](spec/synth.md) — the synth grammar-spec language

## Related repos

- `aski-core` — rkyv types for the parse tree (the contract that askic, veric, semac all speak)
- `askicc` — synth compiler: reads `.synth` files from aski's grammar, produces `dsls.rkyv`
- `askic` — aski frontend: reads `.aski` source + `dsls.rkyv`, produces per-module aski-core rkyv
- `veric` — verifier + linker
- `semac` — sema backend
- `sema` — top-level Nix aggregator

## VCS

Jujutsu (`jj`) mandatory. Git is storage backend only.
