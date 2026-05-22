# Annotate Command Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `dirtree annotate <path> "<description>"` (alias `note`) subcommand that persists per-path descriptions to `.dirtree-state` and renders them inline as ` # <description>` after each entry.

**Architecture:** A new `annotate=[ path = description ]` block in the existing INI-MA `.dirtree-state` format. Annotations are merged across the ancestor state-file chain (gitignore-style: deepest entry wins, empty values are tombstones). Ancestor entries get re-based to be relative to the target render directory before merging. The CLI dispatches `annotate` as a positional subcommand BEFORE the usual flag-parsing loop processes the positional as a directory.

**Tech Stack:** Zig 0.16, PCRE2 (already in use), bash for integration tests, INI-MA state file format.

**Spec reference:** `docs/superpowers/specs/2026-05-22-annotate-command-design.md`

**File Structure:**

| File | Role | Status |
|------|------|--------|
| `src/state.zig` | Parse/write `annotate=[...]` block in `StateFile` | Modify |
| `src/path_eval.zig` | Add `annotations` map to `EffectiveState`, merge across inheritance chain with re-basing | Modify |
| `src/main.zig` | Detect `annotate`/`note` subcommand, write to local state file, exit | Modify |
| `src/tree_render.zig` | Append ` # <desc>` after entry name where annotation exists | Modify |
| `src/i18n/cli_aliases.zig` | Add `annotate` to `CliArg` enum | Modify |
| `src/i18n/en.zig` | Register `annotate` and `note` as aliases | Modify |
| `src/i18n/*.zig` (other 21) | Register one localized colloquial name each | Modify |
| `test/dirtree_test` | Bash integration tests | Modify |

---

## Task 1: Add `AnnotateEntry` data structure to `state.zig`

**Files:**
- Modify: `src/state.zig` (add type and field; update `deinit`)

- [ ] **Step 1: Add a failing unit test for the data structure**

Append to `src/state.zig` (end of test block, after existing tests):

```zig
test "AnnotateEntry: StateFile starts with empty annotate_entries" {
	const allocator = std.testing.allocator;
	var sf = StateFile{ .allocator = allocator };
	defer sf.deinit();
	try std.testing.expectEqual(@as(usize, 0), sf.annotate_entries.items.len);
}

test "AnnotateEntry: can append entries and deinit cleans up" {
	const allocator = std.testing.allocator;
	var sf = StateFile{ .allocator = allocator };
	defer sf.deinit();
	const path = try sf.dupeStr("src/main.zig");
	const desc = try sf.dupeStr("Entry point");
	try sf.annotate_entries.append(allocator, .{ .path = path, .description = desc });
	try std.testing.expectEqual(@as(usize, 1), sf.annotate_entries.items.len);
	try std.testing.expectEqualStrings("src/main.zig", sf.annotate_entries.items[0].path);
	try std.testing.expectEqualStrings("Entry point", sf.annotate_entries.items[0].description);
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `zig build test 2>&1 | tail -30`
Expected: Build fails with `error: no field named 'annotate_entries' in 'StateFile'` (or similar).

- [ ] **Step 3: Add the struct and field**

In `src/state.zig`, find the `PatternKind` enum definition (around line 44). Immediately after `pub const PatternKind = enum { ... };` (the existing enum), add:

```zig
/// An annotation entry: path → description.
pub const AnnotateEntry = struct {
	path: []const u8,
	description: []const u8,
};
```

In `pub const StateFile = struct { ... }`, find the existing collections section (look for `hide_entries: std.ArrayListUnmanaged(StateEntry) = .empty,` around line 80). Add this line right after `hide_entries`:

```zig
	// Annotations: path → description
	annotate_entries: std.ArrayListUnmanaged(AnnotateEntry) = .empty,
```

In `pub fn deinit(self: *StateFile)` (around line 88), find the line `self.hide_entries.deinit(a);` and add this directly after it:

```zig
		self.annotate_entries.deinit(a);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `zig build test 2>&1 | tail -10`
Expected: All tests pass, no build errors.

- [ ] **Step 5: Commit**

```bash
git add src/state.zig
git commit -m "state: add AnnotateEntry type and annotate_entries field"
```

---

## Task 2: Parse `annotate=[...]` block in state files

**Files:**
- Modify: `src/state.zig` (parser logic)

- [ ] **Step 1: Add a failing parser test**

Append to `src/state.zig` test block:

```zig
test "parseStateFile: annotate block" {
	const content =
		\\ver=1.2
		\\annotate=[
		\\	src/main.zig = Entry point
		\\	README.md = Project readme
		\\]
	;
	var sf = try parseStateFile(std.testing.allocator, content);
	defer sf.deinit();

	try std.testing.expectEqual(@as(usize, 2), sf.annotate_entries.items.len);

	// Find entries (order may not be input order yet — we only assert presence)
	var found_main = false;
	var found_readme = false;
	for (sf.annotate_entries.items) |e| {
		if (std.mem.eql(u8, e.path, "src/main.zig")) {
			try std.testing.expectEqualStrings("Entry point", e.description);
			found_main = true;
		} else if (std.mem.eql(u8, e.path, "README.md")) {
			try std.testing.expectEqualStrings("Project readme", e.description);
			found_readme = true;
		}
	}
	try std.testing.expect(found_main);
	try std.testing.expect(found_readme);
}

test "parseStateFile: annotate block with empty description (tombstone)" {
	const content =
		\\ver=1.2
		\\annotate=[
		\\	src/legacy.zig = 
		\\]
	;
	var sf = try parseStateFile(std.testing.allocator, content);
	defer sf.deinit();
	try std.testing.expectEqual(@as(usize, 1), sf.annotate_entries.items.len);
	try std.testing.expectEqualStrings("src/legacy.zig", sf.annotate_entries.items[0].path);
	try std.testing.expectEqualStrings("", sf.annotate_entries.items[0].description);
}

test "parseStateFile: annotate description preserves embedded equals" {
	const content =
		\\ver=1.2
		\\annotate=[
		\\	src/foo.zig = a = b + c
		\\]
	;
	var sf = try parseStateFile(std.testing.allocator, content);
	defer sf.deinit();
	try std.testing.expectEqual(@as(usize, 1), sf.annotate_entries.items.len);
	try std.testing.expectEqualStrings("a = b + c", sf.annotate_entries.items[0].description);
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `zig build test 2>&1 | grep -E "annotate block|tombstone|equals|FAIL" | head -10`
Expected: All three tests fail because the parser doesn't recognize `annotate=[...]`.

- [ ] **Step 3: Extend `isKnownArrayKey` and add annotate-specific parsing**

In `src/state.zig`, find `fn isKnownArrayKey(key: []const u8) bool` (around line 613). Replace its body to add `annotate`:

```zig
fn isKnownArrayKey(key: []const u8) bool {
	return std.mem.eql(u8, key, "open") or
		std.mem.eql(u8, key, "close") or
		std.mem.eql(u8, key, "show") or
		std.mem.eql(u8, key, "hide") or
		std.mem.eql(u8, key, "annotate");
}
```

The existing array-block parsing loop (in `parseStateFile`, the `if (current_array) |arr_key|` block around line 159) treats every entry as a literal/glob/regex. For `annotate`, we need a different path: parse `path = description`.

Find the line inside the `if (current_array) |arr_key|` block that says:

```zig
			const entry_str = strip(line);
			if (entry_str.len == 0) continue;

			// Try to parse as regex
			const parsed = regex_mod.parseWrappedRegexToken(entry_str) catch {
```

Replace those lines with:

```zig
			const entry_str = strip(line);
			if (entry_str.len == 0) continue;

			// Special handling for annotate block: parse as path = description
			if (std.mem.eql(u8, arr_key, "annotate")) {
				if (std.mem.indexOfScalar(u8, entry_str, '=')) |eq_pos| {
					const path_raw = stripTrailing(entry_str[0..eq_pos]);
					var desc_raw = entry_str[eq_pos + 1 ..];
					// Strip one leading space after = (round-trip with writer)
					if (desc_raw.len > 0 and desc_raw[0] == ' ') desc_raw = desc_raw[1..];
					if (path_raw.len == 0) {
						comment_buffer.clearRetainingCapacity();
						continue;
					}
					const path_val = try state.dupeStr(path_raw);
					const desc_val = try state.dupeStr(desc_raw);
					try state.annotate_entries.append(allocator, .{ .path = path_val, .description = desc_val });
				}
				comment_buffer.clearRetainingCapacity();
				continue;
			}

			// Try to parse as regex
			const parsed = regex_mod.parseWrappedRegexToken(entry_str) catch {
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `zig build test 2>&1 | tail -10`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/state.zig
git commit -m "state: parse annotate=[ path = description ] block"
```

---

## Task 3: Write `annotate=[...]` block in state files

**Files:**
- Modify: `src/state.zig` (writer logic)

- [ ] **Step 1: Add a failing round-trip test**

Append to `src/state.zig` test block:

```zig
test "writeStateFile: annotate block round-trips" {
	const allocator = std.testing.allocator;
	var sf = StateFile{ .allocator = allocator };
	defer sf.deinit();

	const p1 = try sf.dupeStr("src/main.zig");
	const d1 = try sf.dupeStr("Entry point");
	const p2 = try sf.dupeStr("README.md");
	const d2 = try sf.dupeStr("Project readme");
	try sf.annotate_entries.append(allocator, .{ .path = p1, .description = d1 });
	try sf.annotate_entries.append(allocator, .{ .path = p2, .description = d2 });

	var buf: [4096]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	try writeStateFile(&sf, &fbs);
	const output = fbs.buffered();

	try std.testing.expect(std.mem.indexOf(u8, output, "annotate=[") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "\tREADME.md = Project readme\n") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "\tsrc/main.zig = Entry point\n") != null);

	// Sorted alphabetically: README.md must come before src/main.zig
	const readme_pos = std.mem.indexOf(u8, output, "\tREADME.md").?;
	const main_pos = std.mem.indexOf(u8, output, "\tsrc/main.zig").?;
	try std.testing.expect(readme_pos < main_pos);
}

test "writeStateFile: annotate empty when no entries" {
	const allocator = std.testing.allocator;
	var sf = StateFile{ .allocator = allocator };
	defer sf.deinit();

	var buf: [4096]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	try writeStateFile(&sf, &fbs);
	const output = fbs.buffered();
	try std.testing.expect(std.mem.indexOf(u8, output, "annotate=[") == null);
}

test "writeStateFile: annotate preserves empty description" {
	const allocator = std.testing.allocator;
	var sf = StateFile{ .allocator = allocator };
	defer sf.deinit();
	const p = try sf.dupeStr("src/dead.zig");
	const d = try sf.dupeStr("");
	try sf.annotate_entries.append(allocator, .{ .path = p, .description = d });

	var buf: [4096]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	try writeStateFile(&sf, &fbs);
	const output = fbs.buffered();
	try std.testing.expect(std.mem.indexOf(u8, output, "\tsrc/dead.zig = \n") != null);
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `zig build test 2>&1 | grep -E "annotate block round|annotate empty|preserves empty desc|FAIL" | head -10`
Expected: All three tests fail (the writer doesn't emit the block yet).

- [ ] **Step 3: Add annotate-block emission to writeStateFile**

In `src/state.zig`, find the section in `writeStateFile` that emits the standard collections — the `inline for (.{ "open", "close", "show", "hide" }) |key|` loop (around line 497). After the closing `}` of that `inline for` block, but BEFORE the `// Passthrough` section, add:

```zig
	// Annotations (sorted alphabetically by path)
	if (state.annotate_entries.items.len > 0) {
		if (wrote_block) try writer.print("\n", .{});
		try writer.print("annotate=[\n", .{});

		// Sort entries alphabetically by path (stable order for deterministic output)
		std.mem.sort(AnnotateEntry, state.annotate_entries.items, {}, annotateLessThan);
		for (state.annotate_entries.items) |entry| {
			try writer.print("\t{s} = {s}\n", .{ entry.path, entry.description });
		}
		try writer.print("]\n", .{});
		wrote_block = true;
	}
```

Then add this helper function near the other comparison helpers (near `fn entryLessThan` around line 552):

```zig
fn annotateLessThan(_: void, a: AnnotateEntry, b: AnnotateEntry) bool {
	return std.mem.lessThan(u8, a.path, b.path);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `zig build test 2>&1 | tail -10`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/state.zig
git commit -m "state: write annotate=[...] block sorted by path"
```

---

## Task 4: Add `annotate` to the `CliArg` enum

**Files:**
- Modify: `src/i18n/cli_aliases.zig`

- [ ] **Step 1: Add the enum value**

In `src/i18n/cli_aliases.zig`, find the `CliArg` enum definition. After the last entry `only,` add:

```zig
    annotate,
```

So the enum now has `..., only, annotate,`.

- [ ] **Step 2: Run tests to verify the enum is valid**

Run: `zig build 2>&1 | tail -5`
Expected: Builds cleanly (no compile errors).

- [ ] **Step 3: Commit**

```bash
git add src/i18n/cli_aliases.zig
git commit -m "i18n: add annotate to CliArg enum"
```

---

## Task 5: Register `annotate` and `note` aliases in English locale

**Files:**
- Modify: `src/i18n/en.zig`

- [ ] **Step 1: Add a failing test**

Append to `src/i18n/mod.zig` test block:

```zig
test "matchLongFlag: annotate and note aliases" {
    try std.testing.expectEqual(CliArg.annotate, matchLongFlag("annotate").?);
    try std.testing.expectEqual(CliArg.annotate, matchLongFlag("note").?);
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `zig build test 2>&1 | grep -E "annotate and note|FAIL" | head -5`
Expected: Test fails — neither alias is registered.

- [ ] **Step 3: Add the aliases in en.zig**

In `src/i18n/en.zig`, find the `.cli` array in `pub const aliases = LocaleAliases{ .cli = &[_]CliAliasEntry{ ... }, ... };` (around line 109). After the last entry `.{ .name = "--only", .arg = .only },` add:

```zig
        .{ .name = "annotate", .arg = .annotate },
        .{ .name = "note", .arg = .annotate },
```

(Note: no `--` prefix — these are positional subcommand names, not flags.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `zig build test 2>&1 | tail -5`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/i18n/en.zig src/i18n/mod.zig
git commit -m "i18n(en): register annotate and note as subcommand aliases"
```

---

## Task 6: Add error string slots in `Strings` for annotate errors

**Files:**
- Modify: `src/i18n/strings.zig` (the struct)
- Modify: `src/i18n/en.zig` (populate strings)
- Modify: each other locale file (populate or copy from en for now)

- [ ] **Step 1: Locate Strings struct**

Run: `grep -n "err_only_requires_path\|err_unknown_option" /Users/pmarreck/Documents-CloudManaged/dirtree/src/i18n/strings.zig | head -5`
Note the line numbers. Use Read tool to inspect the Strings struct.

- [ ] **Step 2: Add new string fields**

In `src/i18n/strings.zig`, find the `Strings` struct. Add these fields next to other error strings (look for `err_unknown_option` or similar; group with errors):

```zig
    err_annotate_requires_path: []const u8,
    err_annotate_requires_description: []const u8,
    err_annotate_multiline: []const u8,
    err_annotate_too_many_args: []const u8,
    help_opt_annotate: []const u8,
```

- [ ] **Step 3: Populate strings in en.zig**

In `src/i18n/en.zig`, in the `.strings` literal that defines the English strings, add (near other err_ fields):

```zig
    .err_annotate_requires_path = "Error: annotate requires a path",
    .err_annotate_requires_description = "Error: annotate requires a description (use \"\" to clear)",
    .err_annotate_multiline = "Error: annotation description must be a single line",
    .err_annotate_too_many_args = "Error: annotate accepts exactly two positional arguments: <path> <description>",
    .help_opt_annotate = "  annotate PATH DESC Persist a one-line note about a file or directory (alias: note; empty DESC clears)",
```

- [ ] **Step 4: Populate the same fields in every other locale file**

For each of these files, add the same five fields. For now, copy the English text verbatim — translators can localize later:

`src/i18n/ar.zig`, `src/i18n/az.zig`, `src/i18n/de.zig`, `src/i18n/el.zig`, `src/i18n/es.zig`, `src/i18n/fa.zig`, `src/i18n/fr.zig`, `src/i18n/he.zig`, `src/i18n/hu.zig`, `src/i18n/it.zig`, `src/i18n/ja.zig`, `src/i18n/km.zig`, `src/i18n/ko.zig`, `src/i18n/pl.zig`, `src/i18n/pt_br.zig`, `src/i18n/ro.zig`, `src/i18n/ru.zig`, `src/i18n/tr.zig`, `src/i18n/uk.zig`, `src/i18n/vi.zig`, `src/i18n/zh_hans.zig`

In each file, find the `.strings` block and add the same five lines as in Step 3. Use the same English text for all locales as placeholders.

- [ ] **Step 5: Run the build to verify all locales compile**

Run: `zig build 2>&1 | tail -10`
Expected: Builds cleanly. If any locale file is missing a field, the compiler will name it.

- [ ] **Step 6: Commit**

```bash
git add src/i18n/strings.zig src/i18n/*.zig
git commit -m "i18n: add error and help strings for annotate command"
```

---

## Task 7: Register localized annotate aliases for non-English locales

**Files:**
- Modify: each non-English locale file (21 files)

- [ ] **Step 1: Add a failing test**

Append to `src/i18n/mod.zig` test block:

```zig
test "matchLongFlag: at least one localized annotate alias per locale" {
    // Sanity: each locale should map at least one non-English colloquial term
    // to .annotate. We don't assert exact spellings (translators can refine);
    // we just verify the map contains entries for known-good examples.
    try std.testing.expectEqual(CliArg.annotate, matchLongFlag("nota").?);    // es/it/pt_br
    try std.testing.expectEqual(CliArg.annotate, matchLongFlag("notiz").?);   // de
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `zig build test 2>&1 | grep -E "localized annotate|FAIL" | head -5`
Expected: Test fails — those aliases aren't yet registered.

- [ ] **Step 3: Register one colloquial name per non-English locale**

For each file below, find the `.cli = &[_]CliAliasEntry{ ... },` block and append the listed entry just before the closing `}`. Single entry per locale — keep it simple; future PRs can add synonyms.

| File | Entry to add |
|------|--------------|
| `src/i18n/de.zig` | `.{ .name = "notiz", .arg = .annotate },` |
| `src/i18n/es.zig` | `.{ .name = "nota", .arg = .annotate },` |
| `src/i18n/fr.zig` | `.{ .name = "annoter", .arg = .annotate },` |
| `src/i18n/it.zig` | `.{ .name = "nota", .arg = .annotate },` |
| `src/i18n/pt_br.zig` | `.{ .name = "nota", .arg = .annotate },` |
| `src/i18n/ro.zig` | `.{ .name = "noteaza", .arg = .annotate },` |
| `src/i18n/pl.zig` | `.{ .name = "notatka", .arg = .annotate },` |
| `src/i18n/ru.zig` | `.{ .name = "zametka", .arg = .annotate },` |
| `src/i18n/uk.zig` | `.{ .name = "notatka", .arg = .annotate },` |
| `src/i18n/el.zig` | `.{ .name = "simeiosi", .arg = .annotate },` |
| `src/i18n/tr.zig` | `.{ .name = "not", .arg = .annotate },` |
| `src/i18n/az.zig` | `.{ .name = "qeyd", .arg = .annotate },` |
| `src/i18n/hu.zig` | `.{ .name = "jegyzet", .arg = .annotate },` |
| `src/i18n/ar.zig` | `.{ .name = "mulahaza", .arg = .annotate },` |
| `src/i18n/fa.zig` | `.{ .name = "yaddasht", .arg = .annotate },` |
| `src/i18n/he.zig` | `.{ .name = "heara", .arg = .annotate },` |
| `src/i18n/ja.zig` | `.{ .name = "memo", .arg = .annotate },` |
| `src/i18n/ko.zig` | `.{ .name = "juseok", .arg = .annotate },` |
| `src/i18n/zh_hans.zig` | `.{ .name = "zhushi", .arg = .annotate },` |
| `src/i18n/vi.zig` | `.{ .name = "ghichu", .arg = .annotate },` |
| `src/i18n/km.zig` | `.{ .name = "chamna", .arg = .annotate },` |

Note: `pl.zig` and `uk.zig` both use `notatka` — those don't collide because they share the same `.annotate` arg value (the alias map already deduplicates same-name/same-arg).

If two locales use the same Latin-script word for a DIFFERENT meaning, the comptime alias-map check in `mod.zig` will catch it as a collision and the build will fail. Should this happen during implementation, drop one of the conflicting entries and pick a different colloquial term for that locale.

- [ ] **Step 4: Run tests to verify they pass**

Run: `zig build test 2>&1 | tail -10`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/i18n/*.zig
git commit -m "i18n: register localized colloquial annotate aliases per locale"
```

---

## Task 8: Wire annotate subcommand dispatch in `main.zig`

**Files:**
- Modify: `src/main.zig` (subcommand detection, file write, exit)

- [ ] **Step 1: Add failing unit tests for the subcommand parser**

In `src/main.zig`, append to the test block at the bottom:

```zig
test "parseArgs: annotate subcommand detected" {
	const args = &[_][:0]const u8{ "dirtree", "annotate", "src/main.zig", "Entry point" };
	const result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.annotate => |a| {
			try std.testing.expectEqualStrings("src/main.zig", a.path);
			try std.testing.expectEqualStrings("Entry point", a.description);
		},
		else => return error.TestExpectedAnnotate,
	}
}

test "parseArgs: note synonym detected" {
	const args = &[_][:0]const u8{ "dirtree", "note", "src/state.zig", "INI-MA parser" };
	const result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.annotate => |a| {
			try std.testing.expectEqualStrings("src/state.zig", a.path);
			try std.testing.expectEqualStrings("INI-MA parser", a.description);
		},
		else => return error.TestExpectedAnnotate,
	}
}

test "parseArgs: annotate empty description allowed (tombstone)" {
	const args = &[_][:0]const u8{ "dirtree", "annotate", "src/dead.zig", "" };
	const result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.annotate => |a| {
			try std.testing.expectEqualStrings("src/dead.zig", a.path);
			try std.testing.expectEqualStrings("", a.description);
		},
		else => return error.TestExpectedAnnotate,
	}
}

test "parseArgs: annotate missing description errors" {
	const args = &[_][:0]const u8{ "dirtree", "annotate", "src/main.zig" };
	const result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.err => {},
		else => return error.TestExpectedError,
	}
}

test "parseArgs: annotate too many args errors" {
	const args = &[_][:0]const u8{ "dirtree", "annotate", "a", "b", "c" };
	const result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.err => {},
		else => return error.TestExpectedError,
	}
}

test "parseArgs: annotate multiline description rejected" {
	const args = &[_][:0]const u8{ "dirtree", "annotate", "a", "first\nsecond" };
	const result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.err => {},
		else => return error.TestExpectedError,
	}
}

test "parseArgs: annotate path normalization" {
	const args = &[_][:0]const u8{ "dirtree", "annotate", "./src/main.zig", "Entry" };
	const result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.annotate => |a| {
			try std.testing.expectEqualStrings("src/main.zig", a.path);
		},
		else => return error.TestExpectedAnnotate,
	}
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `zig build test 2>&1 | grep -E "annotate subcommand|note synonym|tombstone|missing desc|too many args|multiline|path normaliz|FAIL" | head -10`
Expected: All seven tests fail.

- [ ] **Step 3: Add `annotate` variant to `ParseResult` and the `AnnotateArgs` struct**

In `src/main.zig`, find `pub const ParseResult = union(enum) { ... };` (around line 109). Change it to:

```zig
pub const AnnotateArgs = struct {
	path: []const u8,
	description: []const u8,
};

pub const ParseResult = union(enum) {
	config: CliConfig,
	annotate: AnnotateArgs,
	help,
	about,
	test_mode,
	err: []const u8,
};
```

- [ ] **Step 4: Detect the subcommand at the start of parseArgs**

In `src/main.zig`, in `pub fn parseArgs(...)`, right after the line `const args = if (raw_args.len > 0) raw_args[1..] else raw_args;` (around line 157) and BEFORE the `var i: usize = 0;` line, add:

```zig
	// Subcommand: annotate / note (and localized variants).
	// Must appear as the first positional argument. Flags before it
	// (other than --lang) are not supported in v1.
	if (args.len > 0) {
		if (i18n.matchLongFlag(args[0])) |maybe_arg| {
			if (maybe_arg == .annotate) {
				if (args.len < 2) {
					config.deinit(allocator);
					return .{ .err = s.err_annotate_requires_path };
				}
				if (args.len < 3) {
					config.deinit(allocator);
					return .{ .err = s.err_annotate_requires_description };
				}
				if (args.len > 3) {
					config.deinit(allocator);
					return .{ .err = s.err_annotate_too_many_args };
				}
				const desc = args[2];
				if (std.mem.indexOfScalar(u8, desc, '\n') != null) {
					config.deinit(allocator);
					return .{ .err = s.err_annotate_multiline };
				}
				// Normalize path: strip leading ./ and /, strip trailing /
				var p: []const u8 = args[1];
				if (p.len >= 2 and p[0] == '.' and p[1] == '/') p = p[2..];
				while (p.len > 0 and p[0] == '/') p = p[1..];
				while (p.len > 0 and p[p.len - 1] == '/') p = p[0 .. p.len - 1];
				if (p.len == 0) p = ".";
				config.deinit(allocator);
				return .{ .annotate = .{ .path = p, .description = desc } };
			}
		}
	}
```

- [ ] **Step 5: Handle the new `.annotate` result in `main`**

In `src/main.zig`, in `pub fn main(...)`, find the `switch (result) { ... }` block. Add a new arm right after the `.err => ...` arm and BEFORE the `.config => ...` arm:

```zig
		.annotate => |args2| {
			const s2 = i18n.tr();
			// Resolve target directory (CWD) to absolute
			const abs_dir = resolveAbsDir(allocator, ".") catch {
				try stderr.writeAll(s2.err_not_a_directory);
				try stderr.writeAll("\n");
				try stderr.flush();
				return 1;
			};
			defer allocator.free(abs_dir);

			persistAnnotation(allocator, abs_dir, args2.path, args2.description) catch |err| {
				try stderr.print("Error: could not persist annotation: {}\n", .{err});
				try stderr.flush();
				return 1;
			};
			return 0;
		},
```

- [ ] **Step 6: Implement `persistAnnotation`**

At the bottom of `src/main.zig`, after the existing `fn persistState(...)` and `fn removeEntryByValue(...)` (around line 1395), add:

```zig
/// Persist an annotation to the local .dirtree-state file.
/// Empty description writes an empty value (tombstone).
/// Replaces any existing entry for the same path.
fn persistAnnotation(
	allocator: std.mem.Allocator,
	abs_dir: []const u8,
	path: []const u8,
	description: []const u8,
) !void {
	const state_path = try std.fs.path.join(allocator, &.{ abs_dir, ".dirtree-state" });
	defer allocator.free(state_path);

	const io = runtime.io();
	var sf: state_mod.StateFile = blk: {
		const content = std.Io.Dir.cwd().readFileAlloc(io, state_path, allocator, .limited(1024 * 1024)) catch |err| {
			switch (err) {
				error.FileNotFound => {
					break :blk state_mod.StateFile{ .allocator = allocator };
				},
				else => return err,
			}
		};
		defer allocator.free(content);
		break :blk try state_mod.parseStateFile(allocator, content);
	};
	defer sf.deinit();

	// Remove any existing entry for this path
	var i: usize = 0;
	while (i < sf.annotate_entries.items.len) {
		if (std.mem.eql(u8, sf.annotate_entries.items[i].path, path)) {
			_ = sf.annotate_entries.swapRemove(i);
			continue;
		}
		i += 1;
	}

	// Add new entry (including empty description for tombstone)
	const path_owned = try sf.dupeStr(path);
	const desc_owned = try sf.dupeStr(description);
	try sf.annotate_entries.append(allocator, .{ .path = path_owned, .description = desc_owned });

	// Write atomically via temp file + rename
	const tmp_path = try std.fmt.allocPrint(allocator, "{s}.tmp", .{state_path});
	defer allocator.free(tmp_path);

	{
		const file = try std.Io.Dir.cwd().createFile(io, tmp_path, .{});
		defer file.close(io);
		var buf: [8192]u8 = undefined;
		var bw = file.writer(io, &buf);
		try state_mod.writeStateFile(&sf, &bw.interface);
		try bw.interface.flush();
	}

	try std.Io.Dir.cwd().rename(tmp_path, std.Io.Dir.cwd(), state_path, io);
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `zig build test 2>&1 | tail -10`
Expected: All tests pass.

- [ ] **Step 8: Manual smoke test**

```bash
cd /tmp && mkdir -p dirtree-smoke && cd dirtree-smoke && touch foo.zig
/Users/pmarreck/Documents-CloudManaged/dirtree/zig-out/bin/dirtree annotate foo.zig "Test annotation"
cat .dirtree-state
```
Expected: `.dirtree-state` exists and contains an `annotate=[\n\tfoo.zig = Test annotation\n]` block.

Then:
```bash
/Users/pmarreck/Documents-CloudManaged/dirtree/zig-out/bin/dirtree annotate foo.zig ""
cat .dirtree-state
```
Expected: `annotate=[\n\tfoo.zig = \n]` (empty description preserved).

Cleanup:
```bash
cd /tmp && rm -rf dirtree-smoke
```

- [ ] **Step 9: Commit**

```bash
git add src/main.zig
git commit -m "main: dispatch annotate/note subcommand to persist annotations"
```

---

## Task 9: Add `annotations` map to `EffectiveState`

**Files:**
- Modify: `src/path_eval.zig`

- [ ] **Step 1: Add a failing test**

Append to `src/path_eval.zig` test block:

```zig
test "EffectiveState: annotations map initializes empty and deinit cleans up" {
	const allocator = std.testing.allocator;
	var es = EffectiveState{ .allocator = allocator };
	defer es.deinit();
	try std.testing.expectEqual(@as(u32, 0), es.annotations.count());

	const path = try es.dupeStr("src/main.zig");
	const desc = try es.dupeStr("Entry point");
	try es.annotations.put(allocator, path, desc);
	try std.testing.expectEqual(@as(u32, 1), es.annotations.count());
	try std.testing.expectEqualStrings("Entry point", es.annotations.get("src/main.zig").?);
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `zig build test 2>&1 | grep -E "annotations map|FAIL" | head -5`
Expected: Fails — field doesn't exist.

- [ ] **Step 3: Add the field**

In `src/path_eval.zig`, find `pub const EffectiveState = struct { ... };`. Add this field after `max_lines: ?u32 = null,` (around line 65):

```zig
	// Annotations: path → description (re-based to target directory)
	annotations: std.StringHashMapUnmanaged([]const u8) = .empty,
```

In `pub fn deinit(self: *EffectiveState)` (around line 91), find the line `self.strings.deinit(a);` and add this directly BEFORE it:

```zig
		self.annotations.deinit(a);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `zig build test 2>&1 | tail -10`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/path_eval.zig
git commit -m "path_eval: add annotations map to EffectiveState"
```

---

## Task 10: Populate `annotations` during state-chain inheritance walk

**Files:**
- Modify: `src/path_eval.zig`

This is the most complex task. The strategy:
1. During the walk from root → target, record each annotation entry into a temporary `(absolute_path → description)` map. Deeper files win (overwrite).
2. After the walk, re-base each absolute path to be relative to the target directory. Discard entries outside the tree (path starts with `..`).
3. Remove empty-description entries (tombstones).
4. Store final map in `EffectiveState.annotations`.

- [ ] **Step 1: Add a failing inheritance test**

Append to `src/path_eval.zig` test block:

```zig
test "annotations: local file populates the map" {
	const allocator = std.testing.allocator;
	// Create a temp dir with a .dirtree-state file containing annotations
	var tmp = std.testing.tmpDir(.{});
	defer tmp.cleanup();

	const state_content =
		\\ver=1.2
		\\annotate=[
		\\	foo.zig = First file
		\\	bar.zig = Second file
		\\]
	;
	try tmp.dir.writeFile(.{ .sub_path = ".dirtree-state", .data = state_content });

	// Get absolute path of the temp dir
	const abs_dir = try tmp.dir.realpathAlloc(allocator, ".");
	defer allocator.free(abs_dir);

	var es = try buildEffectiveState(allocator, abs_dir);
	defer es.deinit();

	try std.testing.expectEqualStrings("First file", es.annotations.get("foo.zig").?);
	try std.testing.expectEqualStrings("Second file", es.annotations.get("bar.zig").?);
}

test "annotations: empty description acts as tombstone (excluded from map)" {
	const allocator = std.testing.allocator;
	var tmp = std.testing.tmpDir(.{});
	defer tmp.cleanup();

	const state_content =
		\\ver=1.2
		\\annotate=[
		\\	live.zig = Active
		\\	dead.zig = 
		\\]
	;
	try tmp.dir.writeFile(.{ .sub_path = ".dirtree-state", .data = state_content });

	const abs_dir = try tmp.dir.realpathAlloc(allocator, ".");
	defer allocator.free(abs_dir);

	var es = try buildEffectiveState(allocator, abs_dir);
	defer es.deinit();

	try std.testing.expectEqualStrings("Active", es.annotations.get("live.zig").?);
	try std.testing.expect(es.annotations.get("dead.zig") == null);
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `zig build test 2>&1 | grep -E "annotations: local|annotations: empty|FAIL" | head -5`
Expected: Both tests fail (map is empty).

- [ ] **Step 3: Add `annotations` accumulation in `buildEffectiveState`**

In `src/path_eval.zig`, find `pub fn buildEffectiveState(...)` (around line 429). After the existing read of state files from root to target and the local-state read, but BEFORE `// Build effective state` / `return rebuildEffectiveState(...)`, add:

```zig
	// ── Build annotations map (gitignore-style inheritance) ──
	// Step 1: accumulate (absolute_path → description) across the chain.
	// Deeper files win because we walk root→target order and `put` overwrites.
	var abs_annotations = std.StringHashMapUnmanaged([]const u8){};
	defer abs_annotations.deinit(allocator);
	// Track strings we own so we can free them after re-basing.
	var owned_strings: std.ArrayListUnmanaged([]const u8) = .empty;
	defer {
		for (owned_strings.items) |s| allocator.free(s);
		owned_strings.deinit(allocator);
	}

	// Re-walk state_dirs in root→target order (state_dirs is reverse-sorted: index 0 is target).
	// We need to re-read each ancestor's annotate entries.
	var ai: usize = state_dirs.items.len;
	while (ai > 0) {
		ai -= 1;
		const dir = state_dirs.items[ai];
		const sp = try std.fs.path.join(allocator, &.{ dir, ".dirtree-state" });
		defer allocator.free(sp);

		const content = std.Io.Dir.cwd().readFileAlloc(runtime.io(), sp, allocator, .limited(1024 * 1024)) catch continue;
		defer allocator.free(content);

		var sf = state_mod.parseStateFile(allocator, content) catch continue;
		defer sf.deinit();

		for (sf.annotate_entries.items) |entry| {
			const abs_path = blk: {
				if (std.mem.eql(u8, entry.path, ".")) {
					break :blk try allocator.dupe(u8, dir);
				}
				break :blk try std.fs.path.join(allocator, &.{ dir, entry.path });
			};
			try owned_strings.append(allocator, abs_path);
			const desc_owned = try allocator.dupe(u8, entry.description);
			try owned_strings.append(allocator, desc_owned);

			// Deeper wins — fetchPut overwrites previous mapping
			_ = try abs_annotations.fetchPut(allocator, abs_path, desc_owned);
		}
	}

	// Step 2: re-base each absolute path to relative-to-target.
	// Build the final map in the effective state.
	var rebased = std.StringHashMapUnmanaged([]const u8){};
	defer rebased.deinit(allocator);

	var iter = abs_annotations.iterator();
	while (iter.next()) |kv| {
		const abs_path = kv.key_ptr.*;
		const desc = kv.value_ptr.*;

		// Compute relative path from abs_dir to abs_path
		const rel_path = std.fs.path.relative(allocator, abs_dir, abs_path) catch continue;
		defer allocator.free(rel_path);

		// Discard entries outside the target tree (rel starts with "..")
		if (rel_path.len >= 2 and rel_path[0] == '.' and rel_path[1] == '.') continue;

		// Step 3: drop empty-description tombstones
		if (desc.len == 0) continue;

		// Store in effective state with owned copies
		// (effective.strings handles cleanup)
		const key_owned = try allocator.dupe(u8, rel_path);
		// dupe via effective so it cleans up
		// (We can't use es.dupeStr here because es isn't built yet — track via owned_strings)
		// Instead, write directly to the rebased map then transfer in the next step.
		try rebased.put(allocator, key_owned, desc);
		try owned_strings.append(allocator, key_owned);
	}
```

- [ ] **Step 4: Pass `rebased` to `rebuildEffectiveState` and transfer ownership**

After the loop above and before the existing `return rebuildEffectiveState(allocator, &inherited, ...)`, replace the existing return with:

```zig
	// Build effective state (existing logic)
	var effective = try rebuildEffectiveState(allocator, &inherited, if (local_state) |*ls| ls else null);
	errdefer effective.deinit();

	// Transfer rebased annotations into effective.annotations with owned copies
	var rb_iter = rebased.iterator();
	while (rb_iter.next()) |kv| {
		const k = try effective.dupeStr(kv.key_ptr.*);
		const v = try effective.dupeStr(kv.value_ptr.*);
		try effective.annotations.put(allocator, k, v);
	}

	return effective;
```

Remove the existing `return rebuildEffectiveState(allocator, &inherited, ...)` that used to be the last line of the function.

- [ ] **Step 5: Run tests to verify they pass**

Run: `zig build test 2>&1 | tail -10`
Expected: All tests pass.

- [ ] **Step 6: Add inheritance test (parent → child)**

Append to `src/path_eval.zig` test block:

```zig
test "annotations: inherited from parent, with local override" {
	const allocator = std.testing.allocator;
	var parent_tmp = std.testing.tmpDir(.{});
	defer parent_tmp.cleanup();

	// Parent state file references sub/inner.zig
	const parent_content =
		\\ver=1.2
		\\annotate=[
		\\	sub/inner.zig = Parent says inner
		\\	sub/other.zig = Parent says other
		\\	above.zig = Outside scope
		\\]
	;
	try parent_tmp.dir.writeFile(.{ .sub_path = ".dirtree-state", .data = parent_content });
	try parent_tmp.dir.makePath("sub");

	// Child state file overrides one annotation
	const child_content =
		\\ver=1.2
		\\annotate=[
		\\	inner.zig = Child overrides
		\\]
	;
	try parent_tmp.dir.writeFile(.{ .sub_path = "sub/.dirtree-state", .data = child_content });

	const parent_abs = try parent_tmp.dir.realpathAlloc(allocator, ".");
	defer allocator.free(parent_abs);
	const child_abs = try std.fs.path.join(allocator, &.{ parent_abs, "sub" });
	defer allocator.free(child_abs);

	var es = try buildEffectiveState(allocator, child_abs);
	defer es.deinit();

	// Child override wins
	try std.testing.expectEqualStrings("Child overrides", es.annotations.get("inner.zig").?);
	// Parent's entry for sub/other.zig re-bases to "other.zig" and is inherited
	try std.testing.expectEqualStrings("Parent says other", es.annotations.get("other.zig").?);
	// above.zig is outside the rendered tree → must not appear
	try std.testing.expect(es.annotations.get("../above.zig") == null);
	try std.testing.expect(es.annotations.get("above.zig") == null);
}

test "annotations: child empty value suppresses parent annotation" {
	const allocator = std.testing.allocator;
	var parent_tmp = std.testing.tmpDir(.{});
	defer parent_tmp.cleanup();

	const parent_content =
		\\ver=1.2
		\\annotate=[
		\\	sub/inner.zig = Parent description
		\\]
	;
	try parent_tmp.dir.writeFile(.{ .sub_path = ".dirtree-state", .data = parent_content });
	try parent_tmp.dir.makePath("sub");

	const child_content =
		\\ver=1.2
		\\annotate=[
		\\	inner.zig = 
		\\]
	;
	try parent_tmp.dir.writeFile(.{ .sub_path = "sub/.dirtree-state", .data = child_content });

	const parent_abs = try parent_tmp.dir.realpathAlloc(allocator, ".");
	defer allocator.free(parent_abs);
	const child_abs = try std.fs.path.join(allocator, &.{ parent_abs, "sub" });
	defer allocator.free(child_abs);

	var es = try buildEffectiveState(allocator, child_abs);
	defer es.deinit();

	try std.testing.expect(es.annotations.get("inner.zig") == null);
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `zig build test 2>&1 | tail -10`
Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add src/path_eval.zig
git commit -m "path_eval: merge annotations across state-file chain with re-basing"
```

---

## Task 11: Render annotations after entry names

**Files:**
- Modify: `src/tree_render.zig`

- [ ] **Step 1: Add a failing render test**

Append to `src/tree_render.zig` test block:

```zig
test "renderDirEntry: appends annotation after name" {
	const allocator = std.testing.allocator;
	var buf: [1024]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	const writer = &fbs;

	var es = path_eval.EffectiveState{ .allocator = allocator };
	defer es.deinit();
	const k = try es.dupeStr("src");
	const v = try es.dupeStr("Source code");
	try es.annotations.put(allocator, k, v);

	try renderDirEntry(allocator, writer, "/tmp", "src", "src", "", "├── ", "/", .{
		.use_color = false,
		.use_icons = false,
		.use_hyperlinks = false,
		.simple_mode = true,
	}, &es);

	const output = fbs.buffered();
	try std.testing.expect(std.mem.indexOf(u8, output, " # Source code") != null);
	try std.testing.expect(std.mem.endsWith(u8, output, "\n"));
}

test "renderFileEntry: appends annotation after name" {
	const allocator = std.testing.allocator;
	var buf: [1024]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	const writer = &fbs;

	var es = path_eval.EffectiveState{ .allocator = allocator };
	defer es.deinit();
	const k = try es.dupeStr("foo.zig");
	const v = try es.dupeStr("Demo file");
	try es.annotations.put(allocator, k, v);

	try renderFileEntry(allocator, writer, "/tmp", "foo.zig", "foo.zig", "", "└── ", false, false, .{
		.use_color = false,
		.use_icons = false,
		.use_hyperlinks = false,
		.simple_mode = true,
	}, &es);

	const output = fbs.buffered();
	try std.testing.expect(std.mem.indexOf(u8, output, " # Demo file") != null);
}

test "renderFileEntry: no annotation when not in map" {
	const allocator = std.testing.allocator;
	var buf: [1024]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	const writer = &fbs;

	var es = path_eval.EffectiveState{ .allocator = allocator };
	defer es.deinit();

	try renderFileEntry(allocator, writer, "/tmp", "foo.zig", "foo.zig", "", "└── ", false, false, .{
		.use_color = false,
		.use_icons = false,
		.use_hyperlinks = false,
		.simple_mode = true,
	}, &es);

	const output = fbs.buffered();
	try std.testing.expect(std.mem.indexOf(u8, output, "#") == null);
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `zig build test 2>&1 | grep -E "appends annotation|no annotation when|FAIL" | head -5`
Expected: Tests fail (signature mismatch — functions don't accept `&es`).

- [ ] **Step 3: Update `renderDirEntry` and `renderFileEntry` to accept and use the effective state**

In `src/tree_render.zig`, find `fn renderDirEntry(` (around line 714). Change its signature to add a final parameter:

```zig
fn renderDirEntry(
	allocator: std.mem.Allocator,
	writer: anytype,
	abs_dir: []const u8,
	name: []const u8,
	child_rel: []const u8,
	prefix: []const u8,
	connector: []const u8,
	marker: []const u8,
	config: RenderConfig,
	effective: *path_eval.EffectiveState,
) !void {
```

At the bottom of the function, find the line `try writer.writeAll("\n");`. Replace it with:

```zig
	// Annotation, if any
	if (effective.annotations.get(child_rel)) |desc| {
		if (desc.len > 0) {
			try writer.writeAll(" # ");
			try writer.writeAll(desc);
		}
	}

	try writer.writeAll("\n");
```

Do the same for `fn renderFileEntry(` (around line 771). Add `effective: *path_eval.EffectiveState,` as the final parameter. At the very end of the function body, before the existing `try writer.writeAll("\n");`, insert the same annotation-emission block.

- [ ] **Step 4: Update every caller**

Find all callers of `renderDirEntry` and `renderFileEntry`. They're in `renderDir` and `renderDirFocused` in the same file. Run:

```bash
grep -n "renderDirEntry\|renderFileEntry" /Users/pmarreck/Documents-CloudManaged/dirtree/src/tree_render.zig
```

For each call site, add `effective` as the final argument. Example: a call like

```zig
try renderDirEntry(allocator, writer, abs_dir, name, vis.child_rel, prefix, connector, marker, config);
```

becomes

```zig
try renderDirEntry(allocator, writer, abs_dir, name, vis.child_rel, prefix, connector, marker, config, effective);
```

The `effective` variable should already be in scope at every call site (it's threaded through `renderDir` and `renderDirFocused`).

- [ ] **Step 5: Run tests to verify they pass**

Run: `zig build test 2>&1 | tail -10`
Expected: All tests pass.

- [ ] **Step 6: Manual smoke test**

```bash
zig build
cd /tmp && mkdir -p dirtree-render-smoke && cd dirtree-render-smoke && touch foo.zig bar.zig
/Users/pmarreck/Documents-CloudManaged/dirtree/zig-out/bin/dirtree annotate foo.zig "Hello world"
/Users/pmarreck/Documents-CloudManaged/dirtree/zig-out/bin/dirtree --simple --no-icons
```
Expected output includes a line ending with `foo.zig # Hello world`.

Cleanup:
```bash
cd /tmp && rm -rf dirtree-render-smoke
```

- [ ] **Step 7: Commit**

```bash
git add src/tree_render.zig
git commit -m "tree_render: emit ' # <description>' after annotated entries"
```

---

## Task 12: Render annotations on the root header line

**Files:**
- Modify: `src/tree_render.zig`

- [ ] **Step 1: Add a failing test**

Append to `src/tree_render.zig` test block:

```zig
test "renderRootHeader: appends annotation when '.' is annotated" {
	const allocator = std.testing.allocator;
	var buf: [1024]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	const writer = &fbs;

	var es = path_eval.EffectiveState{ .allocator = allocator };
	defer es.deinit();
	const k = try es.dupeStr(".");
	const v = try es.dupeStr("Project root");
	try es.annotations.put(allocator, k, v);

	try renderRootHeader(allocator, writer, "/tmp/test_dir", .{
		.use_color = false,
		.use_icons = false,
		.use_hyperlinks = false,
		.simple_mode = true,
	}, &es);

	const output = fbs.buffered();
	try std.testing.expect(std.mem.indexOf(u8, output, " # Project root") != null);
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `zig build test 2>&1 | grep -E "appends annotation when|FAIL" | head -5`
Expected: Fails — `renderRootHeader` doesn't accept `&es`.

- [ ] **Step 3: Update `renderRootHeader` signature and emission**

In `src/tree_render.zig`, find `fn renderRootHeader(` (around line 167). Change its signature to add a final parameter:

```zig
fn renderRootHeader(
	allocator: std.mem.Allocator,
	writer: anytype,
	abs_dir: []const u8,
	config: RenderConfig,
	effective: *path_eval.EffectiveState,
) !void {
```

At the end of the function, find the final `try writer.writeAll("\n");` (around line 222). Replace it with:

```zig
	// Annotation for the root directory itself, if any
	if (effective.annotations.get(".")) |desc| {
		if (desc.len > 0) {
			try writer.writeAll(" # ");
			try writer.writeAll(desc);
		}
	}

	try writer.writeAll("\n");
```

- [ ] **Step 4: Update existing callers**

Find both call sites in `renderTree` (one in the tail-lines branch around line 85, one in the normal branch around line 126). Each call currently looks like:

```zig
try renderRootHeader(allocator, &buf_writer, abs_dir, config);
```

or

```zig
try renderRootHeader(allocator, stdout, abs_dir, config);
```

Append `, effective` before the closing `)` for each.

Also update the existing root-header tests near the bottom of the file (`renderRootHeader: simple mode shows absolute path` and `renderRootHeader: no icons shows absolute path`). For each, add a local `var es = path_eval.EffectiveState{ .allocator = allocator }; defer es.deinit();` and pass `&es` as the final argument to `renderRootHeader`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `zig build test 2>&1 | tail -10`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add src/tree_render.zig
git commit -m "tree_render: emit annotation on root header when '.' is annotated"
```

---

## Task 13: Add the annotate help line to printHelp

**Files:**
- Modify: `src/main.zig` (help output)

- [ ] **Step 1: Add the new help line**

In `src/main.zig`, find `pub fn printHelp(writer: anytype) !void { ... }` (around line 721). Find the last existing `try writer.writeAll(s.help_opt_only); try writer.writeAll("\n");` block (around line 779-780). Add this block AFTER it (before the blank-line writeAll that introduces the regex_note section):

```zig
	try writer.writeAll(s.help_opt_annotate);
	try writer.writeAll("\n");
```

- [ ] **Step 2: Verify it appears**

Run: `zig build && /Users/pmarreck/Documents-CloudManaged/dirtree/zig-out/bin/dirtree -h | grep -A1 annotate`
Expected: A line resembling `  annotate PATH DESC Persist a one-line note about a file or directory (alias: note; empty DESC clears)`.

- [ ] **Step 3: Commit**

```bash
git add src/main.zig
git commit -m "main: document annotate subcommand in --help"
```

---

## Task 14: Integration tests in bash test harness

**Files:**
- Modify: `test/dirtree_test`

- [ ] **Step 1: Add test functions to the test script**

Open `test/dirtree_test` and locate the test-implementation block (after the fixture helpers, around line 484). Add the following test functions right before the test-runner invocation block at the bottom (search for `run_test "` at the end of the file to find where to insert).

```bash
test_annotate_persists_in_state_file() {
	local path
	path=$(fixture_simple_tree)
	"$DIRTREE_BIN" annotate src/file.txt "A demo file" --no-icons >/dev/null 2>&1
	# Expect the state file to contain an annotate block
	if ! grep -q '^annotate=\[' "$path/.dirtree-state"; then
		echo "expected annotate block not found in state file" >&2
		cat "$path/.dirtree-state" >&2
		return 1
	fi
	if ! grep -q '^\tsrc/file.txt = A demo file$' "$path/.dirtree-state"; then
		echo "expected annotation entry not found" >&2
		cat "$path/.dirtree-state" >&2
		return 1
	fi
}

test_annotate_renders_inline_in_simple_mode() {
	local path output
	path=$(fixture_simple_tree)
	"$DIRTREE_BIN" annotate src/file.txt "Source file" >/dev/null 2>&1
	output=$("$DIRTREE_BIN" --simple --no-icons "$path" 2>/dev/null)
	if ! grep -q 'file.txt # Source file' <<<"$output"; then
		echo "expected ' # Source file' in output, got:" >&2
		echo "$output" >&2
		return 1
	fi
}

test_annotate_empty_clears_local_entry() {
	local path
	path=$(fixture_simple_tree)
	"$DIRTREE_BIN" annotate src/file.txt "Original" >/dev/null 2>&1
	"$DIRTREE_BIN" annotate src/file.txt "" >/dev/null 2>&1
	# The entry should still exist but with empty description (tombstone)
	if ! grep -q '^\tsrc/file.txt = $' "$path/.dirtree-state"; then
		echo "expected empty annotation entry, got:" >&2
		cat "$path/.dirtree-state" >&2
		return 1
	fi
	# And it must NOT render
	local output
	output=$("$DIRTREE_BIN" --simple --no-icons "$path" 2>/dev/null)
	if grep -q 'file.txt #' <<<"$output"; then
		echo "expected no annotation in output, got:" >&2
		echo "$output" >&2
		return 1
	fi
}

test_annotate_overwrites_existing() {
	local path
	path=$(fixture_simple_tree)
	"$DIRTREE_BIN" annotate src/file.txt "First" >/dev/null 2>&1
	"$DIRTREE_BIN" annotate src/file.txt "Second" >/dev/null 2>&1
	if ! grep -q '^\tsrc/file.txt = Second$' "$path/.dirtree-state"; then
		echo "expected updated annotation, got:" >&2
		cat "$path/.dirtree-state" >&2
		return 1
	fi
	if grep -q '^\tsrc/file.txt = First$' "$path/.dirtree-state"; then
		echo "old annotation still present" >&2
		return 1
	fi
}

test_note_synonym_works() {
	local path
	path=$(fixture_simple_tree)
	"$DIRTREE_BIN" note src/file.txt "Via note synonym" >/dev/null 2>&1
	if ! grep -q '^\tsrc/file.txt = Via note synonym$' "$path/.dirtree-state"; then
		echo "expected annotation via 'note' synonym" >&2
		cat "$path/.dirtree-state" >&2
		return 1
	fi
}

test_annotate_inherits_from_parent() {
	local parent child
	parent="$TEST_TMPDIR/dirtree-annotate-parent.$$"
	mkdir -p "$parent/sub"
	touch "$parent/sub/inner.txt"
	TEST_TEMP_PATHS+=("$parent")

	# Parent state file annotates sub/inner.txt
	cat > "$parent/.dirtree-state" <<EOF
ver=1.2
annotate=[
	sub/inner.txt = From parent
]
EOF

	# Render from the child directory; the parent annotation should re-base to "inner.txt" and appear
	child="$parent/sub"
	local output
	output=$("$DIRTREE_BIN" --simple --no-icons "$child" 2>/dev/null)
	if ! grep -q 'inner.txt # From parent' <<<"$output"; then
		echo "expected inherited annotation, got:" >&2
		echo "$output" >&2
		return 1
	fi
}

test_annotate_multiline_rejected() {
	local path rc
	path=$(fixture_simple_tree)
	"$DIRTREE_BIN" annotate src/file.txt $'first\nsecond' >/dev/null 2>&1
	rc=$?
	if (( rc == 0 )); then
		echo "expected non-zero exit for multiline description" >&2
		return 1
	fi
}
```

- [ ] **Step 2: Register the tests in the run block**

At the bottom of `test/dirtree_test`, find the block of `run_test "name" test_function_name` calls. Add these lines at the end (alphabetical order is not required):

```bash
run_test "annotate persists in state file" test_annotate_persists_in_state_file
run_test "annotate renders inline in simple mode" test_annotate_renders_inline_in_simple_mode
run_test "annotate empty clears local entry (tombstone)" test_annotate_empty_clears_local_entry
run_test "annotate overwrites existing entry" test_annotate_overwrites_existing
run_test "note synonym works for annotate" test_note_synonym_works
run_test "annotate inherits from parent state file" test_annotate_inherits_from_parent
run_test "annotate multiline description rejected" test_annotate_multiline_rejected
```

- [ ] **Step 3: Run the bash tests to verify they pass**

Run: `zig build && bash /Users/pmarreck/Documents-CloudManaged/dirtree/test/dirtree_test 2>&1 | tail -30`
Expected: All seven new tests show `✓`, no `✗`.

- [ ] **Step 4: Run the full test suite to confirm no regressions**

Run: `cd /Users/pmarreck/Documents-CloudManaged/dirtree && ./run-tests 2>&1 | tail -20`
Expected: All tests pass (118 prior + 7 new = 125, plus any zig unit tests).

- [ ] **Step 5: Commit**

```bash
git add test/dirtree_test
git commit -m "test: integration tests for annotate/note subcommand"
```

---

## Task 15: Final verification

**Files:** (verification only — no edits)

- [ ] **Step 1: Run the full test suite one more time**

Run: `cd /Users/pmarreck/Documents-CloudManaged/dirtree && zig build test && bash test/dirtree_test 2>&1 | tail -5`
Expected: All zig unit tests pass and all bash integration tests pass.

- [ ] **Step 2: Verify --help shows annotate**

Run: `/Users/pmarreck/Documents-CloudManaged/dirtree/zig-out/bin/dirtree -h | grep annotate`
Expected: One line describing the annotate subcommand.

- [ ] **Step 3: Verify end-to-end with a realistic scenario**

```bash
cd /tmp && mkdir -p dirtree-final && cd dirtree-final
mkdir src && touch src/main.zig src/state.zig README.md
/Users/pmarreck/Documents-CloudManaged/dirtree/zig-out/bin/dirtree annotate src/main.zig "Entry point"
/Users/pmarreck/Documents-CloudManaged/dirtree/zig-out/bin/dirtree annotate README.md "Project readme"
/Users/pmarreck/Documents-CloudManaged/dirtree/zig-out/bin/dirtree --simple --no-icons
```

Expected output contains lines like:
```
├── README.md # Project readme
└── src/
    └── main.zig # Entry point
```
(Exact tree layout depends on sort; the key check is the ` # description` suffixes appear on the right entries.)

Cleanup:
```bash
cd /tmp && rm -rf dirtree-final
```

- [ ] **Step 4: Final commit (if any incidental fixes were needed)**

Only commit if there are uncommitted changes from this verification round.

```bash
git status
# If nothing to commit, skip. Otherwise:
git add -p
git commit -m "<short description of incidental fix>"
```
