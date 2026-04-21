# 05 — Effect Surfaces and Capability Platforms

*Impure operations and platform-specific behavior, at the link level.*

[← 04-impls](04-impls.md) · [06-derivations-and-testing →](06-derivations-and-testing.md)

---

# Part A: The `.effects` surface

## The problem effects solve

Side effects — I/O, mutation of external state, reading clocks,
random number generation — are the hardest thing to reason about in
any codebase. They invalidate local reasoning. They make tests
harder. They make concurrency harder.

Languages take three approaches:

1. **Ignore** (Rust, Go, C): honor system. A function may or may not
   have effects. You find out by reading source or by running.
2. **Type-track** (Haskell): effects show in types via monads
   (`IO String`, `ST s`). Powerful but adds type noise everywhere.
3. **Link-track** (proposed aski): effects show in file extensions.
   If code imports `.effects`, it can have effects; if not, it
   can't.

Option 3 is aski's unlock.

---

## What `.effects` contains

The same shape as `.impls`:

```aski
@[ImplName TraitName Target [ *<TraitImplItem> ]]
```

The difference is **what the impl is allowed to do inside**. An
`.effects` impl can:

- Read files, write files, open sockets
- Read the system clock
- Call into RFI (Rust foreign functions, which are effects at the
  language boundary)
- Trigger global mutation (log sinks, counter updates)
- Invoke any other `.effects` impl transitively

A `.impls` impl cannot do any of those. veric enforces.

---

## Example — file reading

```rust
impl FileReader for LocalFs {
    fn read_all(&self, path: &Path) -> Result<String, Error> {
        std::fs::read_to_string(path)
    }
}
```

```aski
;; localfs.effects
@[Default FileReader LocalFs [
  (readAll &self &path Path {Result String Error} [
    Rfi:FileSystem:readToString(path)
  ])
]]
```

The impl lives in `.effects`. `Rfi:FileSystem:readToString` is a
call into the RFI surface's FileSystem declaration (defined in a
`.rfi` file), which reaches native Rust filesystem operations. The
effect is tracked: anyone using `FileReader` for `LocalFs` has the
`FileSystem` RFI dependency in their effect closure.

---

## The import-based purity proof

```aski
;; pure-math.impls
(PureMath [arithmetic Add Sub Mul])     ;; imports .types + .traits only

@[Default Sum Vec {$Value{Add}} [
  (sum &self $Value [
    (total $Value:zero)
    {| self.items.item
      ~total.addAssign(item)
    |}
    total
  ])
]]
```

This impl:
- Imports `.types` and `.traits` (pure).
- Does not import any `.effects`.
- Does not import `.rfi`.

**Guaranteed pure.** veric verifies by walking the import graph.
`pure-math.impls` can be reasoned about locally without concern for
timing, external state, or I/O.

---

## Effect closure of a program

For any `.exec` or any `.impls` file, veric computes the **effect
closure** — the set of `.effects` files reachable transitively
through imports.

```aski
Program my-app.exec
├── Imports my-app.impls                 [no effects]
│   └── Imports pure-math.impls           [no effects]
└── Imports storage.effects               [effect: FileSystem]
    └── Imports io.rfi                    [RFI: FileSystem, Network]

Effect closure: { FileSystem, Network }
```

The build system emits this closure. Users see at a glance what
effects a program relies on. Libraries advertise "zero effects" by
having an empty closure.

---

## Audit by grep

Want to know what a dependency touches?

```
grep -l "import.*\\.effects" deps/**/*
```

Every file importing an `.effects` surface is a candidate side-effect
site. `.effects` files are explicit and few. Surface-level auditing
is trivial.

---

## Effect categories

One `.effects` file can focus on a category:

```
filesystem.effects      ;; file I/O
network.effects         ;; sockets, HTTP
clock.effects           ;; time, timers
logger.effects          ;; log sinks
process.effects         ;; spawn, env, stdin
random.effects          ;; RNG
```

Fine-grained closures: "this library imports only `clock.effects` —
it reads time but does nothing else."

---

## Pure functions calling effectful functions

If a pure `.impls` method wants to accept an effectful impl as a
dependency, it takes it as a generic parameter:

```aski
;; pure-logic.impls
@[Default ProcessItems Processor [
  (processAll ?{$Storage} ~&self :storage $Storage {Vec Item} [
    (items :storage.readAll)      ;; :storage may or may not be effectful
    (filtered items.filter(self.valid))
    filtered
  ])
]]
```

The method is pure in itself — it delegates effectful operations to
the generic `$Storage`. At the call site, the caller injects a
concrete impl (which may be in `.effects`). The effect flows through
the caller, not the pure method.

This is **dependency injection for effects**. Testable. Composable.
Trackable at the build graph.

---

## Effect composition

An `.effects` file can import other `.effects` files:

```aski
;; composite-logger.effects
@[Default Logger Multi [
  (log ~&self &message String [
    ~Stderr:write(message)           ;; uses stderr.effects
    ~File:append("log.txt" message)  ;; uses filesystem.effects
  ])
]]
```

The composite effect's closure is the union of its parts. Automatic.

---

## Pure vs impure traits

Traits themselves don't carry effect labels. A trait is a shape.
Whether a specific impl is pure or effectful is determined by **which
surface the impl lives in**. Same trait can have both kinds of impls:

```aski
;; pure-clock.impls
@[Mock Clock FixedTime [
  (now &self Time [self.pinnedTime])     ;; pure — reads own state
]]

;; real-clock.effects
@[SystemClock Clock Utc [
  (now &self Time [Rfi:Time:systemNowUtc])  ;; effectful — reads system clock
]]
```

A test uses `FixedTime`. Production uses `Utc`. Effect closure
changes. Behavior from the caller's perspective is identical shape.

---

# Part B: Platform-impl surfaces

## The platform problem

Multi-platform code struggles in every language. You want:
- One source tree.
- Platform-specific behavior where needed (file paths differ; console
  output differs; timing API differs; network stack differs).
- Build selects the platform; dispatch is static.

Rust uses `#[cfg(target_os = "…")]` sprinkled through source. Works
but scatters platform concerns.

Elm uses ports — runtime JavaScript interop. Works but adds runtime
overhead.

aski's approach: **platform-specific `.impls` surfaces**, selected
at build time.

---

## Surface names

```
native.impls            ;; implementations for native desktop targets
native.effects          ;; effectful impls for native
browser.impls           ;; implementations for browser / web
browser.effects         ;; effectful impls for browser
node.impls              ;; Node.js environment
node.effects            ;; Node.js effects
wasm.impls              ;; WebAssembly (no direct OS access)
wasm.effects            ;; Wasm effects (limited)
ios.impls               ;; iOS-specific
ios.effects             ;; iOS effects (CoreLocation, CoreMotion, ...)
```

The file extension carries the platform tag. Build selects which
set to link.

---

## Example — clock

```aski
;; native.effects
@[Default Clock System [
  (now &self Time [Rfi:PosixTime:gettimeofday])
]]

;; browser.effects
@[Default Clock System [
  (now &self Time [Rfi:JsDate:now])
]]

;; wasm.effects (sandboxed)
@[Default Clock System [
  (now &self Time [Rfi:WasiClock:realtime])
]]
```

Same trait `Clock`, same target `System`, three different impls in
three platform surfaces. Build picks one.

---

## Example — file paths

```aski
;; native.impls
@[Default Path Native [
  (separator String [:Platform:isWindows.map("\\" "/")])
  (join &self &parts {Vec String} String [ ... ])
]]

;; browser.impls
@[Default Path Browser [
  (separator String ["/"])
  (join &self &parts {Vec String} String [ ... ])
]]
```

---

## Platform import model

A platform surface's impls are visible to the build only when that
platform is selected. Conceptually:

```
build --platform=native → links native.impls + native.effects
build --platform=browser → links browser.impls + browser.effects
```

Inside the program source, code references the traits normally:

```aski
;; time-display.impls
@[Default TimeDisplay App [
  (display ~&self String [
    (now System:now)                ;; System comes from the active platform
    now.toIso8601
  ])
]]
```

`System:now` dispatches via whichever `.effects` file the build
linked. Platform is transparent at call sites.

---

## Platform composition for multi-platform apps

A single program could target multiple platforms with platform-specific
overrides:

```aski
;; time-display.impls — cross-platform base
@[Default TimeDisplay App [
  (display ~&self String [ (now System:now) now.toIso8601 ])
]]

;; fancy-time-display.ios.impls — iOS-specific overlay
@[IosFancy TimeDisplay App [
  (display ~&self String [
    (now System:now)
    now.toRelative                  ;; iOS-only: "2 minutes ago"
  ])
]]
```

Build:
- `--platform=ios`: links native + ios; `IosFancy` overrides `Default`
  via coherence (iOS-specific impl is more specific in the iOS
  scope).
- `--platform=native` without iOS: uses `Default`.

---

## Capability systems emerge

A platform surface can declare **capabilities** via the traits it
implements. A browser surface might declare:

```aski
;; browser.impls provides:
;;   DOM            — document manipulation
;;   FetchApi       — HTTP via fetch
;;   LocalStorage   — key/value persistence
;;   EventLoop      — async tasks
```

A WASM surface might declare fewer:

```aski
;; wasm.impls provides:
;;   HostCall       — imported host functions
;;   Memory         — linear memory access
```

If a library requires a capability that the active platform surface
doesn't provide, the build errors. Capability is a first-class
build-level concept.

---

## How platform-specific types are handled

Platforms sometimes need their own types (e.g., browser has
`EventTarget`, `Element`, `Node`; native has `ProcessId`, `FileHandle`).

Option 1 — platform-specific `.types` surfaces (also extensible):

```
native.types            ;; native-only types (FileHandle, ProcessId)
browser.types           ;; browser-only types (EventTarget, Element)
```

Option 2 — opaque types in shared `.types`, platform impls fill them:

```aski
;; shared/handles.types
@(| FileHandle U64 |)   ;; opaque handle; meaning varies by platform
```

Each platform's impls interpret the handle appropriately.

Both patterns are valid. Option 2 keeps types portable at the cost
of platform-specific state hiding. Option 1 is more honest but forces
bifurcation.

---

## What this replaces

- **Rust's `#[cfg(target_os = "…")]`**: surface selection replaces
  build-level conditional compilation.
- **Elm's ports**: platform-surface linking replaces runtime JS
  interop (aski still uses RFI for Rust calls; platform surfaces
  wrap those in trait-conformant impls).
- **C preprocessor `#ifdef _WIN32`**: no preprocessor needed; source
  is platform-agnostic.

Same source, many platforms, verified at link time.

---

## Capability gating via trait requirements

A library can demand a capability:

```aski
;; pdf-export.impls
@[Default PdfExport App [
  (exportAll &self Pdf [
    ;; needs FileSystem capability (to write the pdf)
    ;; needs Canvas capability (to render)
    ...
  ])
]]
```

Its module header imports capability traits:
- `FileSystem` trait from `file.traits`
- `Canvas` trait from `graphics.traits`

The build ensures the active platform's `.effects` / `.impls` provide
an impl for these on the target type. If the platform lacks
`Canvas` (e.g., a headless server build), the build errors at the
capability layer — not at link time for a missing symbol, but at
the capability-declaration layer. Clear message.

---

## The big claim

**The build graph IS the capability system.** No runtime checks
for "does this device have GPU" — if the build succeeds, the
capabilities are there. If the program needs a capability that the
platform can't provide, the build fails. Clean separation of
development concerns.

Rust reaches for this with feature flags but doesn't enforce at the
capability level. Elm uses ports but can't verify statically. aski's
surface-selected impls do it structurally.

---

# Combining effects and platforms

The most powerful configuration: **platform-specific effects**.

```
shared.types            ;; portable types
shared.traits           ;; portable trait declarations
shared.impls            ;; portable pure behavior
native.effects          ;; native effect impls
browser.effects         ;; browser effect impls
```

The program consumes `shared.*` plus one platform's `.effects`.
Effect closure and platform selection are coordinated. Every
configuration is provable.

---

# What cannot happen

- A `.impls` file cannot secretly do I/O — grammar + veric prevent
  method bodies from calling into RFI or `.effects` functions.
- A `.effects` file cannot declare new types or new traits.
- A platform surface cannot "see" another platform's surface during
  a build — only the active platform's files contribute.

---

# The aesthetic payoff

Reading a project's top-level:
- `shapes.types` + `shapes.traits` + `shapes.impls` — the pure core
- `storage.effects` — the only impure piece
- `native.effects` / `browser.effects` — platform bindings
- `app.exec` — the entry point

You can **read the architecture from the filesystem**. No
conditional code, no feature flags, no runtime detection. Every
piece has a surface, and each surface has a purpose.

---

# Next

Derivation (replacing `#[derive]`) and test-impls (replacing
`cfg(test)`). [06-derivations-and-testing →](06-derivations-and-testing.md)
