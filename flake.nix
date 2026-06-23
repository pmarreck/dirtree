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
        version = "1.0.0";

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
            # SCM-priority tests exercise real git and jj working copies.
            pkgs.git
            pkgs.jujutsu
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

        # The check Garnix was missing: it builds packages.default (compile only),
        # but nothing RAN the tests or EXECUTED the binary — so a passing build said
        # nothing about whether the code works or even runs (this is exactly how the
        # musl-loader "won't exec on NixOS" bug hid behind a green badge). This check
        # (1) runs the unit/integration suite and (2) smoke-execs the release binary.
        checks.test = pkgs.stdenv.mkDerivation {
          name = "${pname}-test";
          src = self;
          nativeBuildInputs = [ zig pkgs.git pkgs.jujutsu ]
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
            # identity for the real git/jj working copies the SCM-priority tests build
            git config --global user.name test
            git config --global user.email test@example.com
            git config --global init.defaultBranch main
            export JJ_USER=test JJ_EMAIL=test@example.com
            # 1) actually RUN the suite (the part that was never wired into CI)
            zig build test
            # 2) smoke-EXECUTE the release binary — catches runtime/loader regressions
            #    a compile-only gate can't (the musl-loader bug that started all this)
            zig build -Doptimize=ReleaseFast
            ./zig-out/bin/dirtree --about >/dev/null
          '';
          installPhase = ''
            mkdir -p $out
            echo "tests passed and binary executes" > $out/result
          '';
          dontFixup = true;
        };
      });
}
