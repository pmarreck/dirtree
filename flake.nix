{
  description = "dirtree - Stateful directory trees for humans and LLMs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.zig
          ];
        };

        packages.default = pkgs.stdenv.mkDerivation {
          pname = "dirtree";
          version = "0.1.0";
          src = ./.;
          nativeBuildInputs = [ pkgs.zig ];
          dontConfigure = true;
          buildPhase = ''
            export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d)
            zig build -Doptimize=ReleaseFast
          '';
          installPhase = ''
            mkdir -p $out/bin
            cp zig-out/bin/dirtree $out/bin/
          '';
        };
      });
}
