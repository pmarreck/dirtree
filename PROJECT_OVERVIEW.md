# dirtree — Project Overview

## What it is

`dirtree` is a native **Zig 0.16** CLI that renders **stateful** directory trees
for both humans and LLM pair-programmers. Unlike `tree`/`eza`, it persists a
per-directory view — which subtrees are collapsed, which paths are hidden, how
deep to descend, per-path annotations — in a small `.dirtree-state` file, so the
same curated snapshot reproduces locally and for collaborators.

## Goals

- **Shared mental model.** Capture the "interesting" shape of a repo (close noisy
  dirs like `node_modules`, hide file types you rarely need) and reproduce it
  consistently for humans and AI tooling.
- **Two faces, one tree.** A decorated mode (Nerd Font icons, ANSI color, OSC8
  hyperlinks) and a glyph-free `--simple` mode that is LLM- and pipe-friendly.
- **Stateful, not stateless.** State lives in `.dirtree-state`, is inheritable
  down the directory chain, and is edited through the CLI (`open`/`close`/
  `show`/`hide`/`note`/`--depth`/…), never hand-tweaked as a chore.
- **Cross-platform.** One binary per the 5 supported OS/arch combos (macOS
  aarch64, Linux aarch64/x86_64-musl, Windows aarch64/x86_64).
- **i18n-first.** 50 locales (incl. 5 RTL), with compile-time enforcement that no
  user-facing string is missing (no silent English fallback).

## Architecture

Native Zig CLI — **no C FFI** (an explicit, deliberate deviation from the
fleet-wide "Zig core + C FFI + C CLI" pattern; recorded in `RULES.md`). Pure
rendering is separated from I/O where practical (the tree renderer is a function
of state + scanned entries).

| File | Purpose |
|------|---------|
| `src/main.zig` | Entry point, CLI arg parsing, orchestration |
| `src/state.zig` | `.dirtree-state` parse/serialize + the inheritance chain; `parseBool` |
| `src/path_eval.zig` | open/close/show/hide evaluation and precedence rules |
| `src/dir_scan.zig` | Directory listing, `stat`, sorting |
| `src/tree_render.zig` | Tree connectors, markers, recursive rendering, render defaults |
| `src/icons.zig` | Nerd Font icon map (`StaticStringMap`, extension + filename) |
| `src/ansi.zig` | ANSI color constants, OSC8 hyperlinks, percent-encoding |
| `src/scm.zig` | Git/jj SCM-changed priority paths |
| `src/pcre2.zig` | PCRE2 wrapper (compile/find/matches, DFA mode, UTF-8+UCP) |
| `src/regex.zig` | Glob→regex conversion, pattern-kind detection |
| `src/runtime.zig` | Zig 0.16 I/O threading bridge (process-global wrapper) |
| `src/update_check.zig` | Background "newer release available" check + cache |
| `src/i18n/` | 50 locale string tables + `mod.zig` registry, `strings.zig` schema, `cli_aliases.zig` |

## Terminology

- **State file** — `.dirtree-state`, INI-ish (`ver=`, `depth=`, `close=[ … ]`,
  `hide=[ … ]`, `annotate=[ … ]`, etc.). Sorted on write; unknown keys preserved
  as **passthrough**.
- **open / close** — whether a directory's children are rendered (closed dirs show
  a `*` marker). **show / hide** — whether a path appears at all.
- **Annotation / note** — a persisted one-line description of a path, rendered as a
  dim inline comment. An **empty** description is an intentional **tombstone** that
  suppresses an inherited parent note (it is not a bug).
- **Priority (SCM-kept) path** — a path that would be hidden but is kept because
  Git/jj reports it as changed; jj overrides Git.
- **Inheritance chain** — a child directory inherits the nearest ancestor's state
  unless it overrides it.

## Build & test

- `./build` — builds via `nix build` (sandboxed; avoids host-OS libSystem issues),
  copies to `zig-out/bin/dirtree`.
- `./run-tests` — Zig unit tests (`zig build test`) + Bash integration tests
  (`test/dirtree_test`) + build-tooling tests (`test/build_staleness_test`).
  **Named `run-tests`, not the canonical `./test`, on purpose:** the integration
  tests live in the `test/` **directory**, so a `./test` file would collide with
  it. `run-tests` is the single master runner.
- Garnix CI evaluates `packages.*` / `checks.*` from `flake.nix` across all 5
  targets on every push.
