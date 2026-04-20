{
  description = "aski — language spec, tree-sitter grammar, and editor modes for the aski text notation of sema";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        editor = import ./nix/editor.nix { inherit pkgs; };
      in {
        packages = {
          inherit (editor) tree-sitter-aski;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.tree-sitter
            pkgs.nodejs
          ];
        };
      });
}
