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

        # Pre-fetch PCRE2 Zig wrapper tarball (runs during Nix fetch phase, has network)
        pcre2-tarball = pkgs.fetchurl {
          url = "https://github.com/pmarreck/pcre2/archive/refs/tags/zig-0.15.2.tar.gz";
          hash = "sha256-2V5f3Ie1YVjblcqP9RAOANwodU6OrxV1ofbbcv3uvKY=";
        };

        # Unpack into the directory structure Zig expects for --system
        zigDeps = pkgs.runCommandLocal "zig-deps" {} ''
          hash="pcre2-10.47.0-S7QTbjnVMgAEncX1a_JtH4G6BgDWzC1tCMvL-KOMrM8b"
          mkdir -p "$out/$hash"
          tar xzf ${pcre2-tarball} --strip-components=1 -C "$out/$hash"
        '';
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
            zig build --system ${zigDeps} -Doptimize=ReleaseFast
          '';
          installPhase = ''
            mkdir -p $out/bin
            cp zig-out/bin/dirtree $out/bin/
          '';
        };
      });
}
