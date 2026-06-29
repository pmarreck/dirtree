# dirtree — Audit Remediation Plan

Source: 10-dimension subagent audit (2026-06-18). All items approved by Peter, in this order.
Discipline: **TDD** (failing test → minimal fix → green → refactor), **commit per green unit**, every commit a known-good state. Build/test via `./build` and `./run-tests` (nix-sandboxed).

Grades: 🔥 behavioral/correctness · ‼️ important · ⚠️ advisory.

---

## Phase 1 — Behavioral bugs + the coverage that would have caught them

- [x] **1.1 — NOT A BUG (audit #1 false positive)** `annotate PATH ""` (`main.zig` `persistAnnotation` ~:2272). Help says "empty DESC clears"; impl removes then re-adds an empty tombstone (`\tpath = \n`). Fix: when `description.len==0`, remove and skip re-add. *Failing CLI test first*: after `annotate p ""`, the `annotate=[` block / that path is absent.
- [x] **1.2 — RESOLVED by removing `--head`/`--tail`** (compose into a middle window, not "later wins"; duplicate unix head/tail). See Done log.
- [x] **1.3 ‼️ Icon map exhaustive test** (`icons.zig:55-176`, 82 mappings, ~4 tested). Table-driven Zig test over EVERY extension alias + EVERY special filename + a negative set (unknown→`file_icon`). Classifier-over-set.
- [x] **1.4 ‼️ CLI alias resolution test** (`i18n/mod.zig`). `inline for (all_locales)` → for each `aliases.cli` entry assert `matchLongFlag(name).? == arg`; same for env-var alias map. Assert each `CliArg` reachable per locale (or document gaps).
- [x] **1.5 ‼️ Locale "not just English" distinctness test.** Assert a sentinel set of **non-Latin-script** locales (`ja ar ru zh_hans ko el he th`) differ from English on a visible field (e.g. `help_title`). *NOTE (Peter): do NOT use Germanic Latin-script locales (de/nl) — loanwords can legitimately equal English and would false-fail.* (Missing fields already hard-fail to compile since defaults were removed.)
- [x] **1.6 ‼️ `parseLocaleCode` round-trip over the full set** (`mod.zig:401`). `inline for (all_locales) |loc| expectEqual(loc, parseLocaleCode(loc.code()).?)`; plus `code()++"_XX"` and `code()++".UTF-8"` still resolve.
- [x] **1.7 ‼️ path_eval same-type precedence tests** (`path_eval.zig:155`). As a set: open-lit+close-lit→closed; open-rgx+close-rgx→closed; show-lit+hide-lit→hidden; show-rgx+hide-rgx→hidden; hide-matched ∧ priority_files → `scm_kept==true`.

## Phase 2 — Safe locale-dedup slice (fix-pattern already proven via `available_codes`)

- [x] **2.1 ⚠️ `Locale.code()` → `@tagName(self)`** (delete the 50-arm switch; enum names == codes). Handle `tr`/`tr_locale` import-name collision.
- [x] **2.2 ⚠️ Derive `cli_alias_map` `locale_aliases` array (and env array) from `all_locales`** at comptime instead of hand-listing. (Removes 2 of 6 sync points. `stringsFor`/`localeCliAliases` switches = bold, deferred to 4.4.)

## Phase 3 — Hygiene (small, mostly file-isolated → some parallelizable)

- [ ] **3.1 ⚠️ ANSI constants**: replace 7 hardcoded escapes in `main.zig` with `ansi.*`; add `ansi.bold_yellow`.
- [ ] **3.2 ⚠️ Named constants** for magic numbers: `DEFAULT_DEPTH=4`, `DEFAULT_NOTE_COLUMN=40`, `DEFAULT_MAX_LINES=500` (co-locate with `RenderConfig`).
- [ ] **3.3 ⚠️ Unify truthy parsing**: one `parseBool(s) ?bool` (StaticStringMap, case-insensitive). Fixes `state.zig` rejecting `"TRUE"` while `main.zig` accepts it.
- [ ] **3.4 ⚠️ `flake_staleness.sh`**: add `FLAKE_LOCK_NOW` override (epoch only). *NOTE (Peter): `date` may be GNU or BSD — keep math in `date +%s` epoch (portable); guard/detect `gdate` if a formatted date is ever needed.* Port `python3` JSON parse → `jq` or pure bash (no-Python stance).
- [ ] **3.5 ⚠️ `tree_render.zig`**: move `visible` cleanup `defer` ABOVE the accumulation loop (2 sites) — OOM-path hardening (arena currently masks).
- [ ] **3.6 ⚠️ SCM jj-failure → git fallback**: `scm.zig:158` conflates "jj repo present" with "jj succeeded"; only short-circuit git when jj actually produced output.
- [ ] **3.7 ⚠️ PCRE2 workspace-grow OOM**: propagate a real error instead of silent "no match" (`pcre2.zig:122`, swallowed in `path_eval.zig`).
- [ ] **3.8 ⚠️ `update_check` cachePath Windows fallback**: `LOCALAPPDATA`/`USERPROFILE` before erroring.
- [ ] **3.9 ⚠️ Numeric boundary tests**: `-d 0` (root-only), `-d` overflow message, and 0/neg/overflow for `--max-lines`.
- [ ] **3.10 ⚠️ glob char-class edge tests** (`regex.zig`): `[!a-z]`, `[]abc]`, unterminated `[abc`→literal fallback, bare `**`, escaped `a\*b`; `isGlobPattern` as a set classifier.
- [ ] **3.11 ⚠️ state round-trip test**: actually re-parse `output` and compare structurally (current test only substring-greps).
- [ ] **3.12 ⚠️ Strengthen weak tests**: `root-points-to-repo-root` assert basename; `scanDir` assert `build.zig` present; drop/rewrite the `available_codes` `"en"` substring test (redundant with the sorted+complete test).
- [ ] **3.13 ⚠️ Docs/notes**: fix stale `MEMORY.md` ("22 locales" → 50); add `dirtree note` for every source file (dogfood annotate); create `PROJECT_OVERVIEW.md` + `RULES.md`; note `run-tests` vs `./test` convention.
- [ ] **3.14 ⚠️ `icons.zig` → `std.StaticStringMap`** (AFTER 1.3 test is green — refactor under coverage). File-isolated → good worktree-subagent candidate.

## Phase 4 — Bigger refactors (each scoped; offer safe vs bold)

- [ ] **4.1 ‼️ `parseArgs` table-drive**: comptime descriptor table for toggle flags; map short→`CliArg` pre-switch (dedup `-d/-o/-c/-p` vs long arms — the `-d2`/`-td2` bug seam); collapse 50 `config.deinit` via `errdefer`.
- [ ] **4.2 ‼️ `main()` `.config` arm**: extract `runTree()` + the 3 inline warning blocks; move precedence resolution (`cfg.X orelse effective.X orelse DEFAULT`) into a pure `resolveRenderConfig` in `path_eval` (unit-testable). Hexagonal compliance.
- [ ] **4.3 ‼️ `tree_render.zig`**: extract shared `collectVisible()` first pass (`renderDir`/`renderDirFocused` ~75 dup lines; divergence risk).
- [ ] **4.4 ⚠️ i18n bold**: single comptime registry → collapse `stringsFor`/`localeCliAliases` switches (the last 2 of the 6 hand-maintained lists).
- [ ] **4.5 ⚠️ Collapse 2–3 tree walks into 1**: buffer rendered rows; derive note-alignment gutter + line-count estimate from the buffer (the `--tail` path already shows the technique). I/O win on large/cold trees.
- [ ] **4.6 ⚠️ `state.zig` `std.meta.stringToEnum`** for key/value dispatch (replaces `else if eql` chains; exhaustive).
- [ ] **4.7 ⚠️ `ansi.zig writeStatsMessage`**: extract `count(writer,n,sing,plur)` helper (4× dup).

---

## Done log
- 2026-06-29 (eacde65d): **1.3–1.7** exhaustive coverage tests landed; the icon test caught + fixed a real **icon-precedence bug** (Cargo.toml/package.json/*.lock showed wrong icons). i18n alias-resolution / distinctness / round-trip + path-eval precedence coverage all green.
- 2026-06-29: **1.1 — false positive.** Empty annotation is an intentional *tombstone* to suppress an inherited parent-dir note (existing `test_annotate_empty_clears_local_entry` asserts it); "clears" = clears the *displayed* note. No change.
- 2026-06-29: **1.2 — resolved by removal.** `--head`/`--tail` compose into a middle window (not "later wins"); they duplicate unix `head`/`tail` (the help even said "prefer piping to tail -N"). **Removed entirely** — 2 CliArgs, parse arms, the tail-buffer render path + `head_reached` threading + `BufListWriter`, 6 Strings fields × 50 locales, localized aliases, and the old tests; added a rejection test. Pure subtraction.
- 2026-06-29: **Phase 2** done. `Locale.code()` is now just `@tagName(self)` (deleted the 50-arm switch); the `cli_alias_map` hand-list is derived from `all_locales` via `localeCliAliases`. Removed 2 of the 6 hand-maintained 50-entry lists (registry pattern, as `available_codes` already proved). Validated by the 1734-assertion alias-resolution test + parseLocaleCode round-trip.
