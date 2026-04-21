# 07 — Sema Specialization by Impl Graph

*Same aski source, different sema binaries, determined by link-time
impl choice.*

[← 06-derivations-and-testing](06-derivations-and-testing.md) · [08-bootstrap →](08-bootstrap.md)

---

# The thesis

Today, Rust's binary is determined by:
- Source code
- Dependency versions
- Feature flags at compile time
- `cfg` directives
- Profile (debug/release)

Each is a compile-time choice, but they're scattered across
`Cargo.toml`, `build.rs`, and source. Reasoning about "why does this
binary look different from that one?" requires piecing the config
together.

In aski, **the binary is determined by the impl graph**. Given:
- `.types` and `.traits` — the shape of the program
- `.impls` / `.effects` — the chosen behaviors
- `.derivations` — the rules that generate more impls
- Module-header + scope-level activations

semac produces a sema binary. Change which `.impls` or `.effects`
files link; the sema binary changes. The change is structural, not
configuration-file-based.

---

# Why sema cares about impls

Sema is **domain variants as bytes**. Every value has a layout. For
primitive types, layout is fixed (U32 is 4 bytes, Option<U32> is tag
+ 4 bytes). For user types, layout is determined by the sema domain
of that type.

Methods aren't part of the sema layout — they're compiled to sema
actions (reads, writes, dispatches). The sema action for
`iter.next()` depends on which impl `next` routes to.

**Different impls → different sema actions → different sema binary
for the same trait call.**

This is analogous to Rust's monomorphization but at the impl level,
not just the generic-type level.

---

# Scenario 1 — fast vs safe iteration

```aski
;; fast-iter.impls
@[FastIter Iterator TokenStream [
  (next ~&self {Option Token} [
    (| self.cursor < self.buffer.len
      ( True ) [
        (token self.buffer.unchecked(self.cursor))
        ~self.cursor.addAssign(1)
        Option:Some(token)
      ]
      ( False ) Option:None
    |)
  ])
]]

;; safe-iter.impls
@[SafeIter Iterator TokenStream [
  (next ~&self {Option Token} [
    ~self.cursor.addAssign(1)
    (idx self.cursor - 1)
    self.buffer.get(idx).cloned
  ])
]]
```

Build A (release): links `fast-iter.impls`, activates `FastIter` at
top of `main.exec`. sema encodes direct-offset reads.

Build B (debug): links `safe-iter.impls`, activates `SafeIter`. sema
encodes bounds-checked `.get` dispatch.

Same source in the top-level `.exec`. Two different sema binaries.

---

# Scenario 2 — platform-specific binary

```aski
;; native.effects pins FileSystem to Posix impls
;; wasm.effects pins FileSystem to Wasi impls
```

Build for native: sema binary calls into Posix syscalls for file
I/O.

Build for wasm: sema binary calls into Wasi host functions.

Both binaries are valid sema. Both round-trip through askid back
to the same source. The sema layer is identical shape; only the
effect edges differ.

---

# Scenario 3 — algorithm variants

Rust has to express this via generic parameters or feature flags:

```rust
#[cfg(feature = "rayon")]
fn sort(v: &mut Vec<u32>) { v.par_sort(); }

#[cfg(not(feature = "rayon"))]
fn sort(v: &mut Vec<u32>) { v.sort(); }
```

In aski:

```aski
;; single-thread.impls
@[Default Sort {Vec U32} [
  (sort ~&self [ self.sortUnstable ])
]]

;; rayon.impls
@[Default Sort {Vec U32} [
  (sort ~&self [ Rfi:Rayon:parallelSort(self) ])
]]
```

Build with `rayon.impls` → parallel-sort sema binary.
Build without → single-threaded sema binary.

Source `.exec` is unchanged. The algorithm choice is purely a
link-graph commitment.

---

# Scenario 4 — benchmarking variants

```aski
;; noop-log.impls
@[Default Log Logger [
  (log ~&self &_ String [ Unit ])         ;; discard
]]

;; stderr-log.effects
@[Default Log Logger [
  (log ~&self &message String [Rfi:Stderr:write(message)])
]]

;; counting-log.impls
@[Default Log Logger [
  (log ~&self &_ String [
    ~self.counter.addAssign(1)               ;; counts without logging
  ])
]]
```

Benchmark with `counting-log.impls` → sema counts without I/O
overhead.

Production with `stderr-log.effects` → sema actually writes to
stderr.

Development with `noop-log.impls` → log calls are eliminated
entirely (or approximately — veric may inline `Unit` returns).

---

# Specialization and coherence interact cleanly

When impls carry explicit names and scopes:

- Every impl selection is **statically determined** at each call site.
- sema records the resolution, not the trait call.
- Generated sema is always as-specialized-as-possible given the
  link graph.

Runtime dispatch (via `dyn Trait`) exists as an option but is rarely
needed — explicit scopes cover most cases.

Rust's monomorphization produces code bloat (each generic
instantiation is a separate copy). aski's impl-specialization
produces targeted sema for each (call site, impl) combination —
same shape, narrower.

---

# The compiled artifact model

semac emits:

1. **`program.sema`** — the main binary, specialized against the
   linked impl graph.
2. **`program.names.sema`** — name projection table (how domain
   variants map back to source names).
3. **`program.impls.sema`** — impl-graph metadata (which impl each
   resolved call targets). Useful for debugging, profiling, and
   inspection.

The `.impls.sema` artifact is a **specialization trace**. You can
ask the binary "what impl does this call go through?" and get an
exact answer.

---

# Recompilation on impl change

Change `fast-iter.impls` → only the `Iterator TokenStream` call sites
need re-specialization. The rest of the sema is unchanged.

veric + semac incremental build:

1. Detect which impls changed.
2. For each, compute which scopes activated them (from the impl
   graph).
3. Re-specialize those scopes.
4. Patch the sema binary.

Fine-grained incremental compilation becomes the default.

---

# Comparison to Rust's monomorphization

Rust:
- Every generic instantiation is a fresh copy.
- Code bloat proportional to (generics × instantiation sites).
- Compile time scales poorly with generic-heavy code.

aski with impl specialization:
- Each (call site, impl) combination generates one sema action,
  inlined where small, out-of-line where large.
- Impl changes trigger narrow recompiles.
- Code size bounded by impl count, not instantiation count.

---

# The philosophical shift

In Rust, "what this binary does" is the conjunction of source, cargo
flags, environment, rustc flags, feature flags, and profile. A
scattered set of inputs.

In aski, "what this binary does" is the source + the impl graph.
Period. Every other choice expresses itself as an impl selection.

**The impl graph is the build's unit of truth.** Tools that diff
impl graphs diff binary behavior. Tools that audit effect closures
audit binary side effects. Tools that measure specialization measure
binary performance.

This is a cleaner model than Rust's. It follows from the surface
split.

---

# Visualizing an aski build

```
source:
  shapes.types
  iter.traits
  fast-iter.impls       } — linked in release
  safe-iter.impls       } — linked in debug
  native.effects        } — linked on native
  wasm.effects          } — linked on wasm
  core-common.derivations
  app.exec

build command:
  askic build --profile=release --platform=native
  
link graph:
  shapes.types + iter.traits + fast-iter.impls + 
  native.effects + core-common.derivations + app.exec
  
activations (from app.exec module header):
  Iterator TokenStream → FastIter

specialization trace:
  parseTokens/tokens.next → FastIter::next (inline)
  engine.load → System::readFile (native.effects)

emitted:
  app.sema            (specialized binary)
  app.names.sema      (name projection)
  app.impls.sema      (resolution trace)
```

Every piece is visible. Every choice is explicit. The build is
reconstructible from its inputs.

---

# Next

`.core` is the first multi-surface DSL in the aski family. Let's see
how it proves the model and how self-hosting emerges.
[08-bootstrap →](08-bootstrap.md)
