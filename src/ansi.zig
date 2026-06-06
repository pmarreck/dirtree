const std = @import("std");
const i18n = @import("i18n/mod.zig");
const runtime = @import("runtime.zig");

// ANSI color codes
pub const reset = "\x1b[0m";
pub const bold = "\x1b[1m";
pub const dim = "\x1b[2m";
pub const italic = "\x1b[3m";
pub const dim_italic = "\x1b[2;3m";
pub const blue = "\x1b[34m";
pub const bold_blue = "\x1b[1;34m";
pub const green = "\x1b[32m";
pub const bold_green = "\x1b[1;32m";
pub const cyan = "\x1b[36m";
pub const bold_cyan = "\x1b[1;36m";
pub const yellow = "\x1b[33m";
pub const red = "\x1b[31m";

/// OSC8 hyperlink: start
/// Format: \x1b]8;;URL\x1b\\
pub fn writeOsc8Start(writer: anytype, url: []const u8) !void {
	try writer.writeAll("\x1b]8;;");
	try writer.writeAll(url);
	try writer.writeAll("\x1b\\");
}

/// OSC8 hyperlink: end
pub fn writeOsc8End(writer: anytype) !void {
	try writer.writeAll("\x1b]8;;\x1b\\");
}

/// Build a file:// URL from hostname and absolute path.
/// Percent-encodes special characters in the path.
pub fn buildFileUrl(allocator: std.mem.Allocator, abs_path: []const u8) ![]u8 {
	var result: std.ArrayListUnmanaged(u8) = .empty;
	defer result.deinit(allocator);

	try result.appendSlice(allocator, "file://");

	// Get hostname
	const hostname = runtime.getEnv("HOSTNAME") orelse
		runtime.getEnv("HOST") orelse
		"";
	try result.appendSlice(allocator, hostname);

	// Percent-encode the path
	for (abs_path) |c| {
		if (shouldPercentEncode(c)) {
			try result.append(allocator, '%');
			const hex = "0123456789ABCDEF";
			try result.append(allocator, hex[c >> 4]);
			try result.append(allocator, hex[c & 0x0f]);
		} else {
			try result.append(allocator, c);
		}
	}

	return try result.toOwnedSlice(allocator);
}

fn shouldPercentEncode(c: u8) bool {
	// RFC 3986: unreserved = ALPHA / DIGIT / "-" / "." / "_" / "~"
	// Also allow "/" and ":" for paths
	if (std.ascii.isAlphanumeric(c)) return false;
	return switch (c) {
		'-', '.', '_', '~', '/', ':' => false,
		else => true,
	};
}

/// Format display options
pub const DisplayMode = struct {
	use_color: bool = true,
	use_icons: bool = true,
	use_hyperlinks: bool = true,
};

/// Write a colored directory name.
pub fn writeDirName(writer: anytype, name: []const u8, mode: DisplayMode) !void {
	if (mode.use_color) {
		try writer.writeAll(bold_blue);
	}
	try writer.writeAll(name);
	try writer.writeAll("/");
	if (mode.use_color) {
		try writer.writeAll(reset);
	}
}

/// Write a colored file name.
pub fn writeFileName(writer: anytype, name: []const u8, is_executable: bool, is_symlink: bool, mode: DisplayMode) !void {
	if (mode.use_color) {
		if (is_symlink) {
			try writer.writeAll(bold_cyan);
		} else if (is_executable) {
			try writer.writeAll(bold_green);
		}
	}
	try writer.writeAll(name);
	if (mode.use_color) {
		if (is_symlink or is_executable) {
			try writer.writeAll(reset);
		}
	}
}

/// Write the hidden count message to stderr.
pub fn writeStatsMessage(writer: anytype, shown_dirs: u32, shown_files: u32, total_lines: u32, hidden_dirs: u32, hidden_files: u32, scm_kept_dirs: u32, scm_kept_files: u32, simple_mode: bool) !void {
	const has_hidden = hidden_dirs > 0 or hidden_files > 0;
	const has_scm = scm_kept_dirs > 0 or scm_kept_files > 0;
	if (!has_hidden and !has_scm) return;
	const has_shown = shown_dirs > 0 or shown_files > 0;

	const s = i18n.tr();

	try writer.writeAll("\n");
	if (!simple_mode) {
		try writer.writeAll(dim_italic);
	}

	// Shown section: "N directories and M files shown (L lines)"
	if (has_shown) {
		var wrote_part = false;
		if (shown_dirs > 0) {
			if (shown_dirs == 1) {
				try writer.print("1 {s}", .{s.hidden_dir_singular});
			} else {
				try writer.print("{} {s}", .{ shown_dirs, s.hidden_dir_plural });
			}
			wrote_part = true;
		}
		if (shown_files > 0) {
			if (wrote_part) try writer.writeAll(s.hidden_and);
			if (shown_files == 1) {
				try writer.print("1 {s}", .{s.hidden_file_singular});
			} else {
				try writer.print("{} {s}", .{ shown_files, s.hidden_file_plural });
			}
		}
		try writer.writeAll(s.stats_shown);
		// Line count
		if (total_lines > 0) {
			const line_word = if (total_lines == 1) s.stats_line_singular else s.stats_line_plural;
			try writer.print(" ({} {s})", .{ total_lines, line_word });
		}
	}

	// Hidden section: "N directories and M files hidden."
	if (has_hidden) {
		if (has_shown) try writer.writeAll(s.stats_separator);
		var wrote_part = false;
		if (hidden_dirs > 0) {
			if (hidden_dirs == 1) {
				try writer.print("1 {s}", .{s.hidden_dir_singular});
			} else {
				try writer.print("{} {s}", .{ hidden_dirs, s.hidden_dir_plural });
			}
			wrote_part = true;
		}
		if (hidden_files > 0) {
			if (wrote_part) try writer.writeAll(s.hidden_and);
			if (hidden_files == 1) {
				try writer.print("1 {s}", .{s.hidden_file_singular});
			} else {
				try writer.print("{} {s}", .{ hidden_files, s.hidden_file_plural });
			}
		}
		try writer.writeAll(s.stats_hidden);
	}

	if (has_scm) {
		if (has_shown or has_hidden) try writer.writeAll(s.stats_separator);
		var wrote_part = false;
		if (scm_kept_dirs > 0) {
			if (scm_kept_dirs == 1) {
				try writer.print("1 {s}", .{s.hidden_dir_singular});
			} else {
				try writer.print("{} {s}", .{ scm_kept_dirs, s.hidden_dir_plural });
			}
			wrote_part = true;
		}
		if (scm_kept_files > 0) {
			if (wrote_part) try writer.writeAll(s.hidden_and);
			if (scm_kept_files == 1) {
				try writer.print("1 {s}", .{s.hidden_file_singular});
			} else {
				try writer.print("{} {s}", .{ scm_kept_files, s.hidden_file_plural });
			}
		}
		try writer.writeAll(s.stats_scm_kept);
	}

	if (!simple_mode) {
		try writer.writeAll(reset);
	}
	try writer.writeAll("\n");
}

// Tests

test "shouldPercentEncode" {
	try std.testing.expect(!shouldPercentEncode('a'));
	try std.testing.expect(!shouldPercentEncode('/'));
	try std.testing.expect(shouldPercentEncode(' '));
	try std.testing.expect(shouldPercentEncode('#'));
	try std.testing.expect(shouldPercentEncode('%'));
}

test "buildFileUrl: simple path" {
	const allocator = std.testing.allocator;
	const url = try buildFileUrl(allocator, "/tmp/test");
	defer allocator.free(url);
	try std.testing.expect(std.mem.startsWith(u8, url, "file://"));
	try std.testing.expect(std.mem.endsWith(u8, url, "/tmp/test"));
}

test "buildFileUrl: path with spaces" {
	const allocator = std.testing.allocator;
	const url = try buildFileUrl(allocator, "/tmp/my dir/file");
	defer allocator.free(url);
	try std.testing.expect(std.mem.indexOf(u8, url, "%20") != null);
}

test "writeStatsMessage: hidden only" {
	var buf: [256]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	try writeStatsMessage(&fbs, 0, 0, 0, 0, 1, 0, 0, true);
	const output = fbs.buffered();
	try std.testing.expect(std.mem.indexOf(u8, output, "1 file hidden.") != null);
}

test "writeStatsMessage: shown and hidden" {
	var buf: [512]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	try writeStatsMessage(&fbs, 3, 10, 42, 2, 3, 0, 0, true);
	const output = fbs.buffered();
	try std.testing.expect(std.mem.indexOf(u8, output, "3 directories and 10 files shown (42 lines)") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "2 directories and 3 files hidden.") != null);
}
