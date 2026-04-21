# RFI and exec

## RFI — Rust foreign interfaces

Rust foreign interfaces live in `.rfi` files, one group per file. The filename is the group name.

```
FileSystem.rfi
```

```aski
(readToString &path Path {Result String Error})
(writeString &path Path &content String {Result Unit Error})
(exists &path Path Bool)
(remove &path Path {Result Unit Error})
```

```rust
extern "Rust" {
    fn read_to_string(path: &Path) -> Result<String, Error>;
    fn write_string(path: &Path, content: &str) -> Result<(), Error>;
    fn exists(path: &Path) -> bool;
    fn remove(path: &Path) -> Result<(), Error>;
}
```

Each entry is a signature. An `.rfi` group is callable as `Rfi:GroupName:funcName(args)` from inside `.effect` files (not `.impl` — a pure impl cannot call RFI).

```
Lexer.rfi
```

```aski
(lex &source String {Vec Token})
(tokenize &source String {Vec Token})
```

## Exec — entry-point programs

An `.exec` file IS an executable program. The filename is the program's name (the binary target). Content is a program body — a sequence of statements followed by an optional tail expression.

```
Hello.exec
```

```aski
(element Element:Fire)
[StdOut:print(element.describe)]
```

```rust
fn main() {
    let element = Element::Fire;
    println!("{}", element.describe());
}
```

No module header. No name declaration. The filename `Hello.exec` becomes the executable name.

### Larger exec

```
Parser.exec
```

```aski
(args Args:fromProcess)
(source Rfi:FileSystem:readToString(args.first)?)
(lexer Lexer:new(source))
(tokens lexer.tokenize)
(parser Parser:new(tokens))
(ast parser.parse?)
[StdOut:print(ast.debug)]
```

### Effect closure

`Rfi:FileSystem:readToString` is effectful, so a `FileReader.effect` must be linked. If the build links `FileReader~LocalFs.effect`, the program reads from the local filesystem. For tests, swap in `FileReader~Memory.test-impl`.
