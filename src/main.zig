const std = @import("std");
const regex = @import("regex.zig");
const regex_lib = @import("pcre2.zig");
const state_mod = @import("state.zig");
const path_eval = @import("path_eval.zig");
const scm_mod = @import("scm.zig");
const tree_render = @import("tree_render.zig");
const dir_scan = @import("dir_scan.zig");
const ansi_mod = @import("ansi.zig");
const i18n = @import("i18n/mod.zig");
const runtime = @import("runtime.zig");
const update_check = @import("update_check.zig");

pub const SortMode = enum {
	modified,
	alpha,
};

pub const SortDirection = enum {
	asc,
	desc,
};

pub const DefaultState = enum {
	opened,
	closed,
};

pub const ArgEntry = struct {
	value: []const u8,
	kind: state_mod.PatternKind,
	negated: bool,
	owned: bool = false, // true if value was allocated and needs to be freed
};

/// All CLI configuration parsed from arguments and environment.
pub const CliConfig = struct {
	// Display modes
	simple_mode: bool = false,
	force_decorated: bool = false,
	no_icons: bool = false,
	no_color: bool = false,
	// Affirmative inverse of --no-color: re-enable + persist color (escape the one-way door)
	color: bool = false,
	// Suppress the post-listing orphaned-notes warning (this run only, not persisted)
	no_orphan_warning: bool = false,
	// Tri-state note visibility: true=--show-notes, false=--no-notes, null=unset
	cli_notes: ?bool = null,
	// Note layout: inline (ragged) vs aligned gutter (default). Display-only.
	notes_inline: bool = false,
	// Leader dots from name to note in aligned mode (opt-in, display-only).
	note_leader: bool = false,
	no_hyperlinks: bool = false,
	// Affirmative inverse of --no-hyperlinks
	hyperlinks: bool = false,
	// Apply CLI overrides for this run only; do NOT persist to .dirtree-state.
	temporary: bool = false,
	show_hidden: bool = false,
	rewrite_settings: bool = false,
	show_config: bool = false,
	stdout_is_tty: bool = true,

	// Depth
	depth: ?u32 = null,
	// Temporary depth override (this run only, never persisted to state)

	// Sort
	sort_mode: ?SortMode = null,
	sort_direction: ?SortDirection = null,

	// Defaults
	default_state: ?DefaultState = null,

	// Variadic args (literals and regex patterns)
	open_literals: std.ArrayListUnmanaged([]const u8) = .empty,
	open_regexes: std.ArrayListUnmanaged(ArgEntry) = .empty,
	close_literals: std.ArrayListUnmanaged([]const u8) = .empty,
	close_regexes: std.ArrayListUnmanaged(ArgEntry) = .empty,
	show_literals: std.ArrayListUnmanaged([]const u8) = .empty,
	show_regexes: std.ArrayListUnmanaged(ArgEntry) = .empty,
	hide_literals: std.ArrayListUnmanaged([]const u8) = .empty,
	hide_regexes: std.ArrayListUnmanaged(ArgEntry) = .empty,

	// Output control
	max_lines: ?u32 = null,
	override_warning: bool = false,

	// Focus mode
	only_paths: std.ArrayListUnmanaged([]const u8) = .empty,

	// Target directory
	dir: []const u8 = ".",

	// State mutation flag (any --open/--close/--show/--hide/--default/--sort/--depth)
	state_modified: bool = false,

	pub fn deinit(self: *CliConfig, allocator: std.mem.Allocator) void {
		freeOwnedEntries(allocator, &self.open_regexes);
		freeOwnedEntries(allocator, &self.close_regexes);
		freeOwnedEntries(allocator, &self.show_regexes);
		freeOwnedEntries(allocator, &self.hide_regexes);
		self.open_literals.deinit(allocator);
		self.open_regexes.deinit(allocator);
		self.close_literals.deinit(allocator);
		self.close_regexes.deinit(allocator);
		self.show_literals.deinit(allocator);
		self.show_regexes.deinit(allocator);
		self.hide_literals.deinit(allocator);
		self.hide_regexes.deinit(allocator);
		self.only_paths.deinit(allocator);
	}

	fn freeOwnedEntries(allocator: std.mem.Allocator, entries: *std.ArrayListUnmanaged(ArgEntry)) void {
		for (entries.items) |entry| {
			if (entry.owned) {
				allocator.free(entry.value);
			}
		}
	}
};

pub const AnnotateArgs = struct {
	path: []const u8,
	description: []const u8,
};

/// Target directory for the orphaned-notes / purge-orphaned-notes subcommands.
pub const OrphanArgs = struct {
	dir: []const u8,
};

/// Result of argument parsing - either a config or an early exit.
pub const ParseResult = union(enum) {
	config: CliConfig,
	annotate: AnnotateArgs,
	orphaned_notes: OrphanArgs,
	purge_orphaned_notes: OrphanArgs,
	help,
	about,
	version,
	version_check,
	test_mode,
	err: []const u8,
};

/// First pass: scan for --lang CODE and set the i18n locale.
/// Also detects locale from environment if --lang is not present.
fn applyLangArg(raw_args: []const [:0]const u8) void {
	const args = if (raw_args.len > 0) raw_args[1..] else raw_args;
	var i: usize = 0;
	while (i < args.len) : (i += 1) {
		const arg = args[i];
		// Check short flag or long flag via i18n alias map
		if (std.mem.eql(u8, arg, "--lang") or i18n.isFlag(arg, .lang)) {
			i += 1;
			if (i < args.len) {
				if (i18n.parseLocaleCode(args[i])) |loc| {
					i18n.setLocale(loc);
					return;
				}
			}
			return; // --lang was present but invalid code; error handled in second pass
		}
	}
	// No explicit --lang. If the user typed a localized alias (e.g. --hilfe),
	// infer the language from it so help/output match that language. Otherwise
	// fall back to the environment.
	if (i18n.detectLocaleFromAliases(args)) |loc| {
		i18n.setLocale(loc);
		return;
	}
	i18n.setLocale(i18n.detectLocaleFromEnv());
}

/// Parse CLI arguments into a CliConfig.
/// Returns ParseResult which may be an early exit (help, about, test, error).
/// Map a known single-letter short flag to its standalone token.
fn shortFlagToken(c: u8) [:0]const u8 {
	return switch (c) {
		'h' => "-h",
		'a' => "-a",
		't' => "-t",
		'd' => "-d",
		'o' => "-o",
		'c' => "-c",
		'p' => "-p",
		else => unreachable,
	};
}

/// True if `tok` is an expandable getopt-style short-flag cluster: a single-dash
/// token of >=2 letters where every letter is a known short flag and every
/// letter EXCEPT the last is a no-argument flag (h/a/t). The last letter may be
/// an argument-taking flag (d/o/c/p), which then consumes its argument as usual.
/// So "-ta" => -t -a and "-td 3" => -t -d 3, while "-dt" (arg-flag not last) and
/// long flags pass through untouched.
fn isExpandableShort(tok: []const u8) bool {
	if (tok.len < 2 or tok[0] != '-' or tok[1] == '-') return false;
	var idx: usize = 1;
	while (idx < tok.len) : (idx += 1) {
		switch (tok[idx]) {
			'h', 'a', 't' => {},
			'd', 'o', 'c', 'p' => return true, // arg-taking flag ends the scan
			else => return false,
		}
	}
	return true;
}

/// Expand one validated short token into flag tokens, appending to `out`.
/// Returns true if the token ends in `-p` (path) with NO attached value, so the
/// caller knows the FOLLOWING argv token is a verbatim path (skip its expansion).
fn expandOneShort(allocator: std.mem.Allocator, tok: [:0]const u8, out: *std.ArrayListUnmanaged([:0]const u8)) !bool {
	var idx: usize = 1;
	while (idx < tok.len) : (idx += 1) {
		const c = tok[idx];
		switch (c) {
			'h', 'a', 't' => try out.append(allocator, shortFlagToken(c)),
			'd', 'o', 'c', 'p' => {
				try out.append(allocator, shortFlagToken(c));
				const rest = tok[idx + 1 ..]; // [:0] slice of the original token
				if (rest.len > 0) {
					try out.append(allocator, rest); // attached argument, e.g. -d3 -> "3"
				} else if (c == 'p') {
					return true; // -p with no attached value consumes the next token verbatim
				}
				return false;
			},
			else => unreachable, // guaranteed by isExpandableShort
		}
	}
	return false;
}

/// Pre-expand short-flag clusters / attached args into individual tokens so the
/// normal per-flag parser handles them (e.g. "-td3" => "-t" "-d" "3"). Respects
/// the POSIX `--` end-of-options marker and path flags (`--path`/`-p` and
/// localized aliases), which take their following token verbatim — so a
/// flag-like operand is never mistakenly expanded. Returns `argv` unchanged (no
/// allocation) when there is nothing to expand. Allocated with `allocator`
/// (arena in main, so no explicit free).
fn expandShortFlagClusters(allocator: std.mem.Allocator, argv: []const [:0]const u8) ![]const [:0]const u8 {
	var any = false;
	for (argv) |tok| {
		if (isExpandableShort(tok)) {
			any = true;
			break;
		}
	}
	if (!any) return argv;
	var out: std.ArrayListUnmanaged([:0]const u8) = .empty;
	errdefer out.deinit(allocator);
	var i: usize = 0;
	var after_ddash = false;
	while (i < argv.len) : (i += 1) {
		const tok = argv[i];
		if (after_ddash) {
			try out.append(allocator, tok);
			continue;
		}
		if (std.mem.eql(u8, tok, "--")) {
			try out.append(allocator, tok);
			after_ddash = true;
			continue;
		}
		// A long path flag (--path or a localized alias) takes the next token
		// verbatim as a path; pass that operand through unexpanded.
		if (i18n.matchLongFlag(tok)) |a| {
			if (a == .path) {
				try out.append(allocator, tok);
				if (i + 1 < argv.len) {
					i += 1;
					try out.append(allocator, argv[i]);
				}
				continue;
			}
		}
		if (isExpandableShort(tok)) {
			const consumes_path = try expandOneShort(allocator, tok, &out);
			if (consumes_path and i + 1 < argv.len) {
				i += 1;
				try out.append(allocator, argv[i]); // verbatim path after -p
			}
			continue;
		}
		try out.append(allocator, tok);
	}
	return out.toOwnedSlice(allocator);
}

pub fn parseArgs(allocator: std.mem.Allocator, raw_args: []const [:0]const u8) ParseResult {
	var config = CliConfig{};

	// First pass: set locale from --lang or environment
	applyLangArg(raw_args);

	const s = i18n.tr();

	// Detect TTY
	config.stdout_is_tty = detectTty();

	// Check environment variables
	applyEnvVars(&config);

	// Skip program name
	const args = if (raw_args.len > 0) raw_args[1..] else raw_args;

	// Validate --lang up front so an invalid code is a hard error even when
	// --help (or any other short-circuiting flag) is also present. The main
	// option loop below would otherwise return .help before ever reaching the
	// --lang token, silently showing untranslated English help.
	{
		var li: usize = 0;
		while (li < args.len) : (li += 1) {
			if (std.mem.eql(u8, args[li], "--lang") or i18n.isFlag(args[li], .lang)) {
				const bad: []const u8 = if (li + 1 < args.len) args[li + 1] else "";
				if (li + 1 >= args.len or i18n.parseLocaleCode(bad) == null) {
					config.deinit(allocator);
					var err_buf: [256]u8 = undefined;
					const msg = i18n.fmtRuntime(&err_buf, s.err_unknown_lang, &.{ bad, i18n.available_codes });
					@memcpy(lang_err_buf[0..msg.len], msg);
					return .{ .err = lang_err_buf[0..msg.len] };
				}
				break;
			}
		}
	}

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

	// Subcommands: orphaned-notes / purge-orphaned-notes (and localized variants).
	// Both take an optional directory argument (default: current directory).
	if (args.len > 0) {
		if (i18n.matchLongFlag(args[0])) |maybe_arg| {
			switch (maybe_arg) {
				.orphaned_notes, .purge_orphaned_notes => {
					const dir: []const u8 = if (args.len >= 2) args[1] else ".";
					const oa = OrphanArgs{ .dir = dir };
					config.deinit(allocator);
					return if (maybe_arg == .orphaned_notes)
						ParseResult{ .orphaned_notes = oa }
					else
						ParseResult{ .purge_orphaned_notes = oa };
				},
				else => {},
			}
		}
	}

	var i: usize = 0;
	var dir_pending = true;

	while (i < args.len) {
		const arg = args[i];

		// Short flags (fixed, not localized)
		if (std.mem.eql(u8, arg, "-h")) {
			config.deinit(allocator);
			return .help;
		}
		if (std.mem.eql(u8, arg, "-a")) {
			config.deinit(allocator);
			return .about;
		}
		if (std.mem.eql(u8, arg, "-t")) {
			config.temporary = true;
			i += 1;
			continue;
		}

		// End-of-options marker: everything after `--` is an operand, never a
		// flag or subcommand (POSIX convention). dirtree's operand is the path,
		// so the token after `--` is taken verbatim as the directory. A bare
		// `--` simply ends option parsing and falls back to the default path.
		if (std.mem.eql(u8, arg, "--")) {
			i += 1;
			if (i < args.len) {
				config.dir = args[i];
				dir_pending = false;
			}
			break;
		}

		// Long flags via i18n alias map
		if (arg.len > 1 and arg[0] == '-' and arg[1] == '-') {
			if (i18n.matchLongFlag(arg)) |cli_arg| {
				switch (cli_arg) {
					.annotate => {
						// annotate is a positional subcommand, not a flag.
						// It is dispatched before this loop runs. If it appears
						// here (e.g., as --annotate), treat as unknown option.
						config.deinit(allocator);
						return .{ .err = s.err_unknown_option };
					},
					.orphaned_notes, .purge_orphaned_notes => {
						// Positional subcommands, dispatched before this loop; if they
						// appear here as a flag, treat as an unknown option.
						config.deinit(allocator);
						return .{ .err = s.err_unknown_option };
					},
					.help => {
						config.deinit(allocator);
						return .help;
					},
					.about => {
						config.deinit(allocator);
						return .about;
					},
					.@"test" => {
						config.deinit(allocator);
						return .test_mode;
					},
					.version => {
						config.deinit(allocator);
						return .version;
					},
					.version_check => {
						config.deinit(allocator);
						return .version_check;
					},
					.lang => {
						// Already handled in first pass; skip the value
						i += 1;
						if (i < args.len) {
							// Validate the lang code in second pass for error reporting
							if (i18n.parseLocaleCode(args[i]) == null) {
								config.deinit(allocator);
								var err_buf: [256]u8 = undefined;
								const msg = i18n.fmtRuntime(&err_buf, s.err_unknown_lang, &.{ args[i], i18n.available_codes });
								// Copy to static buffer since err_buf is stack-local
								@memcpy(lang_err_buf[0..msg.len], msg);
								return .{ .err = lang_err_buf[0..msg.len] };
							}
						}
						i += 1;
						continue;
					},
					.path => {
						// Consume the NEXT token verbatim as the target path, even if it
						// looks like a flag or subcommand (e.g. a dir named '--config' or
						// 'annotate', or even '--path' itself).
						i += 1;
						if (i >= args.len) {
							config.deinit(allocator);
							return .{ .err = s.err_path_requires_arg };
						}
						config.dir = args[i];
						dir_pending = false;
						i += 1;
						continue;
					},
					.depth => {
						i += 1;
						if (i >= args.len) {
							config.deinit(allocator);
							return .{ .err = s.err_depth_requires_number };
						}
						const depth_str = args[i];
						const depth = std.fmt.parseInt(u32, depth_str, 10) catch {
							config.deinit(allocator);
							return .{ .err = s.err_depth_requires_number };
						};
						config.depth = depth;
						config.state_modified = true;
						i += 1;
						continue;
					},
					.simple => {
						config.simple_mode = true;
						i += 1;
						continue;
					},
					.decorated => {
						config.force_decorated = true;
						i += 1;
						continue;
					},
					.no_icons => {
						config.no_icons = true;
						i += 1;
						continue;
					},
					.no_color => {
						config.no_color = true;
						config.state_modified = true;
						i += 1;
						continue;
					},
					.color => {
						config.color = true;
						config.state_modified = true;
						i += 1;
						continue;
					},
					.no_orphan_warning => {
						// Display-only suppression; never persisted to the state file.
						config.no_orphan_warning = true;
						i += 1;
						continue;
					},
					.no_notes => {
						config.cli_notes = false;
						i += 1;
						continue;
					},
					.show_notes => {
						config.cli_notes = true;
						i += 1;
						continue;
					},
					.notes => {
						i += 1;
						if (i >= args.len) {
							config.deinit(allocator);
							return .{ .err = s.err_notes_requires_mode };
						}
						const mode = args[i];
						if (std.mem.eql(u8, mode, "inline")) {
							config.notes_inline = true;
						} else if (std.mem.eql(u8, mode, "aligned")) {
							config.notes_inline = false;
						} else {
							config.deinit(allocator);
							return .{ .err = s.err_notes_requires_mode };
						}
						i += 1;
						continue;
					},
					.note_leader => {
						config.note_leader = true;
						i += 1;
						continue;
					},
					.no_hyperlinks => {
						config.no_hyperlinks = true;
						config.state_modified = true;
						i += 1;
						continue;
					},
					.hyperlinks => {
						config.hyperlinks = true;
						config.state_modified = true;
						i += 1;
						continue;
					},
					.temporary => {
						config.temporary = true;
						i += 1;
						continue;
					},
					.show_hidden => {
						config.show_hidden = true;
						i += 1;
						continue;
					},
					.rewrite_settings => {
						config.rewrite_settings = true;
						i += 1;
						continue;
					},
					.config => {
						config.show_config = true;
						i += 1;
						continue;
					},
					.max_lines => {
						i += 1;
						if (i >= args.len) {
							config.deinit(allocator);
							return .{ .err = s.err_max_lines_requires_number };
						}
						const ml_str = args[i];
						const ml = std.fmt.parseInt(u32, ml_str, 10) catch {
							config.deinit(allocator);
							return .{ .err = s.err_max_lines_requires_number };
						};
						config.max_lines = ml;
						config.state_modified = true;
						i += 1;
						continue;
					},
					.override_warning => {
						config.override_warning = true;
						i += 1;
						continue;
					},
					.only => {
						i += 1;
						if (i >= args.len) {
							config.deinit(allocator);
							return .{ .err = s.err_only_requires_path };
						}
						var only_path: []const u8 = args[i];
						// Strip trailing slashes
						while (only_path.len > 0 and only_path[only_path.len - 1] == '/') {
							only_path = only_path[0 .. only_path.len - 1];
						}
						// Strip leading slashes (relative paths only)
						while (only_path.len > 0 and only_path[0] == '/') {
							only_path = only_path[1..];
						}
						if (only_path.len > 0) {
							config.only_paths.append(allocator, only_path) catch {
								config.deinit(allocator);
								return .{ .err = s.err_only_requires_path };
							};
						}
						i += 1;
						continue;
					},
					.asc => {
						config.sort_direction = .asc;
						config.state_modified = true;
						i += 1;
						continue;
					},
					.desc => {
						config.sort_direction = .desc;
						config.state_modified = true;
						i += 1;
						continue;
					},
					.sort => {
						i += 1;
						if (i >= args.len) {
							config.deinit(allocator);
							return .{ .err = s.err_sort_requires_mode };
						}
						const mode_str = args[i];
						if (std.mem.eql(u8, mode_str, "modified")) {
							config.sort_mode = .modified;
						} else if (std.mem.eql(u8, mode_str, "alpha")) {
							config.sort_mode = .alpha;
						} else {
							config.deinit(allocator);
							return .{ .err = s.err_sort_requires_mode };
						}
						config.state_modified = true;
						i += 1;
						continue;
					},
					.default => {
						i += 1;
						const result = collectDefaultArgs(args[i..], &config);
						switch (result) {
							.ok => |count| {
								if (count == 0) {
									config.deinit(allocator);
									return .{ .err = s.err_default_requires_value };
								}
								i += count;
								config.state_modified = true;
								continue;
							},
							.err => |msg| {
								config.deinit(allocator);
								return .{ .err = msg };
							},
						}
					},
					.open => {
						i += 1;
						const result = collectVariadicArgs(allocator, args[i..], &config.open_literals, &config.open_regexes, dir_pending, null, "open");
						switch (result) {
							.ok => |count| {
								if (count == 0) {
									config.deinit(allocator);
									return .{ .err = s.err_open_requires_dir };
								}
								i += count;
								config.state_modified = true;
								continue;
							},
							.err => |msg| {
								config.deinit(allocator);
								return .{ .err = msg };
							},
						}
					},
					.close => {
						i += 1;
						const result = collectVariadicArgs(allocator, args[i..], &config.close_literals, &config.close_regexes, dir_pending, null, "close");
						switch (result) {
							.ok => |count| {
								if (count == 0) {
									config.deinit(allocator);
									return .{ .err = s.err_close_requires_dir };
								}
								i += count;
								config.state_modified = true;
								continue;
							},
							.err => |msg| {
								config.deinit(allocator);
								return .{ .err = msg };
							},
						}
					},
					.show => {
						i += 1;
						const result = collectVariadicArgs(allocator, args[i..], &config.show_literals, &config.show_regexes, dir_pending, .reject_absolute, "--show");
						switch (result) {
							.ok => |count| {
								if (count == 0) {
									config.deinit(allocator);
									return .{ .err = s.err_show_requires_path };
								}
								i += count;
								config.state_modified = true;
								continue;
							},
							.err => |msg| {
								config.deinit(allocator);
								return .{ .err = msg };
							},
						}
					},
					.hide => {
						i += 1;
						const result = collectVariadicArgs(allocator, args[i..], &config.hide_literals, &config.hide_regexes, dir_pending, .reject_absolute, "--hide");
						switch (result) {
							.ok => |count| {
								if (count == 0) {
									config.deinit(allocator);
									return .{ .err = s.err_hide_requires_path };
								}
								i += count;
								config.state_modified = true;
								continue;
							},
							.err => |msg| {
								config.deinit(allocator);
								return .{ .err = msg };
							},
						}
					},
				}
			}
		}

		// Short flags with value args (fixed, not localized)
		if (std.mem.eql(u8, arg, "-p")) {
			i += 1;
			if (i >= args.len) {
				config.deinit(allocator);
				return .{ .err = s.err_path_requires_arg };
			}
			config.dir = args[i];
			dir_pending = false;
			i += 1;
			continue;
		}
		if (std.mem.eql(u8, arg, "-d")) {
			i += 1;
			if (i >= args.len) {
				config.deinit(allocator);
				return .{ .err = s.err_depth_requires_number };
			}
			const depth_str = args[i];
			const depth = std.fmt.parseInt(u32, depth_str, 10) catch {
				config.deinit(allocator);
				return .{ .err = s.err_depth_requires_number };
			};
			config.depth = depth;
			config.state_modified = true;
			i += 1;
			continue;
		}

		if (std.mem.eql(u8, arg, "-o")) {
			i += 1;
			const result = collectVariadicArgs(allocator, args[i..], &config.open_literals, &config.open_regexes, dir_pending, null, "open");
			switch (result) {
				.ok => |count| {
					if (count == 0) {
						config.deinit(allocator);
						return .{ .err = s.err_open_requires_dir };
					}
					i += count;
					config.state_modified = true;
					continue;
				},
				.err => |msg| {
					config.deinit(allocator);
					return .{ .err = msg };
				},
			}
		}

		if (std.mem.eql(u8, arg, "-c")) {
			i += 1;
			const result = collectVariadicArgs(allocator, args[i..], &config.close_literals, &config.close_regexes, dir_pending, null, "close");
			switch (result) {
				.ok => |count| {
					if (count == 0) {
						config.deinit(allocator);
						return .{ .err = s.err_close_requires_dir };
					}
					i += count;
					config.state_modified = true;
					continue;
				},
				.err => |msg| {
					config.deinit(allocator);
					return .{ .err = msg };
				},
			}
		}

		// Unknown flag
		if (arg.len > 0 and arg[0] == '-') {
			config.deinit(allocator);
			return .{ .err = s.err_unknown_option };
		}

		// Directory argument
		config.dir = arg;
		dir_pending = false;
		i += 1;
		break;
	}

	return .{ .config = config };
}

// Static buffer for --lang error messages (must outlive parseArgs return)
var lang_err_buf: [256]u8 = undefined;

const PathValidation = enum {
	reject_absolute,
};

const VariadicResult = union(enum) {
	ok: usize,
	err: []const u8,
};

// Static buffer for formatting error messages in collectVariadicArgs
var abs_path_err_buf: [256]u8 = undefined;

fn collectVariadicArgs(
	allocator: std.mem.Allocator,
	args: []const [:0]const u8,
	literals: *std.ArrayListUnmanaged([]const u8),
	regexes: *std.ArrayListUnmanaged(ArgEntry),
	dir_pending: bool,
	path_validation: ?PathValidation,
	flag_name: []const u8,
) VariadicResult {
	const s = i18n.tr();
	var count: usize = 0;

	for (args) |token| {
		// Stop at next flag
		if (token.len > 0 and token[0] == '-') break;

		// If dir_pending and this is the last remaining arg after we've collected some,
		// it might be the directory argument - stop collecting
		if (dir_pending and count > 0 and args.len - count == 1) {
			break;
		}

		// Try to parse as wrapped regex
		const parsed = regex.parseWrappedRegexToken(token) catch {
			return .{ .err = s.err_regex_empty };
		};

		if (parsed) |p| {
			regexes.append(allocator, .{
				.value = p.pattern,
				.kind = .regex,
				.negated = p.negated,
			}) catch return .{ .err = s.err_out_of_memory };
			count += 1;
			continue;
		}

		// Check for absolute path rejection
		if (path_validation) |pv| {
			switch (pv) {
				.reject_absolute => {
					if (token.len > 0 and token[0] == '/') {
						const msg = i18n.fmtRuntime(&abs_path_err_buf, s.err_paths_must_be_relative, &.{ flag_name, token });
						return .{ .err = msg };
					}
				},
			}
		}

		// Try as glob - store as glob kind (deferred conversion to regex at eval time)
		if (regex.isGlobPattern(token)) {
			regexes.append(allocator, .{
				.value = token,
				.kind = .glob,
				.negated = false,
			}) catch return .{ .err = s.err_out_of_memory };
			count += 1;
			continue;
		}

		// Treat as literal
		literals.append(allocator, token) catch return .{ .err = s.err_out_of_memory };
		count += 1;
	}

	return .{ .ok = count };
}

const DefaultArgResult = union(enum) {
	ok: usize,
	err: []const u8,
};

/// Valid tokens for --default argument
const default_tokens = [_][]const u8{
	"open", "opened", "close", "closed",
};

fn isDefaultToken(token: []const u8) bool {
	for (&default_tokens) |dt| {
		if (std.ascii.eqlIgnoreCase(token, dt)) return true;
	}
	return false;
}

fn collectDefaultArgs(args: []const [:0]const u8, config: *CliConfig) DefaultArgResult {
	const s = i18n.tr();
	var count: usize = 0;

	for (args) |token| {
		// Stop at next flag
		if (token.len > 0 and token[0] == '-') break;

		if (!isDefaultToken(token)) break;

		// Parse the default token
		if (std.ascii.eqlIgnoreCase(token, "open") or std.ascii.eqlIgnoreCase(token, "opened")) {
			if (config.default_state != null and config.default_state.? != .opened) {
				return .{ .err = s.err_default_state_conflict };
			}
			config.default_state = .opened;
		} else if (std.ascii.eqlIgnoreCase(token, "close") or std.ascii.eqlIgnoreCase(token, "closed")) {
			if (config.default_state != null and config.default_state.? != .closed) {
				return .{ .err = s.err_default_state_conflict };
			}
			config.default_state = .closed;
		} else {
			return .{ .err = s.err_default_accepts };
		}

		count += 1;
	}

	return .{ .ok = count };
}

fn detectTty() bool {
	// Check PIPED_STDOUT env var first (all locale aliases)
	if (i18n.getEnvLocalized(.piped_stdout)) |val| {
		// PIPED_STDOUT truthy => treat as piped; falsy => treat as TTY.
		if (state_mod.parseBool(val)) |piped| return !piped;
	}
	return std.Io.File.stdout().isTty(runtime.io()) catch false;
}

fn applyEnvVars(config: *CliConfig) void {
	if (i18n.getEnvLocalized(.dirtree_simple)) |val| {
		if (isTruthyEnv(val)) config.simple_mode = true;
	}
	if (i18n.getEnvLocalized(.dirtree_decorated)) |val| {
		if (isTruthyEnv(val)) config.force_decorated = true;
	}
	if (i18n.getEnvLocalized(.dirtree_auto_simple)) |val| {
		if (isTruthyEnv(val) and !config.stdout_is_tty) {
			config.simple_mode = true;
		}
	}
	if (i18n.getEnvLocalized(.dirtree_hide_notes)) |val| {
		if (isTruthyEnv(val)) config.cli_notes = false;
	}
	if (i18n.getEnvLocalized(.dirtree_temp)) |val| {
		if (isTruthyEnv(val)) config.temporary = true;
	}
}

fn isTruthyEnv(val: []const u8) bool {
	return state_mod.parseBool(val) orelse false;
}

/// One help option/subcommand row for the rendered Options table.
const HelpRow = struct {
	flag: []const u8, // canonical English flag column (language-independent)
	text: []const u8, // localized full help line (description source)
	args: []const i18n.CliArg, // CliArg(s) whose localized aliases to show
	subcmd: bool = false, // leading token is a subcommand word (e.g. "annotate")
};

/// Count placeholder tokens in a canonical flagspec: space-separated tokens
/// that are not '-'-prefixed flags (and not the leading subcommand word).
/// e.g. "-p, --path PATH" -> 1, "annotate PATH DESC" (subcmd) -> 2, "--asc" -> 0.
fn placeholderCount(flag: []const u8, subcmd: bool) usize {
	var n: usize = 0;
	var first = true;
	var it = std.mem.tokenizeScalar(u8, flag, ' ');
	while (it.next()) |tok| {
		const is_subcmd_word = first and subcmd;
		first = false;
		if (is_subcmd_word) continue;
		if (tok.len > 0 and tok[0] != '-') n += 1;
	}
	return n;
}

/// Extract the localized description from a full help line. Skips the indent,
/// an optional leading subcommand word, the '-'-prefixed flag tokens, and
/// exactly `placeholderCount` placeholder slots. Consuming a fixed number of
/// placeholder tokens (rather than greedily) means a description that itself
/// opens with a placeholder reference (e.g. German "PATH rendern ...") keeps
/// that word.
fn helpDesc(line: []const u8, flag: []const u8, subcmd: bool) []const u8 {
	const nph = placeholderCount(flag, subcmd);
	var i: usize = 0;
	while (i < line.len and line[i] == ' ') i += 1;
	if (subcmd) {
		while (i < line.len and line[i] != ' ') i += 1; // skip subcommand word
		while (i < line.len and line[i] == ' ') i += 1;
	}
	// consume '-'-prefixed flag tokens
	while (i < line.len and line[i] == '-') {
		while (i < line.len and line[i] != ' ') i += 1;
		while (i < line.len and line[i] == ' ') i += 1;
	}
	// consume exactly `nph` placeholder slots
	var consumed: usize = 0;
	while (consumed < nph and i < line.len) : (consumed += 1) {
		while (i < line.len and line[i] != ' ') i += 1;
		while (i < line.len and line[i] == ' ') i += 1;
	}
	return line[i..];
}

/// Join the localized CLI aliases for the given args into `buf`, comma-separated.
/// Returns an empty slice for the English locale (its aliases are the canonical
/// names, already shown in the flag column).
fn joinLocalizedAliases(args: []const i18n.CliArg, buf: []u8) []const u8 {
	if (i18n.getLocale() == .en) return "";
	var n: usize = 0;
	for (i18n.localeCliAliases(i18n.getLocale())) |entry| {
		for (args) |a| {
			if (entry.arg != a) continue;
			if (n + 2 + entry.name.len > buf.len) break;
			if (n > 0) {
				buf[n] = ',';
				buf[n + 1] = ' ';
				n += 2;
			}
			@memcpy(buf[n .. n + entry.name.len], entry.name);
			n += entry.name.len;
		}
	}
	return buf[0..n];
}

fn writeSpaces(writer: anytype, n: usize) !void {
	var k: usize = 0;
	while (k < n) : (k += 1) try writer.writeAll(" ");
}

/// Pad after writing a column value of width `used` to fill a field of `field`
/// columns, always leaving at least one separating space on overflow.
fn writeColumnPad(writer: anytype, used: usize, field: usize) !void {
	try writeSpaces(writer, if (field > used) field - used else 1);
}

/// Write one example line: "  <cmd>" padded so the comment '#' aligns near col 32.
fn writeExample(writer: anytype, cmd: []const u8, comment: []const u8) !void {
	try writer.writeAll("  ");
	try writer.writeAll(cmd);
	try writeColumnPad(writer, cmd.len, 30);
	try writer.writeAll("# ");
	try writer.writeAll(comment);
	try writer.writeAll("\n");
}

/// Write the Options section. English keeps its hand-tuned two-column layout;
/// other locales gain a middle column of localized aliases between the English
/// flag name and the localized description. All locales list the available
/// language codes beneath the --lang entry.
fn writeOptions(writer: anytype, s: *const i18n.Strings) !void {
	const rows = [_]HelpRow{
		.{ .flag = "-h, --help", .text = s.help_opt_help, .args = &[_]i18n.CliArg{.help} },
		.{ .flag = "-a, --about", .text = s.help_opt_about, .args = &[_]i18n.CliArg{.about} },
		.{ .flag = "-d, --depth N", .text = s.help_opt_depth, .args = &[_]i18n.CliArg{.depth} },
		.{ .flag = "-t, --temp", .text = s.help_opt_temp, .args = &[_]i18n.CliArg{.temporary} },
		.{ .flag = "-p, --path PATH", .text = s.help_opt_path, .args = &[_]i18n.CliArg{.path} },
		.{ .flag = "--simple", .text = s.help_opt_simple, .args = &[_]i18n.CliArg{.simple} },
		.{ .flag = "--decorated", .text = s.help_opt_decorated, .args = &[_]i18n.CliArg{.decorated} },
		.{ .flag = "--no-icons", .text = s.help_opt_no_icons, .args = &[_]i18n.CliArg{.no_icons} },
		.{ .flag = "--no-color/--color", .text = s.help_opt_no_color, .args = &[_]i18n.CliArg{ .no_color, .color } },
		.{ .flag = "--no-orphan-warning", .text = s.help_opt_no_orphan_warning, .args = &[_]i18n.CliArg{.no_orphan_warning} },
		.{ .flag = "--no-notes/--show-notes", .text = s.help_opt_notes, .args = &[_]i18n.CliArg{ .no_notes, .show_notes } },
		.{ .flag = "--notes MODE", .text = s.help_opt_notes_mode, .args = &[_]i18n.CliArg{.notes} },
		.{ .flag = "--notes-leader", .text = s.help_opt_notes_leader, .args = &[_]i18n.CliArg{.note_leader} },
		.{ .flag = "--no-hyperlinks/--hyperlinks", .text = s.help_opt_no_hyperlinks, .args = &[_]i18n.CliArg{ .no_hyperlinks, .hyperlinks } },
		.{ .flag = "--default X", .text = s.help_opt_default, .args = &[_]i18n.CliArg{.default} },
		.{ .flag = "-o, --open DIR...", .text = s.help_opt_open, .args = &[_]i18n.CliArg{.open} },
		.{ .flag = "-c, --close DIR...", .text = s.help_opt_close, .args = &[_]i18n.CliArg{.close} },
		.{ .flag = "--show PATH...", .text = s.help_opt_show, .args = &[_]i18n.CliArg{.show} },
		.{ .flag = "--hide PATH...", .text = s.help_opt_hide, .args = &[_]i18n.CliArg{.hide} },
		.{ .flag = "--sort MODE", .text = s.help_opt_sort, .args = &[_]i18n.CliArg{.sort} },
		.{ .flag = "--asc", .text = s.help_opt_asc, .args = &[_]i18n.CliArg{.asc} },
		.{ .flag = "--desc", .text = s.help_opt_desc, .args = &[_]i18n.CliArg{.desc} },
		.{ .flag = "--show-hidden", .text = s.help_opt_show_hidden, .args = &[_]i18n.CliArg{.show_hidden} },
		.{ .flag = "--rewrite-settings", .text = s.help_opt_rewrite_settings, .args = &[_]i18n.CliArg{.rewrite_settings} },
		.{ .flag = "--config", .text = s.help_opt_config, .args = &[_]i18n.CliArg{.config} },
		.{ .flag = "--test", .text = s.help_opt_test, .args = &[_]i18n.CliArg{.@"test"} },
		.{ .flag = "--lang CODE", .text = s.help_opt_lang, .args = &[_]i18n.CliArg{.lang} },
		.{ .flag = "--max-lines N", .text = s.help_opt_max_lines, .args = &[_]i18n.CliArg{.max_lines} },
		.{ .flag = "--override-warning", .text = s.help_opt_override_warning, .args = &[_]i18n.CliArg{.override_warning} },
		.{ .flag = "--only PATH", .text = s.help_opt_only, .args = &[_]i18n.CliArg{.only} },
		.{ .flag = "annotate PATH DESC", .text = s.help_opt_annotate, .args = &[_]i18n.CliArg{.annotate}, .subcmd = true },
		.{ .flag = "orphaned-notes [DIR]", .text = s.help_opt_orphaned_notes, .args = &[_]i18n.CliArg{.orphaned_notes}, .subcmd = true },
		.{ .flag = "purge-orphaned-notes [DIR]", .text = s.help_opt_purge_orphaned_notes, .args = &[_]i18n.CliArg{.purge_orphaned_notes}, .subcmd = true },
		.{ .flag = "--version", .text = s.help_opt_version, .args = &[_]i18n.CliArg{.version} },
		.{ .flag = "--version-check", .text = s.help_opt_version_check, .args = &[_]i18n.CliArg{.version_check} },
	};

	const is_lang = struct {
		fn f(row: HelpRow) bool {
			return row.args.len == 1 and row.args[0] == .lang;
		}
	}.f;

	if (i18n.getLocale() == .en) {
		// Preserve the hand-tuned English layout verbatim.
		for (rows) |row| {
			try writer.writeAll(row.text);
			try writer.writeAll("\n");
			if (is_lang(row)) {
				try writeSpaces(writer, 21); // align under the description column
				try writer.writeAll(s.help_lang_available_label);
				try writer.writeAll(" ");
				try writer.writeAll(i18n.available_codes);
				try writer.writeAll("\n");
			}
		}
		try writer.writeAll("\n");
		return;
	}

	// Non-English: render three columns (English flag | localized aliases | desc).
	var alias_store: [rows.len][192]u8 = undefined;
	var alias: [rows.len][]const u8 = undefined;
	var w_flag: usize = 0;
	var w_alias: usize = 0;
	for (rows, 0..) |row, idx| {
		alias[idx] = joinLocalizedAliases(row.args, &alias_store[idx]);
		if (row.flag.len > w_flag) w_flag = row.flag.len;
		if (alias[idx].len > w_alias) w_alias = alias[idx].len;
	}
	const col_flag = w_flag + 2;
	const col_alias: usize = if (w_alias > 0) w_alias + 2 else 0;

	for (rows, 0..) |row, idx| {
		try writer.writeAll("  ");
		try writer.writeAll(row.flag);
		try writeColumnPad(writer, row.flag.len, col_flag);
		if (col_alias > 0) {
			try writer.writeAll(alias[idx]);
			try writeColumnPad(writer, alias[idx].len, col_alias);
		}
		try writer.writeAll(helpDesc(row.text, row.flag, row.subcmd));
		try writer.writeAll("\n");
		if (is_lang(row)) {
			try writeSpaces(writer, 2 + col_flag + col_alias);
			try writer.writeAll(s.help_lang_available_label);
			try writer.writeAll(" ");
			try writer.writeAll(i18n.available_codes);
			try writer.writeAll("\n");
		}
	}
	try writer.writeAll("\n");
}


pub fn printHelp(writer: anytype) !void {
	const s = i18n.tr();
	try writer.writeAll(s.help_title);
	try writer.writeAll("\n\n");
	try writer.writeAll(s.help_usage);
	try writer.writeAll("\n\n");
	try writer.writeAll(s.help_options_header);
	try writer.writeAll("\n");
	try writeOptions(writer, s);
	try writer.writeAll(s.help_regex_note);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_relative_note);
	try writer.writeAll("\n\n");
	try writer.writeAll(s.help_behavior_header);
	try writer.writeAll(" ");
	try writer.writeAll(s.help_behavior_text);
	try writer.writeAll("\n\n");
	try writer.writeAll(s.help_examples_header);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_example_1);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_example_2);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_example_3);
	try writer.writeAll("\n");
	// Item 2: additional examples (commands fixed; comments localized).
	try writeExample(writer, "dirtree --close vendor", s.help_example_close_comment);
	try writeExample(writer, "dirtree --hide '/\\.log$/'", s.help_example_hide_comment);
	try writeExample(writer, "dirtree --only src", s.help_example_only_comment);
	{
		const dep = i18n.localizedFlagName(.depth);
		const showcase = if (std.mem.eql(u8, dep, "--depth")) "--tiefe" else dep;
		var cmd_buf: [96]u8 = undefined;
		const cmd = std.fmt.bufPrint(&cmd_buf, "dirtree {s} 2", .{showcase}) catch "dirtree --tiefe 2";
		try writeExample(writer, cmd, s.help_example_localized_comment);
	}
}

pub fn main(init: std.process.Init) !u8 {
	// Initialize process-wide runtime context (io + env) for all modules.
	runtime.init(init.io, init.environ_map);
	const io = init.io;

	var stdout_buf: [4096]u8 = undefined;
	var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buf);
	const stdout = &stdout_writer.interface;

	var stderr_buf: [4096]u8 = undefined;
	var stderr_writer = std.Io.File.stderr().writer(io, &stderr_buf);
	const stderr = &stderr_writer.interface;

	// Warn if running an unoptimized debug build
	if (comptime @import("builtin").mode == .Debug) {
		try stderr.writeAll(ansi_mod.yellow ++ "DEBUG BUILD" ++ ansi_mod.reset ++ "\n");
		try stderr.flush();
	}

	const arena = init.arena;
	const allocator = arena.allocator();
	const raw_args = try init.minimal.args.toSlice(allocator);
	// No need for argsFree - arena handles cleanup

	// Expand getopt-style short-flag clusters (e.g. "-td 3" => "-t" "-d" "3").
	const expanded_args = expandShortFlagClusters(allocator, raw_args) catch raw_args;
	const result = parseArgs(allocator, expanded_args);

	switch (result) {
		.help => {
			try printHelp(stdout);
			try stdout.flush();
			return 0;
		},
		.about => {
			const s = i18n.tr();
			try stdout.writeAll(s.about_text);
			try stdout.writeAll("\n");
			try stdout.flush();
			return 0;
		},
		.version => {
			try printVersionLine(stdout);
			try emitCachedUpdateNotice(allocator, stdout);
			try stdout.flush();
			return 0;
		},
		.version_check => {
			try printVersionLine(stdout);
			const exit = try runVersionCheck(allocator, stdout, stderr);
			try stdout.flush();
			try stderr.flush();
			return exit;
		},
		.test_mode => {
			const s = i18n.tr();
			// Check for DIRTREE_TEST_BIN to run external test binary
			const test_bin = runtime.getEnv("DIRTREE_TEST_BIN");
			if (test_bin) |bin| {
				const argv: []const []const u8 = &.{bin};
				var child = std.process.spawn(io, .{
					.argv = argv,
					.stdin = .inherit,
					.stdout = .inherit,
					.stderr = .inherit,
				}) catch {
					var err_buf: [512]u8 = undefined;
					const msg = i18n.fmtRuntime(&err_buf, s.err_test_bin_run, &.{bin});
					try stderr.writeAll(msg);
					try stderr.writeAll("\n");
					try stderr.flush();
					return 1;
				};
				const term = child.wait(io) catch {
					try stderr.writeAll(s.err_test_bin_wait);
					try stderr.writeAll("\n");
					try stderr.flush();
					return 1;
				};
				return switch (term) {
					.exited => |code| code,
					else => 1,
				};
			}
			try stderr.writeAll(s.test_mode_msg);
			try stderr.writeAll("\n");
			try stderr.flush();
			return 0;
		},
		.err => |msg| {
			try stderr.writeAll(msg);
			try stderr.writeAll("\n");
			try stderr.flush();
			return 1;
		},
		.annotate => |args2| {
			const s2 = i18n.tr();
			// Resolve target directory (CWD) to absolute
			const abs_dir = resolveAbsDir(allocator, ".") catch {
				var err_buf: [512]u8 = undefined;
				const msg = i18n.fmtRuntime(&err_buf, s2.err_not_a_directory, &.{"."});
				try stderr.writeAll(msg);
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
		.orphaned_notes => |oa| {
			return runOrphanedNotes(allocator, oa.dir, stdout, stderr, false) catch |err| {
				try stderr.print("Error: {s}\n", .{@errorName(err)});
				try stderr.flush();
				return 1;
			};
		},
		.purge_orphaned_notes => |oa| {
			return runOrphanedNotes(allocator, oa.dir, stdout, stderr, true) catch |err| {
				try stderr.print("Error: {s}\n", .{@errorName(err)});
				try stderr.flush();
				return 1;
			};
		},
		.config => |config| {
			const s = i18n.tr();
			var cfg = config;
			defer cfg.deinit(allocator);

			// Resolve the target directory to an absolute path
			const abs_dir = resolveAbsDir(allocator, cfg.dir) catch {
				var err_buf: [512]u8 = undefined;
				const msg = i18n.fmtRuntime(&err_buf, s.err_not_a_directory, &.{cfg.dir});
				try stderr.writeAll(msg);
				try stderr.writeAll("\n");
				try stderr.flush();
				return 1;
			};
			defer allocator.free(abs_dir);

			// Collect SCM priority paths
			var priority = scm_mod.collectPriorityPaths(allocator, abs_dir) catch
				scm_mod.PriorityPaths{ .allocator = allocator };
			defer priority.deinit();

			// Build effective state from state chain
			var effective = path_eval.buildEffectiveState(allocator, abs_dir) catch blk: {
				// If state loading fails, use empty state
				break :blk path_eval.EffectiveState{ .allocator = allocator };
			};
			defer effective.deinit();

			// Apply CLI overrides to effective state
			try applyCliOverrides(allocator, &cfg, &effective);

			// Fail loudly if any CLI or state-file regex pattern was invalid,
			// instead of silently rendering a tree that ignores it.
			if (effective.invalid_regex) |bad_pattern| {
				var err_buf: [512]u8 = undefined;
				const msg = i18n.fmtRuntime(&err_buf, s.err_regex_invalid, &.{bad_pattern});
				try stderr.writeAll(msg);
				try stderr.writeAll("\n");
				try stderr.flush();
				return 1;
			}

			// Warn about regex-negation foot-guns on --hide/--show (a negated
			// !/…/ or a leading (?!…) lookahead inverts the match; combining them
			// double-negates). Fires at add-time, when the rule is also persisted.
			{
				var neg_found = false;
				const verb_args = [_]i18n.CliArg{ .hide, .show };
				const lists = [_][]const ArgEntry{ cfg.hide_regexes.items, cfg.show_regexes.items };
				for (verb_args, lists) |verb_arg, list| {
					const verb = i18n.localizedFlagName(verb_arg);
					for (list) |re| {
						if (re.kind != .regex) continue;
						if (!isNegationFootgun(re.value, re.negated)) continue;
						if (!neg_found) {
							neg_found = true;
							if (!cfg.simple_mode) try stderr.writeAll(ansi_mod.dim_italic);
							try stderr.writeAll(s.warn_negation_intro);
							try stderr.writeAll("\n");
						}
						try stderr.print("  {s} {s}/{s}/\n", .{ verb, if (re.negated) "!" else "", re.value });
					}
				}
				if (neg_found) {
					var advice_buf: [1024]u8 = undefined;
					const advice = i18n.fmtRuntime(&advice_buf, s.warn_negation_advice, &.{ i18n.localizedFlagName(.only), i18n.localizedFlagName(.show) });
					try stderr.writeAll(advice);
					if (!cfg.simple_mode) try stderr.writeAll(ansi_mod.reset);
					try stderr.writeAll("\n");
					try stderr.flush();
				}
			}

			// --config: dump effective state and exit
			if (cfg.show_config) {
				// Also apply CLI sort/depth/defaults to effective for display
				if (cfg.sort_mode) |sm| {
					effective.sort_mode = switch (sm) {
						.modified => .modified,
						.alpha => .alpha,
					};
				}
				if (cfg.sort_direction) |sd| {
					effective.sort_direction = switch (sd) {
						.asc => .asc,
						.desc => .desc,
					};
				}
				if (cfg.depth) |d| {
					effective.depth = d;
				}
				path_eval.dumpEffectiveState(stdout, &effective) catch |err| {
					var err_buf2: [256]u8 = undefined;
					const err_msg = std.fmt.bufPrint(&err_buf2, "Error writing config: {}", .{err}) catch "Error writing config";
					try stderr.writeAll(err_msg);
					try stderr.writeAll("\n");
					try stderr.flush();
					return 1;
				};
				try stdout.flush();
				return 0;
			}

			// Check for regex conflicts (same pattern in both open+close)
			if (checkRegexConflict(allocator, &effective, abs_dir, stderr)) |conflict| {
				var err_buf: [512]u8 = undefined;
				var msg = i18n.fmtRuntime(&err_buf, s.err_regex_conflict_path, &.{conflict.path});
				try stderr.writeAll(msg);
				try stderr.writeAll("\n");
				msg = i18n.fmtRuntime(&err_buf, s.err_regex_conflict_open, &.{conflict.pattern});
				try stderr.writeAll(msg);
				try stderr.writeAll("\n");
				msg = i18n.fmtRuntime(&err_buf, s.err_regex_conflict_close, &.{conflict.pattern});
				try stderr.writeAll(msg);
				try stderr.writeAll("\n");
				try stderr.flush();
				allocator.free(conflict.path);
				return 1;
			}

			// Determine display mode
			const use_simple = cfg.simple_mode;
			const use_color = !use_simple and !cfg.no_color and
				(cfg.force_decorated or cfg.stdout_is_tty) and
				(effective.color_preference orelse true);
			const use_hyperlinks = !use_simple and !cfg.no_hyperlinks and
				(cfg.force_decorated or cfg.stdout_is_tty) and
				(effective.hyperlink_preference orelse true);
			const use_icons = !cfg.no_icons;

			// Determine sort
			const sort_mode: dir_scan.SortMode = blk: {
				if (cfg.sort_mode) |sm| break :blk switch (sm) {
					.modified => .modified,
					.alpha => .alpha,
				};
				if (effective.sort_mode) |sm| break :blk switch (sm) {
					.modified => .modified,
					.alpha => .alpha,
				};
				break :blk .modified;
			};
			const sort_direction: dir_scan.SortDirection = blk: {
				if (cfg.sort_direction) |sd| break :blk switch (sd) {
					.asc => .asc,
					.desc => .desc,
				};
				if (effective.sort_direction) |sd| break :blk switch (sd) {
					.asc => .asc,
					.desc => .desc,
				};
				break :blk .desc;
			};

			// Determine depth
			const max_depth = cfg.depth orelse effective.depth orelse tree_render.DEFAULT_DEPTH;

			const render_config = tree_render.RenderConfig{
				.use_color = use_color,
				.use_icons = use_icons,
				.use_hyperlinks = use_hyperlinks,
				.simple_mode = use_simple,
				.report_hidden = !cfg.show_hidden,
				.show_notes = cfg.cli_notes orelse true,
				.note_align = !cfg.notes_inline,
				.note_leader = cfg.note_leader,
				.note_column = effective.note_column orelse tree_render.DEFAULT_NOTE_COLUMN,
				.max_depth = max_depth,
				.show_hidden = cfg.show_hidden,
				.sort_mode = sort_mode,
				.sort_direction = sort_direction,
				.only_paths = cfg.only_paths.items,
			};

			// Persist state if modified
			if (!cfg.temporary and (cfg.state_modified or effective.needs_migration or cfg.rewrite_settings)) {
				persistState(allocator, abs_dir, &cfg, &effective) catch |err| {
					try stderr.print("Warning: could not persist state: {}\n", .{err});
					try stderr.flush();
				};
			}

			// Pre-scan warning for large output when piped
			if (!cfg.stdout_is_tty and !cfg.override_warning) {
				const threshold = effective.max_lines orelse tree_render.DEFAULT_MAX_LINES;
				const estimated = tree_render.countVisibleEntries(
					allocator,
					abs_dir,
					"",
					max_depth,
					false,
					&effective,
					if (priority.enabled) &priority.dirs else null,
					if (priority.enabled) &priority.files else null,
					cfg.show_hidden,
				);
				if (estimated + 1 > threshold) { // +1 for root header line
					const ws = i18n.tr();
					try stderr.writeAll("\n");
					if (!use_simple) try stderr.writeAll(ansi_mod.bold_yellow);
					try stderr.writeAll(ws.warn_large_output_prefix);
					try stderr.print("{}", .{estimated + 1});
					try stderr.writeAll(ws.warn_large_output_mid);
					try stderr.print("{}", .{threshold});
					try stderr.writeAll(ws.warn_large_output_suffix);
					if (!use_simple) try stderr.writeAll(ansi_mod.reset);
					try stderr.writeAll("\n");
				}
			}

			// Render the tree
			tree_render.renderTree(
				allocator,
				stdout,
				stderr,
				abs_dir,
				&effective,
				if (priority.enabled) &priority.dirs else null,
				if (priority.enabled) &priority.files else null,
				render_config,
			) catch |err| {
				try stderr.print("Error rendering tree: {}\n", .{err});
				try stderr.flush();
				return 1;
			};

			// Warn about orphaned annotations: notes in THIS directory's state file
			// that point at paths which no longer exist. Best-effort, current-dir scope.
			if (!cfg.no_orphan_warning) {
				var orphan_sf: state_mod.StateFile = .{ .allocator = allocator };
				defer orphan_sf.deinit();
				var orphans: std.ArrayListUnmanaged(usize) = .empty;
				defer orphans.deinit(allocator);
				scanOrphanedNotes(allocator, abs_dir, &orphan_sf, &orphans) catch {};
				if (orphans.items.len > 0) {
					const ws = i18n.tr();
					if (!use_simple) try stderr.writeAll(ansi_mod.bold_yellow);
					try stderr.writeAll(ws.warn_orphaned_prefix);
					try stderr.print("{}", .{orphans.items.len});
					try stderr.writeAll(ws.warn_orphaned_suffix);
					if (!use_simple) try stderr.writeAll(ansi_mod.reset);
					try stderr.writeAll("\n");
				}
			}

			try stdout.flush();
			try stderr.flush();
			return 0;
		},
	}
}

/// Resolve a directory path to an absolute path.
fn resolveAbsDir(allocator: std.mem.Allocator, dir: []const u8) ![]const u8 {
	const io = runtime.io();
	// If already absolute, use it directly
	if (dir.len > 0 and dir[0] == '/') {
		// Verify it's a directory
		var d = try std.Io.Dir.cwd().openDir(io, dir, .{});
		d.close(io);
		return try allocator.dupe(u8, dir);
	}

	// Resolve relative to cwd
	const cwd_z = try std.Io.Dir.cwd().realPathFileAlloc(io, ".", allocator);
	defer allocator.free(cwd_z);
	const cwd: []const u8 = cwd_z;

	if (std.mem.eql(u8, dir, ".")) {
		return try allocator.dupe(u8, cwd);
	}

	const abs = try std.fs.path.join(allocator, &.{ cwd, dir });
	errdefer allocator.free(abs);

	// Verify it's a directory
	var d = std.Io.Dir.cwd().openDir(io, abs, .{}) catch return error.NotADirectory;
	d.close(io);

	return abs;
}

/// Apply CLI overrides to the effective state.
fn applyCliOverrides(allocator: std.mem.Allocator, cfg: *const CliConfig, effective: *path_eval.EffectiveState) !void {
	// Apply CLI defaults
	if (cfg.default_state) |ds| {
		effective.default_state = switch (ds) {
			.opened => .opened,
			.closed => .closed,
		};
	}
	// Apply CLI open/close/show/hide literals
	for (cfg.open_literals.items) |lit| {
		const key = try effective.dupeStr(lit);
		try effective.open_literals.put(allocator, key, {});
		_ = effective.close_literals.fetchRemove(lit);
	}
	for (cfg.close_literals.items) |lit| {
		const key = try effective.dupeStr(lit);
		try effective.close_literals.put(allocator, key, {});
		_ = effective.open_literals.fetchRemove(lit);
	}
	for (cfg.show_literals.items) |lit| {
		const key = try effective.dupeStr(lit);
		try effective.show_literals.put(allocator, key, {});
		_ = effective.hide_literals.fetchRemove(lit);
	}
	for (cfg.hide_literals.items) |lit| {
		const key = try effective.dupeStr(lit);
		try effective.hide_literals.put(allocator, key, {});
		_ = effective.show_literals.fetchRemove(lit);
	}

	// Apply CLI open/close/show/hide regexes
	for (cfg.open_regexes.items) |re| {
		try addCliRegex(allocator, &effective.open_regexes, &effective.strings, re.value, re.negated, re.kind == .regex, &effective.invalid_regex);
	}
	for (cfg.close_regexes.items) |re| {
		try addCliRegex(allocator, &effective.close_regexes, &effective.strings, re.value, re.negated, re.kind == .regex, &effective.invalid_regex);
	}
	for (cfg.show_regexes.items) |re| {
		try addCliRegex(allocator, &effective.show_regexes, &effective.strings, re.value, re.negated, re.kind == .regex, &effective.invalid_regex);
	}
	for (cfg.hide_regexes.items) |re| {
		try addCliRegex(allocator, &effective.hide_regexes, &effective.strings, re.value, re.negated, re.kind == .regex, &effective.invalid_regex);
	}

	// Apply CLI color/hyperlink preferences
	if (cfg.no_color) {
		effective.color_preference = false;
	}
	if (cfg.color) {
		effective.color_preference = true;
	}
	if (cfg.no_hyperlinks) {
		effective.hyperlink_preference = false;
	}
	if (cfg.hyperlinks) {
		effective.hyperlink_preference = true;
	}

	// Apply CLI max_lines
	if (cfg.max_lines) |ml| {
		effective.max_lines = ml;
	}
}

/// Heuristic: does this --hide/--show regex use a negation that tends to invert
/// intent? Either the !/.../ negate-prefix, or a leading (?!...) / ^(?!...)
/// negative lookahead. Both at once double-negates (net effect flips back).
fn isNegationFootgun(value: []const u8, negated: bool) bool {
	if (negated) return true;
	return std.mem.startsWith(u8, value, "(?!") or std.mem.startsWith(u8, value, "^(?!");
}

/// Compile and add a regex to the effective state.
fn addCliRegex(
	allocator: std.mem.Allocator,
	list: *std.ArrayListUnmanaged(path_eval.CompiledRegex),
	strings: *std.ArrayListUnmanaged([]const u8),
	pattern: []const u8,
	negated: bool,
	// Only genuine regex patterns (kind == .regex) are validated. Globs are
	// stored bare and converted to regex at eval time, so a bare glob like
	// `*.log` legitimately fails raw compilation here and must be skipped
	// silently rather than reported as a user error.
	is_regex: bool,
	invalid_out: *?[]const u8,
) !void {
	const owned_pattern = try allocator.dupe(u8, pattern);
	try strings.append(allocator, owned_pattern);
	const compiled = regex_lib.Regex.compile(allocator, owned_pattern) catch {
		// Record the first invalid *regex* pattern so the caller can fail loudly.
		// owned_pattern is owned by `strings` and freed on deinit.
		if (is_regex and invalid_out.* == null) invalid_out.* = owned_pattern;
		return;
	};
	try list.append(allocator, .{
		.pattern = owned_pattern,
		.negated = negated,
		.compiled = compiled,
	});
}

const RegexConflict = struct {
	path: []const u8,
	pattern: []const u8,
};

/// Check if any regex pattern appears in both open and close lists.
/// If found, scan the directory for a matching path and return conflict info.
/// Uses HashSets for O(open + close) instead of O(open * close).
fn checkRegexConflict(
	allocator: std.mem.Allocator,
	effective: *path_eval.EffectiveState,
	abs_dir: []const u8,
	_: anytype,
) ?RegexConflict {
	// Build HashSets of close regex patterns for O(1) lookup.
	// Separate sets for negated vs non-negated patterns.
	var close_patterns = std.StringHashMapUnmanaged(void){};
	defer close_patterns.deinit(allocator);
	var close_patterns_negated = std.StringHashMapUnmanaged(void){};
	defer close_patterns_negated.deinit(allocator);

	for (effective.close_regexes.items) |*close_re| {
		const set = if (close_re.negated) &close_patterns_negated else &close_patterns;
		set.put(allocator, close_re.pattern, {}) catch return null;
	}

	// Check each open regex against the appropriate HashSet
	for (effective.open_regexes.items) |*open_re| {
		const set = if (open_re.negated) &close_patterns_negated else &close_patterns;
		if (set.contains(open_re.pattern)) {
			// Found matching pattern - scan directory for a concrete example
			if (findMatchingEntry(allocator, abs_dir, open_re)) |entry_name| {
				return RegexConflict{
					.path = entry_name,
					.pattern = open_re.pattern,
				};
			}
			// Even without a matching entry, report the conflict
			// Use the pattern itself as the path example
			return RegexConflict{
				.path = allocator.dupe(u8, open_re.pattern) catch return null,
				.pattern = open_re.pattern,
			};
		}
	}
	return null;
}

/// Scan a directory for an entry that matches the given regex.
fn findMatchingEntry(
	allocator: std.mem.Allocator,
	abs_dir: []const u8,
	re: *path_eval.CompiledRegex,
) ?[]const u8 {
	const io = runtime.io();
	var dir = std.Io.Dir.cwd().openDir(io, abs_dir, .{ .iterate = true }) catch return null;
	defer dir.close(io);
	var iter = dir.iterate();
	while (iter.next(io) catch return null) |entry| {
		if (std.mem.eql(u8, entry.name, ".") or std.mem.eql(u8, entry.name, "..")) continue;
		const matched = re.compiled.partialMatch(entry.name) catch continue;
		if (matched) {
			return allocator.dupe(u8, entry.name) catch return null;
		}
	}
	return null;
}

/// Persist the current state to a .dirtree-state file.
fn persistState(
	allocator: std.mem.Allocator,
	abs_dir: []const u8,
	cfg: *const CliConfig,
	effective: *const path_eval.EffectiveState,
) !void {
	// Read the existing local state file (if any)
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

	// Apply CLI mutations to the state file
	if (cfg.default_state) |ds| {
		sf.default_state = switch (ds) {
			.opened => .opened,
			.closed => .closed,
		};
		sf.default_state_set = true;
	}
	if (cfg.depth) |d| {
		sf.depth = d;
	}
	if (cfg.sort_mode) |sm| {
		sf.sort_mode = switch (sm) {
			.modified => .modified,
			.alpha => .alpha,
		};
	}
	if (cfg.sort_direction) |sd| {
		sf.sort_direction = switch (sd) {
			.asc => .asc,
			.desc => .desc,
		};
	}
	if (cfg.no_color) {
		sf.color_preference = false;
	}
	if (cfg.color) {
		sf.color_preference = true;
	}
	if (cfg.no_hyperlinks) {
		sf.hyperlink_preference = false;
	}
	if (cfg.hyperlinks) {
		sf.hyperlink_preference = true;
	}
	if (cfg.max_lines) |ml| {
		sf.max_lines = ml;
	}

	// Apply open/close/show/hide from CLI
	for (cfg.open_literals.items) |lit| {
		// Remove from close if present
		removeEntryByValue(&sf.close_entries, lit, .literal);
		if (!state_mod.StateFile.hasLiteral(sf.open_entries.items, lit)) {
			const val = try sf.dupeStr(lit);
			try sf.addEntry(&sf.open_entries, .{ .value = val, .kind = .literal, .negated = false });
		}
	}
	for (cfg.open_regexes.items) |re| {
		removeEntryByValue(&sf.close_entries, re.value, re.kind);
		const has = state_mod.StateFile.hasEntry(sf.open_entries.items, re.kind, re.value, re.negated);
		if (!has) {
			const val = try sf.dupeStr(re.value);
			try sf.addEntry(&sf.open_entries, .{ .value = val, .kind = re.kind, .negated = re.negated });
		}
	}
	for (cfg.close_literals.items) |lit| {
		removeEntryByValue(&sf.open_entries, lit, .literal);
		if (!state_mod.StateFile.hasLiteral(sf.close_entries.items, lit)) {
			const val = try sf.dupeStr(lit);
			try sf.addEntry(&sf.close_entries, .{ .value = val, .kind = .literal, .negated = false });
		}
	}
	for (cfg.close_regexes.items) |re| {
		removeEntryByValue(&sf.open_entries, re.value, re.kind);
		const has = state_mod.StateFile.hasEntry(sf.close_entries.items, re.kind, re.value, re.negated);
		if (!has) {
			const val = try sf.dupeStr(re.value);
			try sf.addEntry(&sf.close_entries, .{ .value = val, .kind = re.kind, .negated = re.negated });
		}
	}
	for (cfg.show_literals.items) |lit| {
		removeEntryByValue(&sf.hide_entries, lit, .literal);
		if (!state_mod.StateFile.hasLiteral(sf.show_entries.items, lit)) {
			const val = try sf.dupeStr(lit);
			try sf.addEntry(&sf.show_entries, .{ .value = val, .kind = .literal, .negated = false });
		}
	}
	for (cfg.show_regexes.items) |re| {
		removeEntryByValue(&sf.hide_entries, re.value, re.kind);
		const has = state_mod.StateFile.hasEntry(sf.show_entries.items, re.kind, re.value, re.negated);
		if (!has) {
			const val = try sf.dupeStr(re.value);
			try sf.addEntry(&sf.show_entries, .{ .value = val, .kind = re.kind, .negated = re.negated });
		}
	}
	for (cfg.hide_literals.items) |lit| {
		removeEntryByValue(&sf.show_entries, lit, .literal);
		if (!state_mod.StateFile.hasLiteral(sf.hide_entries.items, lit)) {
			const val = try sf.dupeStr(lit);
			try sf.addEntry(&sf.hide_entries, .{ .value = val, .kind = .literal, .negated = false });
		}
	}
	for (cfg.hide_regexes.items) |re| {
		removeEntryByValue(&sf.show_entries, re.value, re.kind);
		const has = state_mod.StateFile.hasEntry(sf.hide_entries.items, re.kind, re.value, re.negated);
		if (!has) {
			const val = try sf.dupeStr(re.value);
			try sf.addEntry(&sf.hide_entries, .{ .value = val, .kind = re.kind, .negated = re.negated });
		}
	}

	// Write to temp file then rename (atomic)
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
	_ = effective; // used in caller for needs_migration check
}
/// Remove entries from a list that match a given value.
/// Uses swapRemove instead of orderedRemove to avoid O(n) shifts per removal.
/// Order doesn't matter here since entries are sorted later in writeStateFile
/// via sortEntriesForOutput.
fn removeEntryByValue(list: *std.ArrayListUnmanaged(state_mod.StateEntry), value: []const u8, kind: state_mod.PatternKind) void {
	var ii: usize = 0;
	while (ii < list.items.len) {
		if (list.items[ii].kind == kind and std.mem.eql(u8, list.items[ii].value, value)) {
			_ = list.swapRemove(ii);
			// Don't increment ii - the swapped element needs checking
		} else {
			ii += 1;
		}
	}
}

/// Persist an annotation to the local .dirtree-state file.
/// Print "dirtree X.Y.Z" line. Does not flush.
fn printVersionLine(writer: anytype) !void {
	try writer.writeAll("dirtree ");
	try writer.writeAll(@import("build_options").version);
	try writer.writeAll("\n");
}

/// If the update-check cache says a newer version exists, print a one-line
/// notice in yellow (or plain if --no-color / NO_COLOR is set). Silent on any
/// failure (missing cache, parse error, etc).
fn emitCachedUpdateNotice(allocator: std.mem.Allocator, writer: anytype) !void {
	const path = update_check.cachePath(allocator) catch return;
	defer allocator.free(path);
	const state = update_check.loadCache(allocator, path) orelse return;
	const latest = state.last_known_version orelse return;
	const current = @import("build_options").version;
	if (update_check.compareSemver(current, latest) != .older) return;
	const use_color = runtime.getEnv("NO_COLOR") == null;
	if (use_color) try writer.writeAll(ansi_mod.yellow);
	try writer.print("Update available: {s} (current: {s})\n", .{ latest, current });
	if (use_color) try writer.writeAll(ansi_mod.reset);
}

/// Run a fresh network check, update the cache, and print results.
/// Returns nonzero on network failure (so callers/CI can detect it).
fn runVersionCheck(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype) !u8 {
	const path = update_check.cachePath(allocator) catch {
		try stderr.writeAll("Error: cannot determine cache path ($HOME / $XDG_CACHE_HOME missing)\n");
		return 2;
	};
	defer allocator.free(path);

	const exe_path_buf = std.process.executablePathAlloc(runtime.io(), allocator) catch null;
	const exe_mtime: i128 = if (exe_path_buf) |p| blk: {
		defer allocator.free(p);
		break :blk update_check.binaryMtime(p);
	} else 0;

	const now_ts = std.Io.Timestamp.now(runtime.io(), .real);
	const now_unix: i64 = @intCast(@divFloor(now_ts.nanoseconds, std.time.ns_per_s));
	const today = update_check.todayUtc(now_unix);

	// Load existing cache (may be null on first run)
	const prior = update_check.loadCache(allocator, path);

	const tag = update_check.fetchLatestTag(allocator) catch |err| {
		// Failure path: record the failure, increment fail_count, write back.
		var state = prior orelse update_check.CacheState{};
		state.fail_count +|= 1;
		state.last_fail_ts = now_unix;
		state.binary_mtime = exe_mtime;
		update_check.saveCache(allocator, path, state) catch {};
		try stderr.print("Error: update check failed ({s})\n", .{@errorName(err)});
		return 1;
	};
	defer allocator.free(tag);

	// Success path: reset counters, store the new known version.
	const state = update_check.CacheState{
		.last_known_version = tag,
		.last_check_date = today,
		.binary_mtime = exe_mtime,
		.fail_count = 0,
		.last_fail_ts = 0,
	};
	update_check.saveCache(allocator, path, state) catch {};

	const current = @import("build_options").version;
	const use_color = runtime.getEnv("NO_COLOR") == null;
	switch (update_check.compareSemver(current, tag)) {
		.older => {
			if (use_color) try stdout.writeAll(ansi_mod.yellow);
			try stdout.print("Update available: {s} (current: {s})\n", .{ tag, current });
			if (use_color) try stdout.writeAll(ansi_mod.reset);
		},
		.equal => try stdout.writeAll("Up to date.\n"),
		.newer => try stdout.print("You are ahead of the latest release ({s}).\n", .{tag}),
	}
	return 0;
}

/// List (purge=false) or remove (purge=true) the current directory's orphaned
/// annotations. Current-directory scope only.
fn runOrphanedNotes(
	allocator: std.mem.Allocator,
	dir_arg: []const u8,
	stdout: anytype,
	stderr: anytype,
	purge: bool,
) !u8 {
	const s = i18n.tr();
	const abs_dir = resolveAbsDir(allocator, dir_arg) catch {
		var err_buf: [512]u8 = undefined;
		const msg = i18n.fmtRuntime(&err_buf, s.err_not_a_directory, &.{dir_arg});
		try stderr.writeAll(msg);
		try stderr.writeAll("\n");
		try stderr.flush();
		return 1;
	};
	defer allocator.free(abs_dir);

	var sf: state_mod.StateFile = .{ .allocator = allocator };
	defer sf.deinit();
	var orphans: std.ArrayListUnmanaged(usize) = .empty;
	defer orphans.deinit(allocator);
	try scanOrphanedNotes(allocator, abs_dir, &sf, &orphans);

	if (orphans.items.len == 0) {
		try stdout.writeAll(if (purge) s.purge_none else s.orphaned_none);
		try stdout.writeAll("\n");
		try stdout.flush();
		return 0;
	}

	try stdout.writeAll(if (purge) s.purge_header else s.orphaned_header);
	try stdout.writeAll("\n");
	for (orphans.items) |idx| {
		const e = sf.annotate_entries.items[idx];
		try stdout.print("  {s} = {s}\n", .{ e.path, e.description });
	}

	if (purge) {
		// Remove orphaned entries. Reverse order keeps the remaining indices
		// valid under swapRemove (writeStateFile re-sorts, so order is moot).
		var j: usize = orphans.items.len;
		while (j > 0) {
			j -= 1;
			_ = sf.annotate_entries.swapRemove(orphans.items[j]);
		}
		const state_path = try std.fs.path.join(allocator, &.{ abs_dir, ".dirtree-state" });
		defer allocator.free(state_path);
		const io = runtime.io();
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
	try stdout.flush();
	return 0;
}

/// An annotate entry whose target path no longer exists on disk.
const OrphanedNote = struct {
	path: []const u8,
	description: []const u8,
};

/// Parse abs_dir/.dirtree-state and append to `orphans_out` the indices of
/// annotate_entries that are orphaned: a real (non-tombstone) note whose target
/// path no longer exists on disk. Current-directory scope only — does not walk
/// the inheritance chain. On success `sf_out.*` owns the parsed StateFile and the
/// caller must deinit it.
fn scanOrphanedNotes(
	allocator: std.mem.Allocator,
	abs_dir: []const u8,
	sf_out: *state_mod.StateFile,
	orphans_out: *std.ArrayListUnmanaged(usize),
) !void {
	const state_path = try std.fs.path.join(allocator, &.{ abs_dir, ".dirtree-state" });
	defer allocator.free(state_path);
	const io = runtime.io();
	var sf: state_mod.StateFile = blk: {
		const content = std.Io.Dir.cwd().readFileAlloc(io, state_path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
			error.FileNotFound => break :blk state_mod.StateFile{ .allocator = allocator },
			else => return err,
		};
		defer allocator.free(content);
		break :blk try state_mod.parseStateFile(allocator, content);
	};
	errdefer sf.deinit();

	for (sf.annotate_entries.items, 0..) |entry, idx| {
		if (entry.description.len == 0) continue; // tombstone, not a user-facing note
		const full = try std.fs.path.join(allocator, &.{ abs_dir, entry.path });
		defer allocator.free(full);
		_ = std.Io.Dir.cwd().statFile(io, full, .{}) catch {
			try orphans_out.append(allocator, idx);
		};
	}
	sf_out.* = sf;
}

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

// Tests
test "help output contains usage" {
	var buf: [8192]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	const writer = &fbs;
	try printHelp(writer);
	const output = fbs.buffered();
	try std.testing.expect(std.mem.indexOf(u8, output, "Usage: dirtree") != null);
}

test "parseArgs: help flag" {
	const args = &[_][:0]const u8{ "dirtree", "-h" };
	const result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.help => {},
		else => return error.TestExpectedHelp,
	}
}

test "parseArgs: about flag" {
	const args = &[_][:0]const u8{ "dirtree", "--about" };
	const result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.about => {},
		else => return error.TestExpectedAbout,
	}
}

test "parseArgs: depth flag" {
	const args = &[_][:0]const u8{ "dirtree", "-d", "3" };
	var result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.config => |*cfg| {
			defer cfg.deinit(std.testing.allocator);
			try std.testing.expectEqual(@as(u32, 3), cfg.depth.?);
			try std.testing.expect(cfg.state_modified);
		},
		else => return error.TestExpectedConfig,
	}
}

test "parseArgs: depth flag missing value" {
	const args = &[_][:0]const u8{ "dirtree", "-d" };
	const result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.err => {},
		else => return error.TestExpectedError,
	}
}

test "parseArgs: simple mode" {
	const args = &[_][:0]const u8{ "dirtree", "--simple" };
	var result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.config => |*cfg| {
			defer cfg.deinit(std.testing.allocator);
			try std.testing.expect(cfg.simple_mode);
		},
		else => return error.TestExpectedConfig,
	}
}

test "parseArgs: sort flags" {
	const args = &[_][:0]const u8{ "dirtree", "--sort", "alpha", "--asc" };
	var result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.config => |*cfg| {
			defer cfg.deinit(std.testing.allocator);
			try std.testing.expectEqual(SortMode.alpha, cfg.sort_mode.?);
			try std.testing.expectEqual(SortDirection.asc, cfg.sort_direction.?);
		},
		else => return error.TestExpectedConfig,
	}
}

test "parseArgs: unknown option" {
	const args = &[_][:0]const u8{ "dirtree", "--nonexistent" };
	const result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.err => {},
		else => return error.TestExpectedError,
	}
}

test "parseArgs: default opened" {
	const args = &[_][:0]const u8{ "dirtree", "--default", "opened" };
	var result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.config => |*cfg| {
			defer cfg.deinit(std.testing.allocator);
			try std.testing.expectEqual(DefaultState.opened, cfg.default_state.?);
			try std.testing.expect(cfg.state_modified);
		},
		else => return error.TestExpectedConfig,
	}
}

test "parseArgs: default closed" {
	const args = &[_][:0]const u8{ "dirtree", "--default", "closed" };
	var result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.config => |*cfg| {
			defer cfg.deinit(std.testing.allocator);
			try std.testing.expectEqual(DefaultState.closed, cfg.default_state.?);
		},
		else => return error.TestExpectedConfig,
	}
}

test "parseArgs: open with regex" {
	const args = &[_][:0]const u8{ "dirtree", "--open", "/^src$/" };
	var result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.config => |*cfg| {
			defer cfg.deinit(std.testing.allocator);
			try std.testing.expectEqual(@as(usize, 1), cfg.open_regexes.items.len);
			try std.testing.expectEqualStrings("^src$", cfg.open_regexes.items[0].value);
			try std.testing.expect(!cfg.open_regexes.items[0].negated);
		},
		else => return error.TestExpectedConfig,
	}
}

test "parseArgs: open with literal" {
	const args = &[_][:0]const u8{ "dirtree", "--open", "src" };
	var result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.config => |*cfg| {
			defer cfg.deinit(std.testing.allocator);
			try std.testing.expectEqual(@as(usize, 1), cfg.open_literals.items.len);
			try std.testing.expectEqualStrings("src", cfg.open_literals.items[0]);
		},
		else => return error.TestExpectedConfig,
	}
}

test "parseArgs: hide rejects absolute paths" {
	const args = &[_][:0]const u8{ "dirtree", "--hide", "/absolute/path" };
	const result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.err => {},
		else => return error.TestExpectedError,
	}
}

test "parseArgs: show rejects absolute paths" {
	const args = &[_][:0]const u8{ "dirtree", "--show", "/absolute/path" };
	const result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.err => {},
		else => return error.TestExpectedError,
	}
}

test "parseArgs: directory argument" {
	const args = &[_][:0]const u8{ "dirtree", "/tmp" };
	var result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.config => |*cfg| {
			defer cfg.deinit(std.testing.allocator);
			try std.testing.expectEqualStrings("/tmp", cfg.dir);
		},
		else => return error.TestExpectedConfig,
	}
}

test "parseArgs: open with glob" {
	const args = &[_][:0]const u8{ "dirtree", "--open", "*.txt" };
	var result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.config => |*cfg| {
			defer cfg.deinit(std.testing.allocator);
			try std.testing.expectEqual(@as(usize, 1), cfg.open_regexes.items.len);
			try std.testing.expect(cfg.open_regexes.items[0].kind == .glob);
			// glob *.txt should be stored as-is (converted to regex at eval time)
			try std.testing.expectEqualStrings("*.txt", cfg.open_regexes.items[0].value);
		},
		else => return error.TestExpectedConfig,
	}
}

test "parseArgs: --lang en accepted" {
	const args = &[_][:0]const u8{ "dirtree", "--lang", "en", "--simple" };
	var result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.config => |*cfg| {
			defer cfg.deinit(std.testing.allocator);
			try std.testing.expect(cfg.simple_mode);
		},
		else => return error.TestExpectedConfig,
	}
}

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

// Pull in tests from other modules
test {
	_ = @import("regex.zig");
	_ = @import("state.zig");
	_ = @import("dir_scan.zig");
	_ = @import("icons.zig");
	_ = @import("ansi.zig");
	_ = @import("path_eval.zig");
	_ = @import("scm.zig");
	_ = @import("tree_render.zig");
	_ = @import("i18n/mod.zig");
}
