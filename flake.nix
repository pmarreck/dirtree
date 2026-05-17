{
  description = "dirtree - Stateful directory trees for humans and LLMs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, zig-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        zig = zig-overlay.packages.${system}."0.16.0";
        isDarwin = pkgs.stdenv.isDarwin;
        pname = "dirtree";
        version = "0.1.0";

        zigDepsHash = "sha256-CZYaUzlhZdEIT0Wep+Pw7yvyDcfJMsrgJUMZJIS0OBo=";

        zigDeps = pkgs.stdenv.mkDerivation {
          pname = "${pname}-zig-deps";
          inherit version;
          src = self;
          nativeBuildInputs = [ zig pkgs.git pkgs.cacert ]
            ++ pkgs.lib.optionals isDarwin [
              pkgs.darwin.cctools
              pkgs.apple-sdk
            ];
          outputHashMode = "recursive";
          outputHashAlgo = "sha256";
          outputHash = zigDepsHash;
          buildPhase = ''
            export HOME=$TMPDIR
            export ZIG_GLOBAL_CACHE_DIR=$out
            export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
            export GIT_SSL_CAINFO=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
            zig build --fetch=all
          '';
          dontInstall = true;
          dontFixup = true;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            zig
          ];
        };

        packages.default = pkgs.stdenv.mkDerivation {
          inherit pname version;
          src = self;
          nativeBuildInputs = [ zig ]
            ++ pkgs.lib.optionals isDarwin [
              pkgs.darwin.cctools
              pkgs.apple-sdk
            ];
          dontConfigure = true;
          buildPhase = ''
            export HOME="$TMPDIR"
            export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache
            mkdir -p $ZIG_GLOBAL_CACHE_DIR
            cp -r ${zigDeps}/* $ZIG_GLOBAL_CACHE_DIR/
            chmod -R u+w $ZIG_GLOBAL_CACHE_DIR
            zig build --prefix $out -Doptimize=ReleaseFast
          '';
          dontInstall = true;
          dontFixup = true;
        };
      });
}
