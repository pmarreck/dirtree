# dirtree — Audit Remediation Plan

Source: 10-dimension subagent audit (2026-06-18). All items approved by Peter, in this order.
Discipline: **TDD** (failing test → minimal fix → green → refactor), **commit per green unit**, every commit a known-good state. Build/test via `./build` and `./run-tests` (nix-sandboxed).

Grades: 🔥 behavioral/correctness · ‼️ important · ⚠️ advisory.

---

## Phase 6 — i18n locale-selection bug + skill alignment (2026-07-19/20)

Trigger: inbox note `inbox/2026-07-19-note-help-uses-urdu.md` — `dirtree note --help`
emitted an **Urdu** error under an English environment.

- [x] **6.1 🔥 Urdu locale-hijack fix + MFIC disjointness classifier** — five non-English
  locale tables carried a verbatim English canonical CLI token (`ur:note es:--color
  hi:--path nb/da:--test`); `detectLocaleFromAliases` skips English but returns the first
  non-English locale whose alias matches an arg, so a plain English word switched the UI
  into that language. Removed the strays; added Test D (set-classifier: non-en alias sets
  disjoint from English) + Test E (behavioral). Commit `9b67000`. _(2026-07-19)_
- [x] **6.2 🔥 env locale precedence** — `detectLocaleFromEnv` ignored `DIRTREE_LANG` and
  `LC_ALL`. Extracted pure `pickLocaleFromEnvValues`; precedence `DIRTREE_LANG > LC_ALL >
  LC_MESSAGES > LANG`, POSIX set-wins (C/POSIX ⇒ English). Commit `470408c`. _(2026-07-19)_
- [x] **6.3 🔥 `-h/--help` around subcommands** — `note --help` hit annotate dispatch and
  errored; verb only recognized as `args[0]`. Help now short-circuits: bare help ⇒ global
  help (any position); help + a verb ⇒ pointed **untranslated placeholder** "Subcommand
  help not yet supported" (removed when Variant A lands); verb recognized as first operand
  after an optional leading `--lang`. Commit `8ac0fea`. _(2026-07-19)_
- [x] **6.4 G1 — GNU `LANGUAGE`** honored (colon-list) with its C-locale exception, ahead
  of the POSIX categories. Commit `f5d7ba0`. _(2026-07-20)_
- [x] **6.5 G2 — RTL bidi shadow** — pure `isRtl` + `bidiWrapShadow` LRM-brackets the
  `(en: …)` LTR shadow at emit time (was hand-baked only in help, never in error strings;
  `ar` had none). Commit `bed3dd9`. _(2026-07-20)_
- [x] i18n **skill** updated: added testing requirement **#7 Alias-inference disjointness**
  (`~/.claude/skills/i18n/SKILL.md`). Corrected stale 22→50 locale auto-memory.

### Phase 6 — REMAINING (each its own commit; TDD)
- [x] **6.6 Variant A — per-subcommand help (fully translated ×50)** _(2026-07-21)_.
  Canonical-tag design shipped: one `Strings.help_subcommands` corpus per locale holding
  three line-anchored sections `<annotate>`/`<orphaned_notes>`/`<purge_orphaned_notes>`
  (tags = CliArg `@tagName`, never translated). `i18n.extractSubcommandHelp` slices by
  topic; `main.zig` maps the (possibly localized) verb → `CliArg` via `subcommandVerb`,
  returns `ParseResult.help_subcommand`, and `printSubcommandHelp` prints the sliced body.
  Global help stays lean (Peter's choice) — one-liners under Options, detail via
  `<verb> --help`; the placeholder from 6.3 is deleted. **MFIC Test F** sweeps every topic ×
  every locale: exactly-one line-anchored pair, non-empty sliceable body, no residual
  markers, **and command tokens (`dirtree annotate`, `.dirtree-state`, …) verbatim**; plus a
  "global help carries zero topic tags" guard and 4 bash CLI tests. Translations produced by
  10 parallel Opus agents grouped by family, each **grounded in that locale's own existing
  in-file terminology**; structurally verified + spot-checked. **Independent back-translation
  check (2026-07-21):** a LOCAL model (gemma4:12b / qwen3:8b via ollama — MFIC maker≠checker,
  saves cloud tokens) back-translated the flagged mid-resource set — `am bg mk ro is az ta pa
  ko` all preserve meaning (ha reads fine once you know Hausa "share"=erase, a gemma
  false-friend). So those flags were over-cautious; they're GOOD. **Genuinely needs native
  review (no available tool can faithfully do them — gemma mangles Yoruba, proven):** `yo ig
  ps km`. Verified via `zig build test` + `test/dirtree_test`.
- [ ] **6.7 G3 — platform locale adapters** — macOS `CFLocaleCopyPreferredLanguages`,
  Windows `GetUserPreferredUILanguages`, as a fallback when the Unix env gives no signal.
  Unit-test the pure selection logic; the actual platform calls are only exercisable on the
  mac/Windows CI runners (can't integration-test on Linux).
- [x] **6.8 known-bug fix: note-alignment tests were Python-dependent** _(2026-07-21)_. The 4
  note-alignment tests (`notes align to a common gutter`, `--notes inline is not aligned`,
  `notes min-margin for long names`, `note_column cap read from state`) shelled out to
  `python3`, which isn't installed (fleet no-Python stance — `build_staleness_test` even
  enforces it). Rewrote their column checks in `LC_ALL=C.UTF-8 gawk` (code-point-accurate,
  matches Python's `str.index`). The note-alignment feature itself was always correct. Full
  suite now 196/196 + all unit tests green.
- [ ] (noted, not scoped — **broader than first thought**) the **annotate error strings are
  untranslated English across many locales**, not just `ar/he/fa`: `err_annotate_requires_description`
  is English in `de/fr/ar/he/fa` (at least). A future pass should translate the annotate
  error family (with the bilingual-error format per the i18n skill).
- [x] **6.9 `help_opt_annotate` backfill — 20 of 21 locales** _(2026-07-21)_. Translated the
  one-line Options entry (was English) via the LOCAL model (gemma4:12b / qwen3:8b, token
  savings) grounded in each locale's validated 6.6 `<annotate>` phrasing, **every line
  reviewed** — the model made semantic errors even in high-resource langs (ro: "empty DESC
  *saves*" ✗→ fixed to "clears"; hu nonword "egyrésztű"→"egysoros"; ko/qwen returned the
  *orphaned-notes* text ✗; ja "一ライン"✗; uk drifted "коментар"→"нотатка"), all corrected
  from the 6.6 oracle. Lesson: local model saves cloud tokens but its output MUST be
  line-reviewed. **`km` deferred** — its file is corrupted (see below); left English + flagged.
- [ ] (noted, not scoped — surfaced during 6.6) **`km.zig` has pre-existing corruption**: its
  `help_examples_header` is `ដំបូង:` ("first/beginning", not "Examples"), its directory/file
  terms look non-standard vs. `ថត`/`ឯកសារ`, and `help_example_1` contains a replacement-char
  glitch. The 6.6 Khmer translation reused these for internal consistency but they are likely
  wrong fleet-wide — needs a native Khmer pass.
- [ ] (noted — cross-project, from `fsearch` inbox 2026-07-10, processed 2026-07-23) **dirtree
  is the source-of-truth for the shared glob→PCRE2 grammar** that fsearch is adopting for its
  `glob:` modifier: `*` `**/` `?`, char classes + ranges `[a-c]`, brace alternatives
  `{png,jpg}`, inclusive zero-padded numeric ranges `{01..12}`, and `\` escaping. Any future
  change to dirtree's glob grammar must keep deterministic tests green **and coordinate with
  fsearch** so behavior stays matched. (dirtree already has glob tests in `test/dirtree_test`.)

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

- [x] **3.1 ⚠️ ANSI constants**: replace 7 hardcoded escapes in `main.zig` with `ansi.*`; add `ansi.bold_yellow`.
- [x] **3.2 ⚠️ Named constants** for magic numbers: `DEFAULT_DEPTH=4`, `DEFAULT_NOTE_COLUMN=40`, `DEFAULT_MAX_LINES=500` (co-locate with `RenderConfig`).
- [x] **3.3 ⚠️ Unify truthy parsing**: one `parseBool(s) ?bool` (StaticStringMap, case-insensitive). Fixes `state.zig` rejecting `"TRUE"` while `main.zig` accepts it.
- [x] **3.4 ⚠️ `flake_staleness.sh`**: add `FLAKE_LOCK_NOW` override (epoch only). *NOTE (Peter): `date` may be GNU or BSD — keep math in `date +%s` epoch (portable); guard/detect `gdate` if a formatted date is ever needed.* Port `python3` JSON parse → `jq` or pure bash (no-Python stance).
- [x] **3.5 ⚠️ `tree_render.zig`**: move `visible` cleanup `defer` ABOVE the accumulation loop (2 sites) — OOM-path hardening (arena currently masks).
- [x] **3.6 ⚠️ SCM jj-failure → git fallback**: `scm.zig:158` conflates "jj repo present" with "jj succeeded"; only short-circuit git when jj actually produced output.
- [x] **3.7 ⚠️ PCRE2 workspace-grow OOM**: propagate a real error instead of silent "no match" (`pcre2.zig:122`, swallowed in `path_eval.zig`).
- [x] **3.8 ⚠️ `update_check` cachePath Windows fallback**: `LOCALAPPDATA`/`USERPROFILE` before erroring.
- [x] **3.9 ⚠️ Numeric boundary tests**: `-d 0` (root-only), `-d` overflow message, and 0/neg/overflow for `--max-lines`.
- [x] **3.10 ⚠️ glob char-class edge tests** (`regex.zig`): `[!a-z]`, `[]abc]`, unterminated `[abc`→literal fallback, bare `**`, escaped `a\*b`; `isGlobPattern` as a set classifier.
- [x] **3.11 ⚠️ state round-trip test**: actually re-parse `output` and compare structurally (current test only substring-greps).
- [x] **3.12 ⚠️ Strengthen weak tests**: `root-points-to-repo-root` assert basename; `scanDir` assert `build.zig` present; drop/rewrite the `available_codes` `"en"` substring test (redundant with the sorted+complete test).
- [x] **3.13 ⚠️ Docs/notes**: fix stale `MEMORY.md` ("22 locales" → 50); add `dirtree note` for every source file (dogfood annotate); create `PROJECT_OVERVIEW.md` + `RULES.md`; note `run-tests` vs `./test` convention.
- [x] **3.14 ⚠️ `icons.zig` → `std.StaticStringMap`** (AFTER 1.3 test is green — refactor under coverage). File-isolated → good worktree-subagent candidate.

## Phase 4 — Bigger refactors (each scoped; offer safe vs bold)

- [x] **4.1 ‼️ `parseArgs` table-drive**: comptime descriptor table for toggle flags; map short→`CliArg` pre-switch (dedup `-d/-o/-c/-p` vs long arms — the `-d2`/`-td2` bug seam); collapse 50 `config.deinit` via `errdefer`.
- [x] **4.2 ‼️ `main()` `.config` arm**: extract `runTree()` + the 3 inline warning blocks; move precedence resolution (`cfg.X orelse effective.X orelse DEFAULT`) into a pure `resolveRenderConfig` in `path_eval` (unit-testable). Hexagonal compliance.
- [x] **4.3 ‼️ `tree_render.zig`**: extract shared `collectVisible()` first pass (`renderDir`/`renderDirFocused` ~75 dup lines; divergence risk).
- [x] **4.4 ⚠️ i18n bold**: single comptime registry → collapse `stringsFor`/`localeCliAliases` switches (the last 2 of the 6 hand-maintained lists).
- [x] **4.5 ⚠️ Collapse 2–3 tree walks into 1**: buffer rendered rows; derive note-alignment gutter + line-count estimate from the buffer (the `--tail` path already shows the technique). I/O win on large/cold trees.
- [x] **4.6 ⚠️ `state.zig` `std.meta.stringToEnum`** for key/value dispatch (replaces `else if eql` chains; exhaustive).
- [x] **4.7 ⚠️ `ansi.zig writeStatsMessage`**: extract `count(writer,n,sing,plur)` helper (4× dup).

---

## Done log
- 2026-06-29 (eacde65d): **1.3–1.7** exhaustive coverage tests landed; the icon test caught + fixed a real **icon-precedence bug** (Cargo.toml/package.json/*.lock showed wrong icons). i18n alias-resolution / distinctness / round-trip + path-eval precedence coverage all green.
- 2026-06-29: **1.1 — false positive.** Empty annotation is an intentional *tombstone* to suppress an inherited parent-dir note (existing `test_annotate_empty_clears_local_entry` asserts it); "clears" = clears the *displayed* note. No change.
- 2026-06-29: **1.2 — resolved by removal.** `--head`/`--tail` compose into a middle window (not "later wins"); they duplicate unix `head`/`tail` (the help even said "prefer piping to tail -N"). **Removed entirely** — 2 CliArgs, parse arms, the tail-buffer render path + `head_reached` threading + `BufListWriter`, 6 Strings fields × 50 locales, localized aliases, and the old tests; added a rejection test. Pure subtraction.
- 2026-06-29: **Phase 2** done. `Locale.code()` is now just `@tagName(self)` (deleted the 50-arm switch); the `cli_alias_map` hand-list is derived from `all_locales` via `localeCliAliases`. Removed 2 of the 6 hand-maintained 50-entry lists (registry pattern, as `available_codes` already proved). Validated by the 1734-assertion alias-resolution test + parseLocaleCode round-trip.
- 2026-06-29: **Phase 3 wave 1** (5 worktree subagents). 3.14 icons->StaticStringMap (122 ext + 25 filename rows, exhaustive test green). 3.6 scm jj-diff failure now falls back to git (was silently dark). 3.7 pcre2 workspace-OOM now propagates/aborts-loud instead of silently mis-routing show/hide (scan-time path panics; state-build path returns a real error). 3.8 update_check cachePath Windows fallback (LOCALAPPDATA/USERPROFILE) + test. 3.10 glob char-class edge tests — surfaced + fixed an `isGlobPattern` bug (embedded `\*` was wrongly a wildcard; now escape-aware).
- 2026-06-29 (3.3): **Unified truthy parsing.** New `state.parseBool(s) ?bool` (case-insensitive: `1/true/yes/on`→true, `0/false/no/off`→false, else null) is now the single source of truth. `main.zig` `isTruthyEnv` + `detectTty` PIPED_STDOUT block delegate to it; `state.zig` color/hyperlink state-file parse delegate to it (unrecognized → passthrough preserved). Fixes `state.zig` previously rejecting `"TRUE"`/`"yes"`/`"on"` while `main.zig` accepted them. Classifier-over-the-set test (truthy/falsy/null).
- 2026-06-29 (3.4): **flake_staleness.sh portability.** Added `FLAKE_LOCK_NOW` epoch override (deterministic tests; age math stays in `date +%s` epoch — GNU/BSD-agnostic, no formatted-date parsing). Dropped the `python3` dependency: `lastModified` is now extracted via jq when present, else a pure awk/bash fallback scoped to the `"nixpkgs": {` node (an input *reference* of the same name can't fool it). Both extractors verified to agree on the real flake.lock. 4 new tests (deterministic exact-age, no-python, no-python+no-jq pure-bash, python-free source assertion); 11/11 green.
- 2026-06-29 (3.5): **OOM-path hardening in tree_render.zig.** Moved the `visible` `child_rel` cleanup `defer` to immediately after `defer visible.deinit(allocator)` (above the accumulation loop) at both render sites (renderDir + renderDirFocused). defers are LIFO so child_rel frees still run before the backing deinit; now a mid-loop allocation failure also frees already-appended dupes (previously leaked; arena masked it). Mechanical refactor under existing render coverage; full suite green.
- 2026-06-29 (3.9): **Numeric boundary tests** (`test_numeric_boundaries`, classifier over the set). `-d`/`--max-lines` reject negatives AND u32 overflow (rc!=0, both fall to the "requires a numeric argument" path); `-d 0` = root-only; `-d 4294967295` (u32 max) = valid; `--max-lines` large threshold = no warning, small/0 = warns. **NOTE/footgun:** `--max-lines 0` sets threshold 0 so it warns *always* — inconsistent with the `FLAKE_LOCK_STALE_DAYS=0 = silent` convention. Left as-is (characterized, not redesigned); flag to Peter as a possible follow-up (0 ⇒ disable advisory).
- 2026-06-29 (3.11): **Structural state round-trip test.** parse(input) → write → re-parse, then compare the two StateFile structs structurally: all 8 scalars equal; open/close/show/hide entry lists equal as SETS (writer sorts, so order may differ) via hasEntry(kind,value,negated); annotations as a set of (path,description); passthrough preserved in order. Plus idempotency: writing the re-parsed struct yields byte-identical output (writer is a fixed point). Replaces the old substring-grep-only "round-trip" check.
- 2026-06-29 (3.12): **Strengthened 3 weak tests.** (a) `scanDir returns entries` now asserts `build.zig` is present by name (not just `len>0`, which garbage could satisfy). (b) `dirtree root resolves repo` now asserts the root header actually ends with the resolved repo basename + `/` (was: non-empty output only — name claimed more than it checked). (c) dropped the redundant `available_codes contains en` substring test and tightened the completeness test to **exact comma-token membership** (so a 2-char code can't pass by matching inside another code).
- 2026-06-29 (3.13): **Docs/notes.** Fixed stale MEMORY.md (22→50 locales, full list + 5 RTL). Created PROJECT_OVERVIEW.md (goals, architecture map, terminology) and RULES.md (12 hard invariants). Dogfooded `dirtree note` on all 20 core source files + i18n infra + docs (the 50 collapsed locale files left un-noted by design). Documented the `run-tests`-vs-`./test` deviation: a `./test` file can't exist because `test/` is the integration-test directory (name collision) — `run-tests` is the single master runner.
- 2026-06-29 (4.7): **ansi.zig stats dedup.** Extracted `printCount(writer,n,singular,plural)` (the "1 X"/"{n} Xs" pluralization, was inlined 6×) and `printDirFilePair(writer,dirs,files,s)` (the dirs+and+files block, was inlined 3× across shown/hidden/scm sections). writeStatsMessage's three sections each collapse to one call. Output byte-identical (integration stats tests pass unchanged).
- 2026-06-29 (4.6): **state.zig enum value dispatch via std.meta.stringToEnum.** Replaced the `sort`/`sort_direction` if/else-if eql chains with `stringToEnum(SortMode/SortDirection, value)` — exhaustive (a new enum variant auto-parses) and matches the serializer (field names == serialized strings). `default` left as-is (it has lenient open/close aliases + migration flag that stringToEnum can't express). Round-trip test (3.11) covers it; suite green.
- 2026-06-29 (4.3): **Extracted shared collectVisible() first pass.** renderDir and renderDirFocused had ~75 identical lines (entry eval + filter + child_rel dupe + hidden/shown/scm tallying). Hoisted into `collectVisible(...) !ArrayListUnmanaged(VisibleEntry)`; both call sites collapse to one call + the caller-owns cleanup defer. The 3.5 OOM-cleanup is now consolidated in collectVisible's errdefer (single source). Pure extraction — tree output byte-identical (full integration suite green). Removes the divergence risk between the two render paths' first passes.
- 2026-06-29 (4.4): **i18n single comptime registry — last hand-lists gone.** Replaced the two 50-arm switches (`stringsFor`, `localeCliAliases`) with comptime tables derived from `all_locales`: `arr[@intFromEnum(loc)] = &@field(@This(), name).strings` (name = `tr_locale` for `.tr`, else `@tagName`). Removes the final 2 of the original 6 hand-maintained 50-entry lists; adding a locale now needs only its enum entry + `all_locales` + import. Validated by the 1734-assertion alias-resolution test + distinctness + round-trip (all green).

---

## Phase 5 — HTML output (new feature, approved 2026-06-30; build AFTER Phase 4)

Decisions (Peter, 2026-06-30):
- **Interactivity:** native `<details>`/`<summary>` only — **no JS**. `<details open>` ↔ opened dirs, `<details>` ↔ closed dirs (maps to existing open/closed state).
- **Icons:** **Nerd Font via `@font-face`** (match the terminal exactly). Single-file ⇒ embed the font as a base64 data-URI; verify the chosen Nerd Font's license permits embedding (OFL/MIT). Note size cost.
- **Packaging:** **single self-contained `.html`** (inline CSS + embedded font) to stdout/`-o`. Flag: `--html` (alias `--format html`). Honors `-`/`@stdout`.
- **Architecture:** new `src/html_render.zig` adapter, **pure function** (state + scanned entries → HTML string, no I/O), reusing `collectVisible`/`path_eval`/`state`/`ansi` color logic. Hexagonal — parallel to `tree_render.zig`.
- **v1 scope:** colorful nested `<details>` tree, Nerd Font glyphs, ANSI→CSS color mapping, annotations as a dim inline column, `file://` links on names (reuse `ansi.buildFileUrl`). Test: pure-function output assertions + **show Peter rendered HTML in a browser before locking assertions** (visual-output discipline).
- **Styling (Peter, 2026-06-30):** output must be styleable. v1 ships a default **dark** theme,
  but the **CSS class names are overridable** (stable, documented class hooks like `.dt-dir`/
  `.dt-file`/`.dt-note`/`.dt-link`; allow overriding via a `--html-class-prefix` or an injectable
  stylesheet hook) so users can restyle without patching the generator.
- **Defer:** search/expand-all (would need JS); light theme + theme toggle (dark is the v1 default).

### Phase 5 — progress
- [x] **5.1 Pure HTML renderer** (`src/html_render.zig`) — `htmlRender(writer, title, nodes, config)` + `renderNode`; self-contained doc (doctype, meta charset/viewport, inline dark theme, optional `@font-face`), nested `<details>`/`<summary>` tree, `<details open>`↔open dirs, HTML-escaping (names/notes/targets/hrefs), styleable class hooks via `class_prefix` (`dt-dir`/`dt-file`/`dt-symlink`/`dt-note`/`dt-link`/`dt-icon`/`dt-arrow`/`dt-target`), `file://` links, dim note column, Nerd Font icon spans, symlink ` → target`. 14 unit tests. _(2026-06-30)_
- [x] **5.2 FS→node builder** (`tree_render.buildHtmlTree`) — walks FS reusing `collectVisible`/`evaluatePath` so hidden/SCM/sort rules are IDENTICAL to the terminal; **closed dirs DO recurse** (collapsed/expandable, depth-bounded) per Peter's decision. Arena-allocated tree. Unit test proves hide-rule entries stay hidden + closed-dir child still emitted as non-`open`. _(2026-06-30)_
- [x] **5.3 CLI wiring** — `--html` flag + `--format html|text|tree` alias (en-only aliases; exhaustive-switch arms; `html_output` config). HTML render dispatch in main builds the tree + emits to stdout; icons/links are TTY-independent for HTML (on unless `--no-icons`/`--no-hyperlinks`). Help line `help_opt_html` added to all 50 locales (49 are **English placeholders — translation pending**) + help table + help golden updated. 5 CLI integration tests. _(2026-06-30)_
- [x] **5.4 Visual approval** — dark theme rendered in a browser and **approved by Peter as-is** 2026-06-30; theme specifics locked as regression assertions. Closed-dir behavior chosen = recurse-collapsed.
- [x] **5.5 Embed Nerd Font** — subset the **MIT** Symbols Nerd Font (Mono) to the 62 glyphs `icons.zig` uses → **12.7 KB woff2** committed at `src/assets/symbols-nerd-font-subset.woff2`; `html_font.zig` `@embedFile`s it + comptime-base64 into the `@font-face` data-URI (no build-time font tooling). `scripts/gen_html_font_subset.sh` regenerates it (hb-subset+woff2 via nix, no Python). MIT attribution in `src/assets/NOTICE-nerd-font.md`. Icons verified rendering in-browser + approved by Peter. Adds ~17 KB/file (33 KB self-contained output). Unit test decodes the data-URI and checks the woff2 magic. _(2026-06-30)_
- [x] **5.6 Translate `help_opt_html`** into all 49 non-English locales (real translations, `FILE`/`stdout`/`HTML` kept literal per metavar convention). _(2026-06-30)_
- [x] **5.7 Output target on `--html`** — `--html` takes an OPTIONAL arg: `--html FILE` writes to FILE; `--html -`/`@stdout` → stdout; bare `--html` (arg absent or a switch follows) is AUTO: when stdout is an interactive TTY it writes `$TMPDIR/dirtree-<basename>.html` and opens it via `$BROWSER` (else `open`/`xdg-open`); when piped/redirected it streams HTML to stdout (so `dirtree --html > out.html` and `| foo` work). TTY decision honors `PIPED_STDOUT`. Same optional target on `--format html`. No `-o` (would collide with `--open`). Target dir is the trailing positional. Helpers `parseHtmlTarget`/`writeHtmlFile`/`htmlTempPath`/`openInBrowser`; renders once into memory then routes to the sink. parseArgs unit tests + 2 CLI integration tests (file + browser via `BROWSER=true`). _(2026-06-30)_

## Phase 4 — remaining
- [ ] 4.1 parseArgs table-drive · [ ] 4.2 main() extraction + resolveRenderConfig · [x] 4.5 collapse render walks (done via ThresholdStreamWriter)
- 2026-06-30 (4.1): **parseArgs cleanups.** (c) Collapsed 46 manual `config.deinit` error-cleanups into one guarded `defer if (config_owned) config.deinit` (errdefer N/A — ParseResult is value-returned, not an error union); the sole transfer sets `config_owned=false`. (b) Removed 4 literal `-d/-o/-c/-p` blocks that duplicated the `.depth/.open/.close/.path` switch arms: added `shortFlagToCliArg`, relaxed the long-flag guard to admit single-dash flags, so short flags resolve through the same switch (a unit test caught the guard subtlety). (a) **Declined — comptime toggle-flag table:** the `switch (cli_arg)` is exhaustive with no `else`, giving compile-time "every CliArg handled" enforcement; a table would force an `else =>` and forfeit that safety for marginal line savings. Explicit arms kept on purpose.
- 2026-06-30 (4.2): **Pure resolveRenderConfig.** Extracted the CLI>state>default precedence resolution (~55 inline lines in main's .config arm) into `tree_render.resolveRenderConfig(cfg: anytype, effective) RenderConfig`. main() now calls it and derives `use_simple`/`max_depth` from the result. `cfg` is anytype to avoid a main<->tree_render import cycle; this also makes precedence directly unit-testable — added a test covering depth (CLI>state>default), color veto rules, sort fallback, and note_column default. Output byte-identical (full integration suite green). (Deferred the larger runTree()/warning-block extraction as lower-value churn; the testable precedence core was the hexagonal win.)
- 2026-06-30 (4.5): **Collapsed the count+render double walk (piped path).** New `src/threshold_writer.zig` `ThresholdStreamWriter` (custom std.Io.Writer): when piped with the large-output warning enabled, a SINGLE render buffers up to `max_lines` lines; if exceeded it emits the warning to stderr, flushes the buffer, then streams the rest directly — bounded memory (~threshold lines), streaming preserved past the limit, no second directory scan. Eliminated the now-dead `countVisibleEntries` pre-scan walk. Warning count is a lower bound `~{threshold+1}+` (Peter-approved; we stop counting at the limit) — language-neutral `+`, zero locale-string changes. TTY/override path unchanged (direct streaming). Tests: 2 unit tests for the writer's buffer/transition + strengthened integration test (all entries stream complete across the buffer→stream boundary; `+` marker present). Visually verified + approved before locking.

**PHASE 4 COMPLETE.** Next: Phase 5 (HTML output) per the scope above.
