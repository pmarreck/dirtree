const std = @import("std");
const ansi = @import("ansi.zig");
const icons = @import("icons.zig");
const dir_scan = @import("dir_scan.zig");
const path_eval = @import("path_eval.zig");

/// Configuration for the tree renderer.
pub const RenderConfig = struct {
	use_color: bool = true,
	use_icons: bool = true,
	use_hyperlinks: bool = true,
	simple_mode: bool = false,
	report_hidden: bool = true,
	max_depth: u32 = 4,
	show_hidden: bool = false,
	sort_mode: dir_scan.SortMode = .modified,
	sort_direction: dir_scan.SortDirection = .desc,
};

/// Tree connector characters.
const BRANCH = "├── ";
const LAST = "└── ";
const VERT = "│   ";
const SPACE = "    ";

/// Render a complete directory tree.
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
	// Print root header
	try renderRootHeader(allocator, stdout, abs_dir, config);

	// Render tree recursively
	var hidden_dirs: u32 = 0;
	var hidden_files: u32 = 0;
	try renderDir(
		allocator,
		stdout,
		abs_dir,
		"",
		config.max_depth,
		false,
		"",
		effective,
		priority_dirs,
		priority_files,
		config,
		&hidden_dirs,
		&hidden_files,
	);

	// Report hidden counts to stderr (only in decorated mode)
	if (config.report_hidden) {
		try ansi.writeHiddenCount(stderr, hidden_dirs, hidden_files, config.simple_mode);
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

		if (config.use_hyperlinks) {
			try ansi.writeOsc8End(writer);
		}
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
	hidden_dirs: *u32,
	hidden_files: *u32,
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
	var visible = std.ArrayListUnmanaged(VisibleEntry){};
	defer visible.deinit(allocator);

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
			priority_dirs,
			priority_files,
		);

		if (eval_result.is_hidden) {
			// Don't count .dirtree-state in hidden totals (silently excluded like eza --ignore-glob)
			if (!std.mem.eql(u8, entry.name, ".dirtree-state")) {
				if (entry.kind == .directory) {
					hidden_dirs.* += 1;
				} else {
					hidden_files.* += 1;
				}
			}
			continue;
		}

		try visible.append(allocator, .{
			.entry = entry,
			.is_closed = eval_result.is_closed,
			.child_rel = try allocator.dupe(u8, child_rel),
		});
	}
	defer {
		for (visible.items) |v| allocator.free(v.child_rel);
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
			if (vis.is_closed) {
				// Check if dir has children for /* marker
				const child_path = if (rel_dir.len == 0)
					try std.fs.path.join(allocator, &.{ abs_dir, vis.entry.name })
				else
					try std.fs.path.join(allocator, &.{ abs_dir, vis.child_rel });
				defer allocator.free(child_path);

				if (dir_scan.dirHasChildren(child_path)) {
					marker = "/*";
				}
			}

			try renderDirEntry(allocator, writer, abs_dir, vis.entry.name, vis.child_rel, prefix, connector, marker, config);

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
					hidden_dirs,
					hidden_files,
				);
			}
		} else {
			// Check if file is executable or symlink
			const is_executable = isExecutable(abs_dir, vis.child_rel);
			const is_symlink = vis.entry.kind == .symlink;

			try renderFileEntry(allocator, writer, abs_dir, vis.entry.name, vis.child_rel, prefix, connector, is_executable, is_symlink, config);
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

	if (config.use_hyperlinks) {
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

	try writer.writeAll("\n");
}

/// Check if a file is executable.
fn isExecutable(abs_dir: []const u8, child_rel: []const u8) bool {
	// Use the directory to stat the file
	var dir = std.fs.cwd().openDir(abs_dir, .{}) catch return false;
	defer dir.close();

	const stat = dir.statFile(child_rel) catch return false;
	// Check for executable permission in mode bits
	return (stat.mode & 0o111) != 0;
}

/// Read a symlink's target path. Returns owned slice or null on failure.
fn readSymlinkTarget(allocator: std.mem.Allocator, abs_dir: []const u8, child_rel: []const u8) ?[]const u8 {
	var dir = std.fs.cwd().openDir(abs_dir, .{}) catch return null;
	defer dir.close();

	var buf: [std.fs.max_path_bytes]u8 = undefined;
	const target = dir.readLink(child_rel, &buf) catch return null;
	return allocator.dupe(u8, target) catch return null;
}

// Tests

test "renderRootHeader: simple mode shows absolute path" {
	const allocator = std.testing.allocator;
	var buf: [1024]u8 = undefined;
	var fbs = std.io.fixedBufferStream(&buf);
	const writer = fbs.writer();

	try renderRootHeader(allocator, writer, "/tmp/test_dir", .{
		.use_color = false,
		.use_icons = true,
		.use_hyperlinks = false,
		.simple_mode = true,
	});

	const output = fbs.getWritten();
	// Should show absolute path with icon and trailing /
	try std.testing.expect(std.mem.indexOf(u8, output, "/tmp/test_dir/") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, icons.dir_icon) != null);
}

test "renderRootHeader: no icons shows absolute path" {
	const allocator = std.testing.allocator;
	var buf: [1024]u8 = undefined;
	var fbs = std.io.fixedBufferStream(&buf);
	const writer = fbs.writer();

	try renderRootHeader(allocator, writer, "/tmp/test_dir", .{
		.use_color = false,
		.use_icons = false,
		.use_hyperlinks = false,
		.simple_mode = true,
	});

	const output = fbs.getWritten();
	try std.testing.expectEqualStrings("/tmp/test_dir/\n", output);
}

test "renderRootHeader: with color shows parent path and basename" {
	const allocator = std.testing.allocator;
	var buf: [1024]u8 = undefined;
	var fbs = std.io.fixedBufferStream(&buf);
	const writer = fbs.writer();

	try renderRootHeader(allocator, writer, "/tmp/test_dir", .{
		.use_color = true,
		.use_icons = false,
		.use_hyperlinks = false,
		.simple_mode = false,
	});

	const output = fbs.getWritten();
	try std.testing.expect(std.mem.indexOf(u8, output, ansi.cyan) != null);
	try std.testing.expect(std.mem.indexOf(u8, output, ansi.bold_blue) != null);
	try std.testing.expect(std.mem.indexOf(u8, output, ansi.reset) != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "/tmp/") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "test_dir") != null);
}

test "tree connectors" {
	// Verify connector constants are correct Unicode
	try std.testing.expectEqualStrings("├── ", BRANCH);
	try std.testing.expectEqualStrings("└── ", LAST);
	try std.testing.expectEqualStrings("│   ", VERT);
	try std.testing.expectEqualStrings("    ", SPACE);
}

test "isExecutable: non-existent returns false" {
	try std.testing.expect(!isExecutable("/tmp", "nonexistent_file_xyz"));
}
