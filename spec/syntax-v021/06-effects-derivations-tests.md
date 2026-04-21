## EFFECTS — Trait[Args]~Target.effect files

Filename grammar: same as .impl but with `.effect` extension.
Content grammar: identical to .impl.

The ONLY semantic difference: an impl in a `.effect` file
is allowed to cross the I/O boundary (read files, call RFI,
touch external state). A file in `.impl` cannot. veric
enforces.

A library that never imports a `.effect` file (transitively)
is provably pure — its effect closure is empty.

FileReader effect ------------------------------------------

Filesystem path:
  FileReader~LocalFs.effect

File content:

```aski
(readAll &self &path Path {Result String Error} [
  Rfi:FileSystem:readToString(path)
])

```
Rust equivalent:
  impl FileReader for LocalFs {
      fn read_all(&self, path: &Path) -> Result<String, Error> {
          std::fs::read_to_string(path)
      }
  }

`Rfi:FileSystem:readToString` is a call into the RFI surface
(see `.rfi` files below). The effect is tracked: anyone who
transitively depends on `FileReader~LocalFs.effect` has
`FileSystem` in their effect closure.

Clock effect -----------------------------------------------

Filesystem path:
  Clock~Utc.effect

File content:

```aski
(now &self Time [
  Rfi:Time:systemNowUtc
])

```
Rust equivalent:
  impl Clock for Utc { fn now(&self) -> Time { ... } }

Logger effect (composite — delegates to other effects) ----

Filesystem path:
  Logger~Multi.effect

File content:

```aski
(log ~&self &message String [
  [~Stderr:write(message)]
  [~LogFile:append(message)]
])

```
Rust equivalent:
  impl Logger for Multi {
      fn log(&mut self, message: &str) {
          stderr().write(message);
          log_file().append(message);
      }
  }

Platform-scoped effect (capability system) -----------------

Filesystem path:
  Clock~System.native.effect
  Clock~System.browser.effect
  Clock~System.wasm.effect

Content of Clock~System.native.effect:

```aski
(now &self Time [ Rfi:PosixTime:gettimeofday ])

```
Content of Clock~System.browser.effect:

```aski
(now &self Time [ Rfi:JsDate:now ])

```
Content of Clock~System.wasm.effect:

```aski
(now &self Time [ Rfi:WasiClock:realtime ])

```
The `<platform>` segment between the stem and extension
carries the build tag. Build selection chooses which set
of platform-tagged effects to link. Prior per-concern
effects-and-platforms proposal was retired 2026-04-21; see
`decomposition.md` for the II-L derivation that subsumed it.

## DERIVATIONS — Name.derivation files

Filename grammar:
  [_]DerivationName.derivation

Content grammar:
  :TraitName <TypePattern> *<TraitImplItem>

A derivation is a rule: "for every type matching this pattern,
synthesize this impl." veric applies the rule at link time,
producing synthetic `.impl` equivalents for each matching type.
Hand-written `.impl` files for a given (Trait, Target) always
win over derivation output (most-specific wins).

Debug derivation for any struct whose fields all impl Debug

Filesystem path:
  DebugStruct.derivation

File content:

```aski
:Debug {StructOf {$Struct} {AllFields Debug}}
(debug &self String [
  (out :StructName:asString)
  [~out.append(" { ")]
  {| self.Struct.field
    [~out.append(field.name)]
    [~out.append(": ")]
    [~out.append(field.value.debug)]
    [~out.append(" ")]
  |}
  [~out.append("}")]
  out
])

```
Rust equivalent:
  // #[derive(Debug)] on any struct
  impl Debug for <any struct whose fields all impl Debug> {
      fn debug(&self) -> String { ... }
  }

`StructOf` / `AllFields` are pattern-matchers on type shape,
provided by the derivation stdlib. (Earlier per-concern
derivations-and-testing proposal was retired 2026-04-21; the
full pattern language remains to be specified within v0.21.)

Clone derivation for enums ---------------------------------

Filesystem path:
  CloneEnum.derivation

File content:

```aski
:Clone {EnumOf {$Enum} {AllVariants Clone}}
(clone &self Self [
  (| self
    {| :EnumType.variant
      ( :variant :fields ) :variant(:fields.map(field.clone))
    |}
  |)
])

```
JSON serialization derivation for structs ------------------

Filesystem path:
  JsonSerializeStruct.derivation

File content:

```aski
:JsonSerialize {StructOf {$Struct} {AllFields JsonSerialize}}
(toJson &self Json [
  (obj Json:Object:empty)
  {| self.Struct.field
    [~obj.insert(field.name field.value.toJson)]
  |}
  Json:Object(obj)
])

```

## TEST-IMPLS — Trait[Args]~Target.test-impl files

Filename grammar: same as `.impl` with `.test-impl` extension.
Content grammar: identical to `.impl`.

Only linked into test builds. Replaces production impls for
the same (Trait, Target) pair during test runs.

Filesystem path:
  Storage~Database.test-impl

File content:

```aski
(read &self &key String {Option String} [
  Option:Some("mocked-value")
])
(write ~&self &key String &value String [
  Unit
])

```
Rust equivalent: what you'd write in a `#[cfg(test)]` mod
with a mock Database. aski's version is a separate file,
linked by the test build. No conditional compilation in
production source.

Bench-impls follow the same pattern with `.bench-impl`.
