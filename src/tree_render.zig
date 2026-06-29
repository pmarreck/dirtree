const std = @import("std");
const ansi = @import("ansi.zig");
const icons = @import("icons.zig");
const dir_scan = @import("dir_scan.zig");
const path_eval = @import("path_eval.zig");
const i18n = @import("i18n/mod.zig");
const runtime = @import("runtime.zig");

/// Configuration for the tree renderer.
/// Tracks the current display column while forwarding bytes to an inner writer
/// (or discarding when inner == null). Counts one cell per UTF-8 codepoint and
/// skips ANSI CSI and OSC 8 escape sequences, so note gutters can be aligned
/// without a separate width function. Duck-typed: the render path only calls
/// writeAll.
const ColumnTracker = struct {
	inner: ?*std.Io.Writer = null,
	col: usize = 0,
	esc: Esc = .none,
	const Esc = enum { none, esc, csi, osc, osc_esc };
	pub fn writeAll(self: *ColumnTracker, bytes: []const u8) !void {
		if (self.inner) |w| try w.writeAll(bytes);
		for (bytes) |b| {
			switch (self.esc) {
				.none => {
					if (b == 0x1b) {
						self.esc = .esc;
					} else if (b == '\n') {
						self.col = 0;
					} else if (b & 0xC0 != 0x80) {
						// Count UTF-8 lead/single bytes (skip continuation bytes).
						self.col += 1;
					}
				},
				.esc => self.esc = if (b == '[') .csi else if (b == ']') .osc else .none,
				.csi => { if (b >= 0x40 and b <= 0x7e) self.esc = .none; },
				.osc => { if (b == 0x07) { self.esc = .none; } else if (b == 0x1b) { self.esc = .osc_esc; } },
				.osc_esc => self.esc = .none,
			}
		}
	}
};

/// Shared note-alignment state. In measuring mode it records the widest
/// pre-note column; in render mode it pads each note out to `gutter`.
const Aligner = struct {
	measuring: bool = false,
	gutter: usize = 0,
	max_pre_note: usize = 0,
};

/// Write an entry's note. Aligned (padded to the gutter, min one space) when an
/// Aligner is active and the writer tracks columns; otherwise inline (a single
/// leading space). In measuring mode it only records the column and emits
/// nothing.
fn writeNote(writer: anytype, config: RenderConfig, desc: []const u8) !void {
	if (!config.show_notes or desc.len == 0) return;
	if (config.note_aligner) |aligner| {
		if (@hasField(@typeInfo(@TypeOf(writer)).pointer.child, "col")) {
			if (aligner.measuring) {
				if (writer.col > aligner.max_pre_note) aligner.max_pre_note = writer.col;
				return;
			}
			const pad: usize = if (writer.col < aligner.gutter) aligner.gutter - writer.col else 1;
			if (config.note_leader and pad >= 3) {
				// Dim middle-dot leaders connect the name to its note. They sit
				// inside the OSC 8 span, so the hover-underline traces the line.
				try writer.writeAll(" ");
				if (config.use_color) try writer.writeAll(ansi.dim);
				var k: usize = 0;
				while (k < pad - 2) : (k += 1) try writer.writeAll("\u{00b7}");
				if (config.use_color) try writer.writeAll(ansi.reset);
				try writer.writeAll(" ");
			} else {
				var k: usize = 0;
				while (k < pad) : (k += 1) try writer.writeAll(" ");
			}
			if (config.use_color) try writer.writeAll(ansi.dim);
			try writer.writeAll("# ");
			try writer.writeAll(desc);
			if (config.use_color) try writer.writeAll(ansi.reset);
			return;
		}
	}
	// Inline fallback (ragged): single leading space.
	if (config.use_color) try writer.writeAll(ansi.dim);
	try writer.writeAll(" # ");
	try writer.writeAll(desc);
	if (config.use_color) try writer.writeAll(ansi.reset);
}

/// Defaults applied when neither a CLI flag nor persisted state sets the value.
pub const DEFAULT_DEPTH: u32 = 4;
pub const DEFAULT_NOTE_COLUMN: u32 = 40;
pub const DEFAULT_MAX_LINES: u32 = 500;

pub const RenderConfig = struct {
	use_color: bool = true,
	use_icons: bool = true,
	use_hyperlinks: bool = true,
	simple_mode: bool = false,
	report_hidden: bool = true,
	show_notes: bool = true,
	note_align: bool = true,
	note_column: usize = 40,
	note_aligner: ?*Aligner = null,
	note_leader: bool = false,
	max_depth: u32 = 4,
	show_hidden: bool = false,
	sort_mode: dir_scan.SortMode = .modified,
	sort_direction: dir_scan.SortDirection = .desc,
	only_paths: []const []const u8 = &.{},
};

/// Tree connector characters.
const BRANCH = "├── ";
const LAST = "└── ";
const VERT = "│   ";
const SPACE = "    ";

/// Aggregated statistics from tree rendering.
pub const TreeStats = struct {
	hidden_dirs: u32 = 0,
	hidden_files: u32 = 0,
	shown_dirs: u32 = 0,
	shown_files: u32 = 0,
	total_lines: u32 = 0,
	scm_kept_dirs: u32 = 0,
	scm_kept_files: u32 = 0,
};

/// Render a complete directory tree.
/// Writer adapter that appends to an ArrayListUnmanaged(u8).

pub fn renderTree(
	allocator: std.mem.Allocator,
	stdout: anytype,
	stderr: anytype,
	abs_dir: []const u8,
	effective: *path_eval.EffectiveState,
	priority_dirs: ?*const std.StringHashMapUnmanaged(void),
	priority_files: ?*const std.StringHashMapUnmanaged(void),
	config: RenderConfig,
) !void {

	// Normal (non-tail) rendering path.
	// Wrap stdout so we can track the display column for note alignment.
	var col_tracker = ColumnTracker{ .inner = stdout };
	var aligner = Aligner{};
	var rcfg = config;
	if (config.show_notes and config.note_align) {
		// Measure pass: run the SAME render fns into a discarding tracker to
		// find the widest pre-note column (no stats are emitted here).
		aligner.measuring = true;
		var mcfg = config;
		mcfg.note_aligner = &aligner;
		var mtracker = ColumnTracker{ .inner = null };
		try renderRootHeader(allocator, &mtracker, abs_dir, mcfg, effective);
		var mstats = TreeStats{};
		mstats.total_lines = 1;
		if (config.only_paths.len > 0) {
			var mfocus = try buildFocusSet(allocator, config.only_paths);
			defer mfocus.deinit();
			try renderDirFocused(allocator, &mtracker, abs_dir, "", config.max_depth, false, "", effective, priority_dirs, priority_files, mcfg, &mstats, &mfocus);
		} else {
			try renderDir(allocator, &mtracker, abs_dir, "", config.max_depth, false, "", effective, priority_dirs, priority_files, mcfg, &mstats);
		}
		aligner.gutter = @min(aligner.max_pre_note + 1, config.note_column);
		aligner.measuring = false;
		rcfg.note_aligner = &aligner;
	}

	try renderRootHeader(allocator, &col_tracker, abs_dir, rcfg, effective);

	var stats = TreeStats{};
	stats.total_lines = 1; // root header line

	if (config.only_paths.len > 0) {
		// Focused rendering mode
		var focus = try buildFocusSet(allocator, config.only_paths);
		defer focus.deinit();
		try renderDirFocused(
			allocator, &col_tracker, abs_dir, "", config.max_depth, false, "",
			effective, priority_dirs, priority_files, rcfg, &stats, &focus,
		);
	} else {
		try renderDir(
			allocator, &col_tracker, abs_dir, "", config.max_depth, false, "",
			effective, priority_dirs, priority_files, rcfg, &stats,
		);
	}

	// Report stats to stderr (only in decorated mode)
	if (config.report_hidden) {
		try ansi.writeStatsMessage(stderr, stats.shown_dirs, stats.shown_files, stats.total_lines, stats.hidden_dirs, stats.hidden_files, stats.scm_kept_dirs, stats.scm_kept_files, config.simple_mode);
	}
}

/// Render the root directory header line.
/// In simple/no-color mode: <icon> <abs_path>/\n
/// In decorated mode: <blue><icon> <cyan><parent_path>/<reset><hyperlink><bold_blue><basename><reset>/</hyperlink>\n
fn renderRootHeader(
	allocator: std.mem.Allocator,
	writer: anytype,
	abs_dir: []const u8,
	config: RenderConfig,
	effective: *path_eval.EffectiveState,
) !void {
	const basename = std.fs.path.basename(abs_dir);
	const display_name = if (basename.len == 0) "/" else basename;

	if (config.use_color) {
		// Decorated mode: parent path in cyan, basename in bold blue
		const parent_path = std.fs.path.dirname(abs_dir) orelse "/";

		if (config.use_icons) {
			const icon = icons.getDirIcon(display_name);
			try writer.writeAll(ansi.blue);
			try writer.writeAll(icon);
			try writer.writeAll(" ");
		}

		// Parent path prefix in cyan
		try writer.writeAll(ansi.cyan);
		try writer.writeAll(parent_path);
		if (!std.mem.endsWith(u8, parent_path, "/")) {
			try writer.writeAll("/");
		}
		try writer.writeAll(ansi.reset);

		// Hyperlinked basename in bold blue
		if (config.use_hyperlinks) {
			const url = try ansi.buildFileUrl(allocator, abs_dir);
			defer allocator.free(url);
			try ansi.writeOsc8Start(writer, url);
		}

		try writer.writeAll(ansi.bold_blue);
		try writer.writeAll(display_name);
		try writer.writeAll(ansi.reset);
		try writer.writeAll("/");
	} else {
		// Simple mode: show full absolute path
		if (config.use_icons) {
			const icon = icons.getDirIcon(display_name);
			try writer.writeAll(icon);
			try writer.writeAll(" ");
		}

		try writer.writeAll(abs_dir);
		try writer.writeAll("/");
	}

	// Annotation for the root directory itself, if any
	if (effective.annotations.get(".")) |desc| {
		try writeNote(writer, config, desc);
	}

	if (config.use_hyperlinks) {
		try ansi.writeOsc8End(writer);
	}

	try writer.writeAll("\n");
}

/// Recursively render a directory's contents.
fn renderDir(
	allocator: std.mem.Allocator,
	writer: anytype,
	abs_dir: []const u8,
	rel_dir: []const u8,
	depth_left: u32,
	parent_closed: bool,
	prefix: []const u8,
	effective: *path_eval.EffectiveState,
	priority_dirs: ?*const std.StringHashMapUnmanaged(void),
	priority_files: ?*const std.StringHashMapUnmanaged(void),
	config: RenderConfig,
	stats: *TreeStats,
) !void {
	if (depth_left == 0) return;

	// Build the actual directory path
	const scan_path = if (rel_dir.len == 0)
		abs_dir
	else blk: {
		const p = try std.fs.path.join(allocator, &.{ abs_dir, rel_dir });
		break :blk p;
	};
	defer if (rel_dir.len > 0) allocator.free(scan_path);

	// Scan directory entries
	const entries = try dir_scan.scanDir(allocator, scan_path, config.sort_mode, config.sort_direction);
	defer dir_scan.freeEntries(allocator, entries);

	// First pass: evaluate and filter entries
	var visible = std.ArrayListUnmanaged(VisibleEntry).empty;
	defer visible.deinit(allocator);
	defer {
		for (visible.items) |v| allocator.free(v.child_rel);
	}

	for (entries) |entry| {
		// Skip . and ..
		if (std.mem.eql(u8, entry.name, ".") or std.mem.eql(u8, entry.name, "..")) continue;

		// Build relative path for this entry
		const child_rel = if (rel_dir.len == 0)
			try allocator.dupe(u8, entry.name)
		else
			try std.fs.path.join(allocator, &.{ rel_dir, entry.name });
		defer allocator.free(child_rel);

		// Evaluate the path
		const eval_result = effective.evaluatePath(
			child_rel,
			parent_closed,
			config.show_hidden,
			entry.kind == .directory,
			priority_dirs,
			priority_files,
		);

		if (eval_result.is_hidden) {
			// Don't count .dirtree-state in hidden totals (silently excluded)
			if (!std.mem.eql(u8, entry.name, ".dirtree-state")) {
				if (entry.kind == .directory) {
					stats.hidden_dirs += 1;
				} else {
					stats.hidden_files += 1;
				}
			}
			continue;
		}

		// Track shown counts
		if (entry.kind == .directory) {
			stats.shown_dirs += 1;
		} else {
			stats.shown_files += 1;
		}
		if (eval_result.scm_kept) {
			if (entry.kind == .directory) {
				stats.scm_kept_dirs += 1;
			} else {
				stats.scm_kept_files += 1;
			}
		}

		try visible.append(allocator, .{
			.entry = entry,
			.is_closed = eval_result.is_closed,
			.child_rel = try allocator.dupe(u8, child_rel),
		});
	}

	// Second pass: render visible entries
	for (visible.items, 0..) |vis, idx| {
		const is_last = idx == visible.items.len - 1;
		const connector = if (is_last) LAST else BRANCH;
		const next_prefix_ext = if (is_last) SPACE else VERT;

		// Build next prefix
		const next_prefix = try std.fmt.allocPrint(allocator, "{s}{s}", .{ prefix, next_prefix_ext });
		defer allocator.free(next_prefix);

		if (vis.entry.kind == .directory) {
			// Determine marker
			var marker: []const u8 = "/";
			if (vis.is_closed or (!vis.is_closed and depth_left <= 1)) {
				// Check if dir has children for /* marker
				// (applies to closed dirs AND dirs truncated by depth limit)
				const child_path = if (rel_dir.len == 0)
					try std.fs.path.join(allocator, &.{ abs_dir, vis.entry.name })
				else
					try std.fs.path.join(allocator, &.{ abs_dir, vis.child_rel });
				defer allocator.free(child_path);

				if (dir_scan.dirHasChildren(child_path)) {
					marker = "/*";
				}
			}

			try renderDirEntry(allocator, writer, abs_dir, vis.entry.name, vis.child_rel, prefix, connector, marker, config, effective);
			stats.total_lines += 1;

			// Recurse into non-closed directories
			if (!vis.is_closed and depth_left > 1) {
				try renderDir(
					allocator,
					writer,
					abs_dir,
					vis.child_rel,
					depth_left - 1,
					vis.is_closed,
					next_prefix,
					effective,
					priority_dirs,
					priority_files,
					config,
					stats,
				);
			}
		} else {
			const is_executable = (vis.entry.mode & 0o111) != 0;
			const is_symlink = vis.entry.kind == .symlink;

			try renderFileEntry(allocator, writer, abs_dir, vis.entry.name, vis.child_rel, prefix, connector, is_executable, is_symlink, config, effective);
			stats.total_lines += 1;
		}
	}
}

/// Lightweight pre-scan to estimate the number of visible lines without rendering.
/// Used to warn when piped output may be too large for LLM context windows.
pub fn countVisibleEntries(
	allocator: std.mem.Allocator,
	abs_dir: []const u8,
	rel_dir: []const u8,
	depth_left: u32,
	parent_closed: bool,
	effective: *path_eval.EffectiveState,
	priority_dirs: ?*const std.StringHashMapUnmanaged(void),
	priority_files: ?*const std.StringHashMapUnmanaged(void),
	show_hidden: bool,
) u32 {
	if (depth_left == 0) return 0;

	const scan_path = if (rel_dir.len == 0)
		abs_dir
	else blk: {
		const p = std.fs.path.join(allocator, &.{ abs_dir, rel_dir }) catch return 0;
		break :blk p;
	};
	defer if (rel_dir.len > 0) allocator.free(scan_path);

	const entries = dir_scan.scanDir(allocator, scan_path, .alpha, .asc) catch return 0;
	defer dir_scan.freeEntries(allocator, entries);

	var count: u32 = 0;
	for (entries) |entry| {
		if (std.mem.eql(u8, entry.name, ".") or std.mem.eql(u8, entry.name, "..")) continue;

		const child_rel = if (rel_dir.len == 0)
			allocator.dupe(u8, entry.name) catch return count
		else
			std.fs.path.join(allocator, &.{ rel_dir, entry.name }) catch return count;
		defer allocator.free(child_rel);

		const eval_result = effective.evaluatePath(
			child_rel,
			parent_closed,
			show_hidden,
			entry.kind == .directory,
			priority_dirs,
			priority_files,
		);

		if (eval_result.is_hidden) continue;

		count += 1;

		if (entry.kind == .directory and !eval_result.is_closed and depth_left > 1) {
			count += countVisibleEntries(
				allocator,
				abs_dir,
				child_rel,
				depth_left - 1,
				eval_result.is_closed,
				effective,
				priority_dirs,
				priority_files,
				show_hidden,
			);
		}
	}
	return count;
}

/// Focus set for --only mode. Tracks which relative paths are ancestors of targets,
/// which are the targets themselves, and provides query methods.
pub const FocusSet = struct {
	/// Directories that are ancestors of target paths (need focused recursion)
	ancestors: std.StringHashMapUnmanaged(void) = .empty,
	/// The target directories themselves (get full-depth normal rendering)
	targets: std.StringHashMapUnmanaged(void) = .empty,
	allocator: std.mem.Allocator,

	pub fn init(allocator: std.mem.Allocator) FocusSet {
		return .{ .allocator = allocator };
	}

	pub fn deinit(self: *FocusSet) void {
		// Free all duped keys
		{
			var it = self.ancestors.keyIterator();
			while (it.next()) |key| {
				self.allocator.free(key.*);
			}
			self.ancestors.deinit(self.allocator);
		}
		{
			var it = self.targets.keyIterator();
			while (it.next()) |key| {
				self.allocator.free(key.*);
			}
			self.targets.deinit(self.allocator);
		}
	}

	pub fn isAncestor(self: *const FocusSet, rel: []const u8) bool {
		return self.ancestors.contains(rel);
	}

	pub fn isTarget(self: *const FocusSet, rel: []const u8) bool {
		return self.targets.contains(rel);
	}

	/// Check if rel is under any target (i.e., a target is a prefix of rel)
	pub fn isUnderTarget(self: *const FocusSet, rel: []const u8) bool {
		// Walk up path components checking if any parent is a target.
		// This is O(depth) instead of O(targets) since depth is bounded
		// by max_depth (typically 4-8), making it effectively O(1).
		var i: usize = rel.len;
		while (i > 0) {
			i -= 1;
			if (rel[i] == '/') {
				if (self.targets.contains(rel[0..i])) return true;
			}
		}
		return false;
	}
};

/// Build a FocusSet from a list of --only paths.
/// For each path like "src/lib", decomposes into ancestors {src} and targets {src/lib}.
pub fn buildFocusSet(allocator: std.mem.Allocator, only_paths: []const []const u8) !FocusSet {
	var fs = FocusSet.init(allocator);
	errdefer fs.deinit();

	for (only_paths) |path| {
		// Add the target itself
		if (!fs.targets.contains(path)) {
			const duped = try allocator.dupe(u8, path);
			try fs.targets.put(allocator, duped, {});
		}

		// Decompose into ancestor prefixes
		var i: usize = 0;
		while (i < path.len) : (i += 1) {
			if (path[i] == '/') {
				const prefix = path[0..i];
				if (!fs.ancestors.contains(prefix) and !fs.targets.contains(prefix)) {
					const duped = try allocator.dupe(u8, prefix);
					try fs.ancestors.put(allocator, duped, {});
				}
			}
		}
	}
	return fs;
}

/// Focused rendering: like renderDir but focus-aware.
/// - Ancestor dirs: rendered + recursed via renderDirFocused
/// - Target dirs: rendered + recursed via normal renderDir (full depth)
/// - Under-target: rendered via normal renderDir
/// - Other sibling dirs: rendered as collapsed single-line (no recursion)
/// - Files: always rendered
fn renderDirFocused(
	allocator: std.mem.Allocator,
	writer: anytype,
	abs_dir: []const u8,
	rel_dir: []const u8,
	depth_left: u32,
	parent_closed: bool,
	prefix: []const u8,
	effective: *path_eval.EffectiveState,
	priority_dirs: ?*const std.StringHashMapUnmanaged(void),
	priority_files: ?*const std.StringHashMapUnmanaged(void),
	config: RenderConfig,
	stats: *TreeStats,
	focus: *const FocusSet,
) !void {
	if (depth_left == 0) return;

	const scan_path = if (rel_dir.len == 0)
		abs_dir
	else blk: {
		const p = try std.fs.path.join(allocator, &.{ abs_dir, rel_dir });
		break :blk p;
	};
	defer if (rel_dir.len > 0) allocator.free(scan_path);

	const entries = try dir_scan.scanDir(allocator, scan_path, config.sort_mode, config.sort_direction);
	defer dir_scan.freeEntries(allocator, entries);

	// First pass: evaluate and filter entries
	var visible = std.ArrayListUnmanaged(VisibleEntry).empty;
	defer visible.deinit(allocator);
	defer {
		for (visible.items) |v| allocator.free(v.child_rel);
	}

	for (entries) |entry| {
		if (std.mem.eql(u8, entry.name, ".") or std.mem.eql(u8, entry.name, "..")) continue;

		const child_rel = if (rel_dir.len == 0)
			try allocator.dupe(u8, entry.name)
		else
			try std.fs.path.join(allocator, &.{ rel_dir, entry.name });
		defer allocator.free(child_rel);

		const eval_result = effective.evaluatePath(
			child_rel,
			parent_closed,
			config.show_hidden,
			entry.kind == .directory,
			priority_dirs,
			priority_files,
		);

		if (eval_result.is_hidden) {
			if (!std.mem.eql(u8, entry.name, ".dirtree-state")) {
				if (entry.kind == .directory) {
					stats.hidden_dirs += 1;
				} else {
					stats.hidden_files += 1;
				}
			}
			continue;
		}

		if (entry.kind == .directory) {
			stats.shown_dirs += 1;
		} else {
			stats.shown_files += 1;
		}
		if (eval_result.scm_kept) {
			if (entry.kind == .directory) {
				stats.scm_kept_dirs += 1;
			} else {
				stats.scm_kept_files += 1;
			}
		}

		try visible.append(allocator, .{
			.entry = entry,
			.is_closed = eval_result.is_closed,
			.child_rel = try allocator.dupe(u8, child_rel),
		});
	}

	// Second pass: render with focus awareness
	for (visible.items, 0..) |vis, idx| {
		const is_last = idx == visible.items.len - 1;
		const connector = if (is_last) LAST else BRANCH;
		const next_prefix_ext = if (is_last) SPACE else VERT;

		const next_prefix = try std.fmt.allocPrint(allocator, "{s}{s}", .{ prefix, next_prefix_ext });
		defer allocator.free(next_prefix);

		if (vis.entry.kind == .directory) {
			const is_ancestor = focus.isAncestor(vis.child_rel);
			const is_target = focus.isTarget(vis.child_rel);
			const is_under = focus.isUnderTarget(vis.child_rel);

			if (is_target) {
				// Target dir: render normally with full depth
				var target_marker: []const u8 = "/";
				if (vis.is_closed or (!vis.is_closed and depth_left <= 1)) {
					const child_path = if (rel_dir.len == 0)
						try std.fs.path.join(allocator, &.{ abs_dir, vis.entry.name })
					else
						try std.fs.path.join(allocator, &.{ abs_dir, vis.child_rel });
					defer allocator.free(child_path);
					if (dir_scan.dirHasChildren(child_path)) target_marker = "/*";
				}
				try renderDirEntry(allocator, writer, abs_dir, vis.entry.name, vis.child_rel, prefix, connector, target_marker, config, effective);
				stats.total_lines += 1;
				if (!vis.is_closed and depth_left > 1) {
					try renderDir(
						allocator, writer, abs_dir, vis.child_rel,
						depth_left - 1, vis.is_closed, next_prefix,
						effective, priority_dirs, priority_files,
						config, stats,
					);
				}
			} else if (is_ancestor) {
				// Ancestor dir: render and recurse with focus
				try renderDirEntry(allocator, writer, abs_dir, vis.entry.name, vis.child_rel, prefix, connector, "/", config, effective);
				stats.total_lines += 1;
				if (depth_left > 1) {
					try renderDirFocused(
						allocator, writer, abs_dir, vis.child_rel,
						depth_left - 1, vis.is_closed, next_prefix,
						effective, priority_dirs, priority_files,
						config, stats, focus,
					);
				}
			} else if (is_under) {
				// Under a target: render via normal renderDir
				var marker: []const u8 = "/";
				if (vis.is_closed or (!vis.is_closed and depth_left <= 1)) {
					const child_path = if (rel_dir.len == 0)
						try std.fs.path.join(allocator, &.{ abs_dir, vis.entry.name })
					else
						try std.fs.path.join(allocator, &.{ abs_dir, vis.child_rel });
					defer allocator.free(child_path);
					if (dir_scan.dirHasChildren(child_path)) marker = "/*";
				}
				try renderDirEntry(allocator, writer, abs_dir, vis.entry.name, vis.child_rel, prefix, connector, marker, config, effective);
				stats.total_lines += 1;
				if (!vis.is_closed and depth_left > 1) {
					try renderDir(
						allocator, writer, abs_dir, vis.child_rel,
						depth_left - 1, vis.is_closed, next_prefix,
						effective, priority_dirs, priority_files,
						config, stats,
					);
				}
			} else {
				// Sibling dir: collapsed (show as dir/* if non-empty, dir/ if empty)
				const child_path = if (rel_dir.len == 0)
					try std.fs.path.join(allocator, &.{ abs_dir, vis.entry.name })
				else
					try std.fs.path.join(allocator, &.{ abs_dir, vis.child_rel });
				defer allocator.free(child_path);
				const marker: []const u8 = if (dir_scan.dirHasChildren(child_path)) "/*" else "/";
				try renderDirEntry(allocator, writer, abs_dir, vis.entry.name, vis.child_rel, prefix, connector, marker, config, effective);
				stats.total_lines += 1;
				// No recursion — collapsed
			}
		} else {
			// Files always rendered
			const is_executable = (vis.entry.mode & 0o111) != 0;
			const is_symlink = vis.entry.kind == .symlink;
			try renderFileEntry(allocator, writer, abs_dir, vis.entry.name, vis.child_rel, prefix, connector, is_executable, is_symlink, config, effective);
			stats.total_lines += 1;
		}
	}
}

const VisibleEntry = struct {
	entry: dir_scan.DirEntry,
	is_closed: bool,
	child_rel: []const u8,
};

/// Render a directory entry line.
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
	try writer.writeAll(prefix);
	try writer.writeAll(connector);

	if (config.use_icons) {
		const icon = icons.getDirIcon(name);
		if (config.use_color) {
			try writer.writeAll(ansi.blue);
			try writer.writeAll(icon);
			try writer.writeAll(" ");
			try writer.writeAll(ansi.reset);
		} else {
			try writer.writeAll(icon);
			try writer.writeAll(" ");
		}
	}

	if (config.use_hyperlinks) {
		const abs_path = try std.fs.path.join(allocator, &.{ abs_dir, child_rel });
		defer allocator.free(abs_path);
		const url = try ansi.buildFileUrl(allocator, abs_path);
		defer allocator.free(url);
		try ansi.writeOsc8Start(writer, url);
	}

	// Quote names containing spaces
	const needs_quote = std.mem.indexOfScalar(u8, name, ' ') != null;

	if (config.use_color) {
		try writer.writeAll(ansi.bold_blue);
	}
	if (needs_quote) try writer.writeAll("'");
	try writer.writeAll(name);
	if (needs_quote) try writer.writeAll("'");
	if (config.use_color) {
		try writer.writeAll(ansi.reset);
	}
	try writer.writeAll(marker);

	// Annotation, if any
	if (effective.annotations.get(child_rel)) |desc| {
		try writeNote(writer, config, desc);
	}

	if (config.use_hyperlinks) {
		try ansi.writeOsc8End(writer);
	}

	try writer.writeAll("\n");
}

/// Render a file entry line.
fn renderFileEntry(
	allocator: std.mem.Allocator,
	writer: anytype,
	abs_dir: []const u8,
	name: []const u8,
	child_rel: []const u8,
	prefix: []const u8,
	connector: []const u8,
	is_executable: bool,
	is_symlink: bool,
	config: RenderConfig,
	effective: *path_eval.EffectiveState,
) !void {
	try writer.writeAll(prefix);
	try writer.writeAll(connector);

	if (config.use_icons) {
		const icon = if (is_symlink)
			icons.symlink_icon
		else if (is_executable)
			icons.exec_icon
		else
			icons.getFileIcon(name);

		if (config.use_color) {
			if (is_symlink) {
				try writer.writeAll(ansi.cyan);
			} else if (is_executable) {
				try writer.writeAll(ansi.green);
			}
			try writer.writeAll(icon);
			try writer.writeAll(" ");
			if (is_symlink or is_executable) {
				try writer.writeAll(ansi.reset);
			}
		} else {
			try writer.writeAll(icon);
			try writer.writeAll(" ");
		}
	}

	if (config.use_hyperlinks) {
		const abs_path = try std.fs.path.join(allocator, &.{ abs_dir, child_rel });
		defer allocator.free(abs_path);
		const url = try ansi.buildFileUrl(allocator, abs_path);
		defer allocator.free(url);
		try ansi.writeOsc8Start(writer, url);
	}

	if (config.use_color) {
		if (is_symlink) {
			try writer.writeAll(ansi.bold_cyan);
		} else if (is_executable) {
			try writer.writeAll(ansi.bold_green);
		}
	}
	try writer.writeAll(name);
	if (config.use_color) {
		if (is_symlink or is_executable) {
			try writer.writeAll(ansi.reset);
		}
	}

	if (config.use_hyperlinks and is_symlink) {
		// Close the link after the name for symlinks so the ` -> target`
		// keeps its own terminal-provided link and the note stays outside.
		try ansi.writeOsc8End(writer);
	}

	// Show symlink target
	if (is_symlink) {
		if (readSymlinkTarget(allocator, abs_dir, child_rel)) |target| {
			defer allocator.free(target);
			try writer.writeAll(" -> ");
			const needs_quote = std.mem.indexOfScalar(u8, target, ' ') != null;
			if (needs_quote) try writer.writeAll("'");
			try writer.writeAll(target);
			if (needs_quote) try writer.writeAll("'");
		}
	}

	// Annotation, if any
	if (effective.annotations.get(child_rel)) |desc| {
		try writeNote(writer, config, desc);
	}

	if (config.use_hyperlinks and !is_symlink) {
		// Close after the note so name + note form one link (whole-entry
		// hover/click). Symlinks were already closed above.
		try ansi.writeOsc8End(writer);
	}

	try writer.writeAll("\n");
}

/// Read a symlink's target path. Returns owned slice or null on failure.
fn readSymlinkTarget(allocator: std.mem.Allocator, abs_dir: []const u8, child_rel: []const u8) ?[]const u8 {
	const io = runtime.io();
	var dir = std.Io.Dir.cwd().openDir(io, abs_dir, .{}) catch return null;
	defer dir.close(io);

	var buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
	const n = dir.readLink(io, child_rel, &buf) catch return null;
	return allocator.dupe(u8, buf[0..n]) catch return null;
}

// Tests

test "renderRootHeader: simple mode shows absolute path" {
	const allocator = std.testing.allocator;
	var buf: [1024]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	const writer = &fbs;

	var es = path_eval.EffectiveState{ .allocator = allocator };
	defer es.deinit();

	try renderRootHeader(allocator, writer, "/tmp/test_dir", .{
		.use_color = false,
		.use_icons = true,
		.use_hyperlinks = false,
		.simple_mode = true,
	}, &es);

	const output = fbs.buffered();
	// Should show absolute path with icon and trailing /
	try std.testing.expect(std.mem.indexOf(u8, output, "/tmp/test_dir/") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, icons.dir_icon) != null);
}

test "renderRootHeader: no icons shows absolute path" {
	const allocator = std.testing.allocator;
	var buf: [1024]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	const writer = &fbs;

	var es = path_eval.EffectiveState{ .allocator = allocator };
	defer es.deinit();

	try renderRootHeader(allocator, writer, "/tmp/test_dir", .{
		.use_color = false,
		.use_icons = false,
		.use_hyperlinks = false,
		.simple_mode = true,
	}, &es);

	const output = fbs.buffered();
	try std.testing.expectEqualStrings("/tmp/test_dir/\n", output);
}

test "renderRootHeader: with color shows parent path and basename" {
	const allocator = std.testing.allocator;
	var buf: [1024]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	const writer = &fbs;

	var es = path_eval.EffectiveState{ .allocator = allocator };
	defer es.deinit();

	try renderRootHeader(allocator, writer, "/tmp/test_dir", .{
		.use_color = true,
		.use_icons = false,
		.use_hyperlinks = false,
		.simple_mode = false,
	}, &es);

	const output = fbs.buffered();
	try std.testing.expect(std.mem.indexOf(u8, output, ansi.cyan) != null);
	try std.testing.expect(std.mem.indexOf(u8, output, ansi.bold_blue) != null);
	try std.testing.expect(std.mem.indexOf(u8, output, ansi.reset) != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "/tmp/") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "test_dir") != null);
}

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

test "tree connectors" {
	// Verify connector constants are correct Unicode
	try std.testing.expectEqualStrings("├── ", BRANCH);
	try std.testing.expectEqualStrings("└── ", LAST);
	try std.testing.expectEqualStrings("│   ", VERT);
	try std.testing.expectEqualStrings("    ", SPACE);
}

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

test "renderFileEntry: annotation is dim-styled when use_color=true" {
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
		.use_color = true,
		.use_icons = false,
		.use_hyperlinks = false,
		.simple_mode = false,
	}, &es);

	const output = fbs.buffered();
	try std.testing.expect(std.mem.indexOf(u8, output, ansi.dim ++ " # Demo file" ++ ansi.reset) != null);
}

test "renderFileEntry: annotation has no ANSI when use_color=false" {
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
	try std.testing.expect(std.mem.indexOf(u8, output, "\x1b[") == null);
	try std.testing.expect(std.mem.indexOf(u8, output, " # Demo file") != null);
}
