const std = @import("std");
const runtime = @import("runtime.zig");

pub const EntryKind = enum {
	directory,
	file,
	symlink,
};

pub const DirEntry = struct {
	name: []const u8, // owned by caller/arena
	kind: EntryKind,
	mtime: i128, // nanoseconds since epoch
	mode: u32, // permission bits from stat
};

pub const StatInfo = struct {
	mtime: i128,
	mode: u32,
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
	var entries: std.ArrayListUnmanaged(DirEntry) = .empty;
	defer entries.deinit(allocator);

	const io = runtime.io();
	var dir = std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch |err| {
		switch (err) {
			error.AccessDenied, error.FileNotFound => return try entries.toOwnedSlice(allocator),
			else => return err,
		}
	};
	defer dir.close(io);

	const need_stat = sort_mode == .modified;
	var iter = dir.iterate();
	while (try iter.next(io)) |entry| {
		const kind: EntryKind = switch (entry.kind) {
			.directory => .directory,
			.sym_link => .symlink,
			else => .file,
		};

		// Only stat when needed for mtime sorting; mode is fetched lazily during render
		const stat_info: StatInfo = if (need_stat) getStatInfo(dir, entry.name) else .{ .mtime = 0, .mode = 0 };

		const name = try allocator.dupe(u8, entry.name);
		try entries.append(allocator, .{
			.name = name,
			.kind = kind,
			.mtime = stat_info.mtime,
			.mode = stat_info.mode,
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
	const io = runtime.io();
	var dir = std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch return false;
	defer dir.close(io);
	var iter = dir.iterate();
	if ((iter.next(io) catch null)) |_| {
		return true;
	}
	return false;
}

fn getStatInfo(dir: std.Io.Dir, name: []const u8) StatInfo {
	const stat = dir.statFile(runtime.io(), name, .{}) catch |err| {
		switch (err) {
			else => return .{ .mtime = 0, .mode = 0 },
		}
	};
	return .{
		.mtime = @intCast(stat.mtime.nanoseconds),
		.mode = @intCast(stat.permissions.toMode()),
	};
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
	// The project root must actually contain build.zig — assert it by name, not
	// just len>0 (which a broken scanner returning garbage could also satisfy).
	var found_build_zig = false;
	for (entries) |e| {
		if (std.mem.eql(u8, e.name, "build.zig")) found_build_zig = true;
	}
	try std.testing.expect(found_build_zig);
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
