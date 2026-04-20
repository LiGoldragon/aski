# Tree-sitter grammars and Emacs modes for aski.

{ pkgs }:

{
  # Tree-sitter grammar (native .so)
  tree-sitter-aski = pkgs.stdenv.mkDerivation {
    pname = "tree-sitter-aski";
    version = "0.1.0";
    src = ../tree-sitter-aski;
    nativeBuildInputs = [ pkgs.tree-sitter pkgs.nodejs ];
    buildPhase = ''
      tree-sitter generate
      cc -shared -fPIC -o libtree-sitter-aski.so src/parser.c -I src
    '';
    installPhase = ''
      mkdir -p $out/lib $out/queries $out/grammar
      cp libtree-sitter-aski.so $out/lib/
      cp -r queries/* $out/queries/
      cp grammar.js $out/grammar/
      cp src/parser.c $out/grammar/
      cp src/tree_sitter/parser.h $out/grammar/ 2>/dev/null || true
    '';
  };

  # Tree-sitter grammar (WASM — for VSCode/web-tree-sitter)
  tree-sitter-aski-wasm = pkgs.stdenv.mkDerivation {
    pname = "tree-sitter-aski-wasm";
    version = "0.1.0";
    src = ../tree-sitter-aski;
    nativeBuildInputs = [
      pkgs.tree-sitter
      pkgs.pkgsCross.wasi32.stdenv.cc
      pkgs.binaryen
      pkgs.nodejs
    ];
    buildPhase = ''
      export HOME=$TMPDIR
      export NIX_LDFLAGS=""
      tree-sitter generate

      wasm32-unknown-wasi-cc \
        -shared -fPIC -Os \
        -o tree-sitter-aski.wasm \
        -Wl,--export=tree_sitter_aski \
        -Wl,--allow-undefined \
        -Wl,--no-entry \
        -nostdlib -fno-exceptions -fvisibility=hidden \
        -I src \
        src/parser.c

      wasm-opt tree-sitter-aski.wasm -Os -o tree-sitter-aski.wasm
    '';
    installPhase = ''
      mkdir -p $out
      cp tree-sitter-aski.wasm $out/
      cp -r queries $out/
    '';
  };

  # Emacs packages
  aski-mode = pkgs.emacsPackages.trivialBuild {
    pname = "aski-mode";
    version = "0.1.0";
    src = ../aski-mode.el;
  };

  aski-ts-mode = pkgs.emacsPackages.trivialBuild {
    pname = "aski-ts-mode";
    version = "0.1.0";
    src = ../aski-ts-mode.el;
  };
}
