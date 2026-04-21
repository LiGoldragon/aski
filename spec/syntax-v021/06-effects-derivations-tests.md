# Effects, derivations, tests, benches

## Effects

Effect impls live in `[_]TraitPart~TargetPart.effect` files. Filename and content grammar are identical to [`.impl`](05-impls.md).

**The only semantic difference:** an impl in a `.effect` file is allowed to cross the I/O boundary (read files, call RFI, touch external state). A file in `.impl` cannot. `veric` enforces.

A library that never imports a `.effect` file (transitively) is provably pure — its effect closure is empty.

### FileReader effect

```
FileReader~LocalFs.effect
```

```aski
(readAll &self &path Path {Result String Error} [
  Rfi:FileSystem:readToString(path)
])
```

```rust
impl FileReader for LocalFs {
    fn read_all(&self, path: &Path) -> Result<String, Error> {
        std::fs::read_to_string(path)
    }
}
```

`Rfi:FileSystem:readToString` is a call into the RFI surface (see [13-rfi-exec](13-rfi-exec.md)). Anyone who transitively depends on `FileReader~LocalFs.effect` has `FileSystem` in their effect closure.

### Clock effect

```
Clock~Utc.effect
```

```aski
(now &self Time [
  Rfi:Time:systemNowUtc
])
```

### Composite effect (delegates to other effects)

```
Logger~Multi.effect
```

```aski
(log ~&self &message String [
  [~Stderr:write(message)]
  [~LogFile:append(message)]
])
```

### Platform-scoped effects

The `.<platform>.effect` middle segment carries the build tag. Build selection links the matching platform file.

```
Clock~System.native.effect
Clock~System.browser.effect
Clock~System.wasm.effect
```

```aski
# Clock~System.native.effect
(now &self Time [ Rfi:PosixTime:gettimeofday ])
```

```aski
# Clock~System.browser.effect
(now &self Time [ Rfi:JsDate:now ])
```

```aski
# Clock~System.wasm.effect
(now &self Time [ Rfi:WasiClock:realtime ])
```

## Derivations

Derivations live in `[_]Name.derivation` files.

**Content grammar:** `:TraitName <TypePattern> *<TraitImplItem>`.

A derivation is a rule: *"for every type matching this pattern, synthesize this impl."* `veric` applies the rule at link time, producing synthetic `.impl` equivalents for each matching type. Hand-written `.impl` files for a given (Trait, Target) always win (most-specific wins).

### Debug for any struct whose fields all impl Debug

```
DebugStruct.derivation
```

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

`StructOf` / `AllFields` are pattern-matchers on type shape, provided by the derivation stdlib.

### Clone for any enum

```
CloneEnum.derivation
```

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

### JSON serialize for structs

```
JsonSerializeStruct.derivation
```

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

## Test impls

Test impls live in `[_]TraitPart~TargetPart.test-impl` files. Filename and content grammar identical to `.impl`. Linked only into test builds; replaces production impls for the same (Trait, Target) pair during test runs.

```
Storage~Database.test-impl
```

```aski
(read &self &key String {Option String} [
  Option:Some("mocked-value")
])
(write ~&self &key String &value String [
  Unit
])
```

No conditional compilation in production source — the test impl is a separate file wired in by the test build.

## Bench impls

`.bench-impl` follows the same pattern as `.test-impl`, linked only into benchmark builds.
