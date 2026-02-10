const std = @import("std");

pub const EntryKind = enum {
	directory,
	file,
	symlink,
};

pub const DirEntry = struct {
	name: []const u8, // owned by caller/arena
	kind: EntryKind,
	mtime: i128, // nanoseconds since epoch
};

pub const SortMode = enum {
	modified,
	alpha,
};

pub const SortDirection = enum {
	asc,
	desc,
};

/// Scan a directory and return sorted entries.
/// Caller owns the returned slice and all name strings (allocated from `allocator`).
pub fn scanDir(
	allocator: std.mem.Allocator,
	dir_path: []const u8,
	sort_mode: SortMode,
	sort_direction: SortDirection,
) ![]DirEntry {
	var entries: std.ArrayListUnmanaged(DirEntry) = .{};
	defer entries.deinit(allocator);

	var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch |err| {
		switch (err) {
			error.AccessDenied, error.FileNotFound => return try entries.toOwnedSlice(allocator),
			else => return err,
		}
	};
	defer dir.close();

	var iter = dir.iterate();
	while (try iter.next()) |entry| {
		const kind: EntryKind = switch (entry.kind) {
			.directory => .directory,
			.sym_link => .symlink,
			else => .file,
		};

		// Get mtime via stat
		const mtime = getMtime(dir, entry.name) catch 0;

		const name = try allocator.dupe(u8, entry.name);
		try entries.append(allocator, .{
			.name = name,
			.kind = kind,
			.mtime = mtime,
		});
	}

	const items = try entries.toOwnedSlice(allocator);

	// Sort
	switch (sort_mode) {
		.modified => {
			switch (sort_direction) {
				.desc => std.mem.sort(DirEntry, items, {}, modifiedDescCmp),
				.asc => std.mem.sort(DirEntry, items, {}, modifiedAscCmp),
			}
		},
		.alpha => {
			switch (sort_direction) {
				.asc => std.mem.sort(DirEntry, items, {}, alphaAscCmp),
				.desc => std.mem.sort(DirEntry, items, {}, alphaDescCmp),
			}
		},
	}

	return items;
}

/// Check if a directory has any children (non-empty).
pub fn dirHasChildren(dir_path: []const u8) bool {
	var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return false;
	defer dir.close();
	var iter = dir.iterate();
	if ((iter.next() catch null)) |_| {
		return true;
	}
	return false;
}

fn getMtime(dir: std.fs.Dir, name: []const u8) !i128 {
	const stat = dir.statFile(name) catch |err| {
		switch (err) {
			error.FileNotFound => return 0,
			else => return err,
		}
	};
	return stat.mtime;
}

// Sort comparisons

fn modifiedDescCmp(_: void, a: DirEntry, b: DirEntry) bool {
	if (a.mtime != b.mtime) return a.mtime > b.mtime;
	return std.mem.lessThan(u8, a.name, b.name);
}

fn modifiedAscCmp(_: void, a: DirEntry, b: DirEntry) bool {
	if (a.mtime != b.mtime) return a.mtime < b.mtime;
	return std.mem.lessThan(u8, a.name, b.name);
}

fn alphaAscCmp(_: void, a: DirEntry, b: DirEntry) bool {
	return std.mem.lessThan(u8, a.name, b.name);
}

fn alphaDescCmp(_: void, a: DirEntry, b: DirEntry) bool {
	return std.mem.lessThan(u8, b.name, a.name);
}

/// Free entries returned by scanDir.
pub fn freeEntries(allocator: std.mem.Allocator, entries: []DirEntry) void {
	for (entries) |e| {
		allocator.free(e.name);
	}
	allocator.free(entries);
}

// Tests

test "scanDir returns entries for current directory" {
	const allocator = std.testing.allocator;
	const entries = try scanDir(allocator, ".", .alpha, .asc);
	defer freeEntries(allocator, entries);
	// Current dir should have at least build.zig
	try std.testing.expect(entries.len > 0);
}

test "scanDir alpha sort is alphabetical" {
	const allocator = std.testing.allocator;
	const entries = try scanDir(allocator, ".", .alpha, .asc);
	defer freeEntries(allocator, entries);
	// Verify sorted
	for (1..entries.len) |i| {
		try std.testing.expect(!std.mem.lessThan(u8, entries[i].name, entries[i - 1].name));
	}
}

test "scanDir nonexistent dir returns empty" {
	const allocator = std.testing.allocator;
	const entries = try scanDir(allocator, "/nonexistent_dir_xyz", .alpha, .asc);
	defer freeEntries(allocator, entries);
	try std.testing.expectEqual(@as(usize, 0), entries.len);
}
