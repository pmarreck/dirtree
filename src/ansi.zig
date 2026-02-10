const std = @import("std");

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
	var result: std.ArrayListUnmanaged(u8) = .{};
	defer result.deinit(allocator);

	try result.appendSlice(allocator, "file://");

	// Get hostname
	const hostname = std.posix.getenv("HOSTNAME") orelse
		std.posix.getenv("HOST") orelse
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
pub fn writeHiddenCount(writer: anytype, dir_count: u32, file_count: u32, simple_mode: bool) !void {
	if (dir_count == 0 and file_count == 0) return;

	var parts_buf: [2][]const u8 = undefined;
	var parts_count: usize = 0;
	var msg_buf: [128]u8 = undefined;
	var msg_pos: usize = 0;

	if (dir_count > 0) {
		if (dir_count == 1) {
			const s = "1 directory";
			@memcpy(msg_buf[msg_pos .. msg_pos + s.len], s);
			parts_buf[parts_count] = msg_buf[msg_pos .. msg_pos + s.len];
			msg_pos += s.len;
		} else {
			const written = std.fmt.bufPrint(msg_buf[msg_pos..], "{} directories", .{dir_count}) catch return;
			parts_buf[parts_count] = written;
			msg_pos += written.len;
		}
		parts_count += 1;
	}
	if (file_count > 0) {
		if (file_count == 1) {
			const s = "1 file";
			@memcpy(msg_buf[msg_pos .. msg_pos + s.len], s);
			parts_buf[parts_count] = msg_buf[msg_pos .. msg_pos + s.len];
			msg_pos += s.len;
		} else {
			const written = std.fmt.bufPrint(msg_buf[msg_pos..], "{} files", .{file_count}) catch return;
			parts_buf[parts_count] = written;
			msg_pos += written.len;
		}
		parts_count += 1;
	}

	try writer.writeAll("\n");
	if (!simple_mode) {
		try writer.writeAll(dim_italic);
	}

	for (parts_buf[0..parts_count], 0..) |part, idx| {
		try writer.writeAll(part);
		if (idx < parts_count - 1) {
			try writer.writeAll(" and ");
		}
	}

	const total = dir_count + file_count;
	if (total == 1) {
		try writer.writeAll(" is hidden.");
	} else {
		try writer.writeAll(" are hidden.");
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

test "writeHiddenCount: single file" {
	var buf: [256]u8 = undefined;
	var fbs = std.io.fixedBufferStream(&buf);
	try writeHiddenCount(fbs.writer(), 0, 1, true);
	const output = fbs.getWritten();
	try std.testing.expect(std.mem.indexOf(u8, output, "1 file is hidden.") != null);
}

test "writeHiddenCount: mixed" {
	var buf: [256]u8 = undefined;
	var fbs = std.io.fixedBufferStream(&buf);
	try writeHiddenCount(fbs.writer(), 2, 3, true);
	const output = fbs.getWritten();
	try std.testing.expect(std.mem.indexOf(u8, output, "2 directories and 3 files are hidden.") != null);
}
