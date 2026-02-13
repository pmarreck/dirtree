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

pub const DefaultVisibility = enum {
	shown,
	hidden,
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
	no_hyperlinks: bool = false,
	show_hidden: bool = false,
	rewrite_settings: bool = false,
	show_config: bool = false,
	stdout_is_tty: bool = true,

	// Depth
	depth: ?u32 = null,

	// Sort
	sort_mode: ?SortMode = null,
	sort_direction: ?SortDirection = null,

	// Defaults
	default_state: ?DefaultState = null,
	default_visibility: ?DefaultVisibility = null,

	// Variadic args (literals and regex patterns)
	open_literals: std.ArrayListUnmanaged([]const u8) = .{},
	open_regexes: std.ArrayListUnmanaged(ArgEntry) = .{},
	close_literals: std.ArrayListUnmanaged([]const u8) = .{},
	close_regexes: std.ArrayListUnmanaged(ArgEntry) = .{},
	show_literals: std.ArrayListUnmanaged([]const u8) = .{},
	show_regexes: std.ArrayListUnmanaged(ArgEntry) = .{},
	hide_literals: std.ArrayListUnmanaged([]const u8) = .{},
	hide_regexes: std.ArrayListUnmanaged(ArgEntry) = .{},

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
	}

	fn freeOwnedEntries(allocator: std.mem.Allocator, entries: *std.ArrayListUnmanaged(ArgEntry)) void {
		for (entries.items) |entry| {
			if (entry.owned) {
				allocator.free(entry.value);
			}
		}
	}
};

/// Result of argument parsing - either a config or an early exit.
pub const ParseResult = union(enum) {
	config: CliConfig,
	help,
	about,
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
	// No --lang found; detect from environment
	i18n.setLocale(i18n.detectLocaleFromEnv());
}

/// Parse CLI arguments into a CliConfig.
/// Returns ParseResult which may be an early exit (help, about, test, error).
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

		// Long flags via i18n alias map
		if (arg.len > 1 and arg[0] == '-' and arg[1] == '-') {
			if (i18n.matchLongFlag(arg)) |cli_arg| {
				switch (cli_arg) {
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
					.no_hyperlinks => {
						config.no_hyperlinks = true;
						config.state_modified = true;
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
	"open", "opened", "close", "closed", "show", "shown", "hide", "hidden",
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
		} else if (std.ascii.eqlIgnoreCase(token, "show") or std.ascii.eqlIgnoreCase(token, "shown")) {
			if (config.default_visibility != null and config.default_visibility.? != .shown) {
				return .{ .err = s.err_default_visibility_conflict };
			}
			config.default_visibility = .shown;
		} else if (std.ascii.eqlIgnoreCase(token, "hide") or std.ascii.eqlIgnoreCase(token, "hidden")) {
			if (config.default_visibility != null and config.default_visibility.? != .hidden) {
				return .{ .err = s.err_default_visibility_conflict };
			}
			config.default_visibility = .hidden;
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
		if (std.ascii.eqlIgnoreCase(val, "0") or
			std.ascii.eqlIgnoreCase(val, "false") or
			std.ascii.eqlIgnoreCase(val, "no") or
			std.ascii.eqlIgnoreCase(val, "off"))
		{
			return true; // PIPED_STDOUT=0 means treat as TTY
		}
		if (std.ascii.eqlIgnoreCase(val, "1") or
			std.ascii.eqlIgnoreCase(val, "true") or
			std.ascii.eqlIgnoreCase(val, "yes") or
			std.ascii.eqlIgnoreCase(val, "on"))
		{
			return false; // PIPED_STDOUT=1 means treat as piped
		}
	}
	return std.posix.isatty(std.posix.STDOUT_FILENO);
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
}

fn isTruthyEnv(val: []const u8) bool {
	return std.mem.eql(u8, val, "1") or
		std.mem.eql(u8, val, "true") or
		std.mem.eql(u8, val, "TRUE") or
		std.mem.eql(u8, val, "yes") or
		std.mem.eql(u8, val, "YES") or
		std.mem.eql(u8, val, "on") or
		std.mem.eql(u8, val, "ON");
}

pub fn printHelp(writer: anytype) !void {
	const s = i18n.tr();
	try writer.writeAll(s.help_title);
	try writer.writeAll("\n\n");
	try writer.writeAll(s.help_usage);
	try writer.writeAll("\n\n");
	try writer.writeAll(s.help_options_header);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_help);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_about);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_depth);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_simple);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_decorated);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_no_icons);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_no_color);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_no_hyperlinks);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_default);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_open);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_close);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_show);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_hide);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_sort);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_asc);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_desc);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_show_hidden);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_rewrite_settings);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_config);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_test);
	try writer.writeAll("\n");
	try writer.writeAll(s.help_opt_lang);
	try writer.writeAll("\n\n");
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
}

pub fn main() !u8 {
	var stdout_buf: [4096]u8 = undefined;
	var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
	const stdout = &stdout_writer.interface;

	var stderr_buf: [4096]u8 = undefined;
	var stderr_writer = std.fs.File.stderr().writer(&stderr_buf);
	const stderr = &stderr_writer.interface;

	const allocator = std.heap.page_allocator;
	const raw_args = try std.process.argsAlloc(allocator);
	defer std.process.argsFree(allocator, raw_args);

	const result = parseArgs(allocator, raw_args);

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
		.test_mode => {
			const s = i18n.tr();
			// Check for DIRTREE_TEST_BIN to run external test binary
			const test_bin = std.posix.getenv("DIRTREE_TEST_BIN");
			if (test_bin) |bin| {
				const argv: []const []const u8 = &.{bin};
				var child = std.process.Child.init(argv, allocator);
				child.stderr_behavior = .Inherit;
				child.stdout_behavior = .Inherit;
				child.stdin_behavior = .Inherit;
				child.spawn() catch {
					var err_buf: [512]u8 = undefined;
					const msg = i18n.fmtRuntime(&err_buf, s.err_test_bin_run, &.{std.mem.sliceTo(bin, 0)});
					try stderr.writeAll(msg);
					try stderr.writeAll("\n");
					try stderr.flush();
					return 1;
				};
				const term = child.wait() catch {
					try stderr.writeAll(s.err_test_bin_wait);
					try stderr.writeAll("\n");
					try stderr.flush();
					return 1;
				};
				return term.Exited;
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
			applyCliOverrides(allocator, &cfg, &effective) catch {};

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
			const max_depth = cfg.depth orelse effective.depth orelse 4;

			const render_config = tree_render.RenderConfig{
				.use_color = use_color,
				.use_icons = use_icons,
				.use_hyperlinks = use_hyperlinks,
				.simple_mode = use_simple,
				.report_hidden = !cfg.show_hidden,
				.max_depth = max_depth,
				.show_hidden = cfg.show_hidden,
				.sort_mode = sort_mode,
				.sort_direction = sort_direction,
			};

			// Persist state if modified
			if (cfg.state_modified or effective.needs_migration or cfg.rewrite_settings) {
				persistState(allocator, abs_dir, &cfg, &effective) catch |err| {
					try stderr.print("Warning: could not persist state: {}\n", .{err});
					try stderr.flush();
				};
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

			try stdout.flush();
			try stderr.flush();
			return 0;
		},
	}
}

/// Resolve a directory path to an absolute path.
fn resolveAbsDir(allocator: std.mem.Allocator, dir: []const u8) ![]const u8 {
	// If already absolute, use it directly
	if (dir.len > 0 and dir[0] == '/') {
		// Verify it's a directory
		var d = try std.fs.cwd().openDir(dir, .{});
		d.close();
		return try allocator.dupe(u8, dir);
	}

	// Resolve relative to cwd
	const cwd = try std.fs.cwd().realpathAlloc(allocator, ".");
	defer allocator.free(cwd);

	if (std.mem.eql(u8, dir, ".")) {
		return try allocator.dupe(u8, cwd);
	}

	const abs = try std.fs.path.join(allocator, &.{ cwd, dir });
	errdefer allocator.free(abs);

	// Verify it's a directory
	var d = std.fs.cwd().openDir(abs, .{}) catch return error.NotADirectory;
	d.close();

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
	if (cfg.default_visibility) |dv| {
		effective.default_visibility = switch (dv) {
			.shown => .shown,
			.hidden => .hidden,
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
		try addCliRegex(allocator, &effective.open_regexes, &effective.strings, re.value, re.negated);
	}
	for (cfg.close_regexes.items) |re| {
		try addCliRegex(allocator, &effective.close_regexes, &effective.strings, re.value, re.negated);
	}
	for (cfg.show_regexes.items) |re| {
		try addCliRegex(allocator, &effective.show_regexes, &effective.strings, re.value, re.negated);
	}
	for (cfg.hide_regexes.items) |re| {
		try addCliRegex(allocator, &effective.hide_regexes, &effective.strings, re.value, re.negated);
	}

	// Apply CLI color/hyperlink preferences
	if (cfg.no_color) {
		effective.color_preference = false;
	}
	if (cfg.no_hyperlinks) {
		effective.hyperlink_preference = false;
	}
}

/// Compile and add a regex to the effective state.
fn addCliRegex(
	allocator: std.mem.Allocator,
	list: *std.ArrayListUnmanaged(path_eval.CompiledRegex),
	strings: *std.ArrayListUnmanaged([]const u8),
	pattern: []const u8,
	negated: bool,
) !void {
	const owned_pattern = try allocator.dupe(u8, pattern);
	try strings.append(allocator, owned_pattern);
	const compiled = regex_lib.Regex.compile(allocator, owned_pattern) catch return;
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
fn checkRegexConflict(
	allocator: std.mem.Allocator,
	effective: *path_eval.EffectiveState,
	abs_dir: []const u8,
	_: anytype,
) ?RegexConflict {
	// Check each open regex against each close regex for same pattern
	for (effective.open_regexes.items) |*open_re| {
		for (effective.close_regexes.items) |*close_re| {
			if (std.mem.eql(u8, open_re.pattern, close_re.pattern) and
				open_re.negated == close_re.negated)
			{
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
	}
	return null;
}

/// Scan a directory for an entry that matches the given regex.
fn findMatchingEntry(
	allocator: std.mem.Allocator,
	abs_dir: []const u8,
	re: *path_eval.CompiledRegex,
) ?[]const u8 {
	var dir = std.fs.cwd().openDir(abs_dir, .{ .iterate = true }) catch return null;
	defer dir.close();
	var iter = dir.iterate();
	while (iter.next() catch return null) |entry| {
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

	var sf: state_mod.StateFile = blk: {
		const content = std.fs.cwd().readFileAlloc(allocator, state_path, 1024 * 1024) catch |err| {
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
	if (cfg.default_visibility) |dv| {
		sf.default_visibility = switch (dv) {
			.shown => .shown,
			.hidden => .hidden,
		};
		sf.default_visibility_set = true;
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
	if (cfg.no_hyperlinks) {
		sf.hyperlink_preference = false;
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
		const has = if (re.kind == .glob) state_mod.StateFile.hasGlob(sf.open_entries.items, re.value, re.negated) else state_mod.StateFile.hasRegex(sf.open_entries.items, re.value, re.negated);
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
		const has = if (re.kind == .glob) state_mod.StateFile.hasGlob(sf.close_entries.items, re.value, re.negated) else state_mod.StateFile.hasRegex(sf.close_entries.items, re.value, re.negated);
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
		const has = if (re.kind == .glob) state_mod.StateFile.hasGlob(sf.show_entries.items, re.value, re.negated) else state_mod.StateFile.hasRegex(sf.show_entries.items, re.value, re.negated);
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
		const has = if (re.kind == .glob) state_mod.StateFile.hasGlob(sf.hide_entries.items, re.value, re.negated) else state_mod.StateFile.hasRegex(sf.hide_entries.items, re.value, re.negated);
		if (!has) {
			const val = try sf.dupeStr(re.value);
			try sf.addEntry(&sf.hide_entries, .{ .value = val, .kind = re.kind, .negated = re.negated });
		}
	}

	// Write to temp file then rename (atomic)
	const tmp_path = try std.fmt.allocPrint(allocator, "{s}.tmp", .{state_path});
	defer allocator.free(tmp_path);

	{
		const file = try std.fs.cwd().createFile(tmp_path, .{});
		defer file.close();
		var buf: [8192]u8 = undefined;
		var bw = file.writer(&buf);
		try state_mod.writeStateFile(&sf, &bw.interface);
		try bw.interface.flush();
	}

	try std.fs.cwd().rename(tmp_path, state_path);
	_ = effective; // used in caller for needs_migration check
}

/// Remove entries from a list that match a given value.
fn removeEntryByValue(list: *std.ArrayListUnmanaged(state_mod.StateEntry), value: []const u8, kind: state_mod.PatternKind) void {
	var ii: usize = 0;
	while (ii < list.items.len) {
		if (list.items[ii].kind == kind and std.mem.eql(u8, list.items[ii].value, value)) {
			_ = list.orderedRemove(ii);
		} else {
			ii += 1;
		}
	}
}

// Tests
test "help output contains usage" {
	var buf: [8192]u8 = undefined;
	var fbs = std.io.fixedBufferStream(&buf);
	const writer = fbs.writer();
	try printHelp(writer);
	const output = fbs.getWritten();
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

test "parseArgs: default closed hidden" {
	const args = &[_][:0]const u8{ "dirtree", "--default", "closed", "hidden" };
	var result = parseArgs(std.testing.allocator, args);
	switch (result) {
		.config => |*cfg| {
			defer cfg.deinit(std.testing.allocator);
			try std.testing.expectEqual(DefaultState.closed, cfg.default_state.?);
			try std.testing.expectEqual(DefaultVisibility.hidden, cfg.default_visibility.?);
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
