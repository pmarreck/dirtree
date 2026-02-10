const std = @import("std");
const regex = @import("regex.zig");
const regex_lib = @import("regex");
const state_mod = @import("state.zig");
const path_eval = @import("path_eval.zig");
const scm_mod = @import("scm.zig");
const tree_render = @import("tree_render.zig");
const dir_scan = @import("dir_scan.zig");
const ansi_mod = @import("ansi.zig");

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
	is_regex: bool,
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

/// Parse CLI arguments into a CliConfig.
/// Returns ParseResult which may be an early exit (help, about, test, error).
pub fn parseArgs(allocator: std.mem.Allocator, raw_args: []const [:0]const u8) ParseResult {
	var config = CliConfig{};

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

		if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
			config.deinit(allocator);
			return .help;
		}
		if (std.mem.eql(u8, arg, "-a") or std.mem.eql(u8, arg, "--about")) {
			config.deinit(allocator);
			return .about;
		}
		if (std.mem.eql(u8, arg, "--test")) {
			config.deinit(allocator);
			return .test_mode;
		}

		if (std.mem.eql(u8, arg, "-d") or std.mem.eql(u8, arg, "--depth")) {
			i += 1;
			if (i >= args.len) {
				config.deinit(allocator);
				return .{ .err = "Error: --depth requires a numeric argument" };
			}
			const depth_str = args[i];
			const depth = std.fmt.parseInt(u32, depth_str, 10) catch {
				config.deinit(allocator);
				return .{ .err = "Error: --depth requires a numeric argument" };
			};
			config.depth = depth;
			config.state_modified = true;
			i += 1;
			continue;
		}

		if (std.mem.eql(u8, arg, "--simple")) {
			config.simple_mode = true;
			i += 1;
			continue;
		}
		if (std.mem.eql(u8, arg, "--decorated")) {
			config.force_decorated = true;
			i += 1;
			continue;
		}
		if (std.mem.eql(u8, arg, "--no-icons")) {
			config.no_icons = true;
			i += 1;
			continue;
		}
		if (std.mem.eql(u8, arg, "--no-color")) {
			config.no_color = true;
			config.state_modified = true;
			i += 1;
			continue;
		}
		if (std.mem.eql(u8, arg, "--no-hyperlinks")) {
			config.no_hyperlinks = true;
			config.state_modified = true;
			i += 1;
			continue;
		}
		if (std.mem.eql(u8, arg, "--show-hidden")) {
			config.show_hidden = true;
			i += 1;
			continue;
		}
		if (std.mem.eql(u8, arg, "--rewrite-settings")) {
			config.rewrite_settings = true;
			i += 1;
			continue;
		}
		if (std.mem.eql(u8, arg, "--asc")) {
			config.sort_direction = .asc;
			config.state_modified = true;
			i += 1;
			continue;
		}
		if (std.mem.eql(u8, arg, "--desc")) {
			config.sort_direction = .desc;
			config.state_modified = true;
			i += 1;
			continue;
		}

		if (std.mem.eql(u8, arg, "--sort")) {
			i += 1;
			if (i >= args.len) {
				config.deinit(allocator);
				return .{ .err = "Error: --sort requires 'modified' or 'alpha'" };
			}
			const mode_str = args[i];
			if (std.mem.eql(u8, mode_str, "modified")) {
				config.sort_mode = .modified;
			} else if (std.mem.eql(u8, mode_str, "alpha")) {
				config.sort_mode = .alpha;
			} else {
				config.deinit(allocator);
				return .{ .err = "Error: --sort requires 'modified' or 'alpha'" };
			}
			config.state_modified = true;
			i += 1;
			continue;
		}

		if (std.mem.eql(u8, arg, "--default")) {
			i += 1;
			const result = collectDefaultArgs(args[i..], &config);
			switch (result) {
				.ok => |count| {
					if (count == 0) {
						config.deinit(allocator);
						return .{ .err = "Error: --default requires at least one value" };
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

		if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--open")) {
			i += 1;
			const result = collectVariadicArgs(allocator, args[i..], &config.open_literals, &config.open_regexes, dir_pending, null, "open");
			switch (result) {
				.ok => |count| {
					if (count == 0) {
						config.deinit(allocator);
						return .{ .err = "Error: --open requires at least one directory" };
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

		if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--close")) {
			i += 1;
			const result = collectVariadicArgs(allocator, args[i..], &config.close_literals, &config.close_regexes, dir_pending, null, "close");
			switch (result) {
				.ok => |count| {
					if (count == 0) {
						config.deinit(allocator);
						return .{ .err = "Error: --close requires at least one directory" };
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

		if (std.mem.eql(u8, arg, "--show")) {
			i += 1;
			const result = collectVariadicArgs(allocator, args[i..], &config.show_literals, &config.show_regexes, dir_pending, .reject_absolute, "--show");
			switch (result) {
				.ok => |count| {
					if (count == 0) {
						config.deinit(allocator);
						return .{ .err = "Error: --show requires at least one path" };
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

		if (std.mem.eql(u8, arg, "--hide")) {
			i += 1;
			const result = collectVariadicArgs(allocator, args[i..], &config.hide_literals, &config.hide_regexes, dir_pending, .reject_absolute, "--hide");
			switch (result) {
				.ok => |count| {
					if (count == 0) {
						config.deinit(allocator);
						return .{ .err = "Error: --hide requires at least one path" };
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
			return .{ .err = "Unknown option" };
		}

		// Directory argument
		config.dir = arg;
		dir_pending = false;
		i += 1;
		break;
	}

	return .{ .config = config };
}

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
			return .{ .err = "Error: regex pattern must not be empty" };
		};

		if (parsed) |p| {
			regexes.append(allocator, .{
				.value = p.pattern,
				.is_regex = true,
				.negated = p.negated,
			}) catch return .{ .err = "Out of memory" };
			count += 1;
			continue;
		}

		// Check for absolute path rejection
		if (path_validation) |pv| {
			switch (pv) {
				.reject_absolute => {
					if (token.len > 0 and token[0] == '/') {
						const written = std.fmt.bufPrint(&abs_path_err_buf, "Error: {s} paths must be relative (no leading '/'): {s}", .{ flag_name, token }) catch {
							return .{ .err = "Error: paths must be relative (no leading '/')" };
						};
						return .{ .err = written };
					}
				},
			}
		}

		// Try as glob
		if (regex.isGlobPattern(token)) {
			const regex_pattern = regex.globToRegex(allocator, token) catch {
				return .{ .err = "Out of memory" };
			};
			regexes.append(allocator, .{
				.value = regex_pattern,
				.is_regex = true,
				.negated = false,
				.owned = true,
			}) catch return .{ .err = "Out of memory" };
			count += 1;
			continue;
		}

		// Treat as literal
		literals.append(allocator, token) catch return .{ .err = "Out of memory" };
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
	var count: usize = 0;

	for (args) |token| {
		// Stop at next flag
		if (token.len > 0 and token[0] == '-') break;

		if (!isDefaultToken(token)) break;

		// Parse the default token
		if (std.ascii.eqlIgnoreCase(token, "open") or std.ascii.eqlIgnoreCase(token, "opened")) {
			if (config.default_state != null and config.default_state.? != .opened) {
				return .{ .err = "Error: --default state conflict" };
			}
			config.default_state = .opened;
		} else if (std.ascii.eqlIgnoreCase(token, "close") or std.ascii.eqlIgnoreCase(token, "closed")) {
			if (config.default_state != null and config.default_state.? != .closed) {
				return .{ .err = "Error: --default state conflict" };
			}
			config.default_state = .closed;
		} else if (std.ascii.eqlIgnoreCase(token, "show") or std.ascii.eqlIgnoreCase(token, "shown")) {
			if (config.default_visibility != null and config.default_visibility.? != .shown) {
				return .{ .err = "Error: --default visibility conflict" };
			}
			config.default_visibility = .shown;
		} else if (std.ascii.eqlIgnoreCase(token, "hide") or std.ascii.eqlIgnoreCase(token, "hidden")) {
			if (config.default_visibility != null and config.default_visibility.? != .hidden) {
				return .{ .err = "Error: --default visibility conflict" };
			}
			config.default_visibility = .hidden;
		} else {
			return .{ .err = "Error: --default accepts opened/closed/shown/hidden" };
		}

		count += 1;
	}

	return .{ .ok = count };
}

fn detectTty() bool {
	// Check PIPED_STDOUT env var first
	if (std.posix.getenv("PIPED_STDOUT")) |val| {
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
	if (std.posix.getenv("DIRTREE_SIMPLE")) |val| {
		if (isTruthyEnv(val)) config.simple_mode = true;
	}
	if (std.posix.getenv("DIRTREE_DECORATED")) |val| {
		if (isTruthyEnv(val)) config.force_decorated = true;
	}
	if (std.posix.getenv("DIRTREE_AUTO_SIMPLE")) |val| {
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
	try writer.print(
		\\dirtree - Stateful directory trees for humans and LLMs
		\\
		\\Usage: dirtree [OPTIONS] [PATH]
		\\
		\\Options:
		\\  -h, --help         Show this help message
		\\  -a, --about        Show detailed description
		\\  -d, --depth N      Set maximum depth (default: 4)
		\\  --simple           Output a simple, LLM-friendly stateful tree
		\\  --decorated        Force decorated output (even when piped)
		\\  --no-icons         Disable icons (simple mode + decorated header)
		\\  --no-color        Disable ANSI colors and persist preference
		\\  --no-hyperlinks   Disable OSC8 hyperlinks and persist preference
		\\  --default X        Persist default state: opened|closed
		\\  -o, --open DIR...  Open one or more subdirs (repeat flag to add more)
		\\  -c, --close DIR... Close one or more subdirs (repeat flag to add more)
		\\  --show PATH...     Force show relative paths; wrap regexes as /pattern/ or !/pattern/
		\\  --hide PATH...     Hide relative paths; wrap regexes as /pattern/ or !/pattern/ (repeatable)
		\\  --sort MODE        Sorting mode: modified|alpha (default: modified)
		\\  --asc              Sort ascending
		\\  --desc             Sort descending (default)
		\\  --show-hidden      Temporarily display paths hidden via config
		\\  --rewrite-settings Rewrite state file using current settings
		\\  --test             Run associated tests
		\\
		\\Use /pattern/ or !/pattern/ with --open/--close/--show/--hide to add regex rules; other arguments are treated as literals.
		\\Paths supplied to --show/--hide must be relative (no leading '/').
		\\
		\\Behavior: By default, when stdout is not a TTY (piped),
		\\  colors/icons/hyperlinks are disabled unless --decorated is given.
		\\
		\\Examples:
		\\  dirtree                       # Show tree of current directory
		\\  dirtree -d 3                  # Set depth to 3 levels
		\\  dirtree --sort alpha --asc    # Sorted alphabetically ascending
		\\
	, .{});
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
			try stdout.print("Stateful directory tree (icons/colors/links); --simple for LLMs; persists .dirtree-state (default/open/close/show/hide); regex via /pattern/ or !/pattern/; literals must be relative; env: DIRTREE_{{SIMPLE,DECORATED,AUTO_SIMPLE}}.\n", .{});
			try stdout.flush();
			return 0;
		},
		.test_mode => {
			// Check for DIRTREE_TEST_BIN to run external test binary
			const test_bin = std.posix.getenv("DIRTREE_TEST_BIN");
			if (test_bin) |bin| {
				const argv: []const []const u8 = &.{bin};
				var child = std.process.Child.init(argv, allocator);
				child.stderr_behavior = .Inherit;
				child.stdout_behavior = .Inherit;
				child.stdin_behavior = .Inherit;
				child.spawn() catch {
					try stderr.print("Error: could not run DIRTREE_TEST_BIN: {s}\n", .{bin});
					try stderr.flush();
					return 1;
				};
				const term = child.wait() catch {
					try stderr.print("Error: could not wait for DIRTREE_TEST_BIN\n", .{});
					try stderr.flush();
					return 1;
				};
				return term.Exited;
			}
			try stderr.print("Test mode: running zig unit tests is done via 'zig build test'\n", .{});
			try stderr.flush();
			return 0;
		},
		.err => |msg| {
			try stderr.print("{s}\n", .{msg});
			try stderr.flush();
			return 1;
		},
		.config => |config| {
			var cfg = config;
			defer cfg.deinit(allocator);

			// Resolve the target directory to an absolute path
			const abs_dir = resolveAbsDir(allocator, cfg.dir) catch {
				try stderr.print("Error: '{s}' is not a directory\n", .{cfg.dir});
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

			// Check for regex conflicts (same pattern in both open+close)
			if (checkRegexConflict(allocator, &effective, abs_dir, stderr)) |conflict| {
				try stderr.print("Error: path '{s}' matches both open and close patterns\n", .{conflict.path});
				try stderr.print("  open pattern: {s}\n", .{conflict.pattern});
				try stderr.print("  close pattern: {s}\n", .{conflict.pattern});
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
		removeEntryByValue(&sf.close_entries, lit, false);
		if (!state_mod.StateFile.hasLiteral(sf.open_entries.items, lit)) {
			const val = try sf.dupeStr(lit);
			try sf.addEntry(&sf.open_entries, .{ .value = val, .is_regex = false, .negated = false });
		}
	}
	for (cfg.open_regexes.items) |re| {
		removeEntryByValue(&sf.close_entries, re.value, true);
		if (!state_mod.StateFile.hasRegex(sf.open_entries.items, re.value, re.negated)) {
			const val = try sf.dupeStr(re.value);
			try sf.addEntry(&sf.open_entries, .{ .value = val, .is_regex = true, .negated = re.negated });
		}
	}
	for (cfg.close_literals.items) |lit| {
		removeEntryByValue(&sf.open_entries, lit, false);
		if (!state_mod.StateFile.hasLiteral(sf.close_entries.items, lit)) {
			const val = try sf.dupeStr(lit);
			try sf.addEntry(&sf.close_entries, .{ .value = val, .is_regex = false, .negated = false });
		}
	}
	for (cfg.close_regexes.items) |re| {
		removeEntryByValue(&sf.open_entries, re.value, true);
		if (!state_mod.StateFile.hasRegex(sf.close_entries.items, re.value, re.negated)) {
			const val = try sf.dupeStr(re.value);
			try sf.addEntry(&sf.close_entries, .{ .value = val, .is_regex = true, .negated = re.negated });
		}
	}
	for (cfg.show_literals.items) |lit| {
		removeEntryByValue(&sf.hide_entries, lit, false);
		if (!state_mod.StateFile.hasLiteral(sf.show_entries.items, lit)) {
			const val = try sf.dupeStr(lit);
			try sf.addEntry(&sf.show_entries, .{ .value = val, .is_regex = false, .negated = false });
		}
	}
	for (cfg.show_regexes.items) |re| {
		removeEntryByValue(&sf.hide_entries, re.value, true);
		if (!state_mod.StateFile.hasRegex(sf.show_entries.items, re.value, re.negated)) {
			const val = try sf.dupeStr(re.value);
			try sf.addEntry(&sf.show_entries, .{ .value = val, .is_regex = true, .negated = re.negated });
		}
	}
	for (cfg.hide_literals.items) |lit| {
		removeEntryByValue(&sf.show_entries, lit, false);
		if (!state_mod.StateFile.hasLiteral(sf.hide_entries.items, lit)) {
			const val = try sf.dupeStr(lit);
			try sf.addEntry(&sf.hide_entries, .{ .value = val, .is_regex = false, .negated = false });
		}
	}
	for (cfg.hide_regexes.items) |re| {
		removeEntryByValue(&sf.show_entries, re.value, true);
		if (!state_mod.StateFile.hasRegex(sf.hide_entries.items, re.value, re.negated)) {
			const val = try sf.dupeStr(re.value);
			try sf.addEntry(&sf.hide_entries, .{ .value = val, .is_regex = true, .negated = re.negated });
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
fn removeEntryByValue(list: *std.ArrayListUnmanaged(state_mod.StateEntry), value: []const u8, is_regex: bool) void {
	var i: usize = 0;
	while (i < list.items.len) {
		if (list.items[i].is_regex == is_regex and std.mem.eql(u8, list.items[i].value, value)) {
			_ = list.orderedRemove(i);
		} else {
			i += 1;
		}
	}
}

// Tests
test "help output contains usage" {
	var buf: [4096]u8 = undefined;
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
			try std.testing.expect(cfg.open_regexes.items[0].is_regex);
			// glob *.txt should become ^[^/]*\.txt$
			try std.testing.expectEqualStrings("^[^/]*\\.txt$", cfg.open_regexes.items[0].value);
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
}
