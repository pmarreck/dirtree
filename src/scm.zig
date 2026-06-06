const std = @import("std");
const i18n = @import("i18n/mod.zig");
const runtime = @import("runtime.zig");

/// Priority paths collected from SCM (git/jj) for changed files/dirs.
/// These override hide/close for paths with uncommitted changes.
pub const PriorityPaths = struct {
	allocator: std.mem.Allocator,
	files: std.StringHashMapUnmanaged(void) = .empty,
	dirs: std.StringHashMapUnmanaged(void) = .empty,
	enabled: bool = false,
	strings: std.ArrayListUnmanaged([]const u8) = .empty,

	pub fn deinit(self: *PriorityPaths) void {
		const a = self.allocator;
		for (self.strings.items) |s| {
			a.free(s);
		}
		self.strings.deinit(a);
		self.files.deinit(a);
		self.dirs.deinit(a);
	}

	fn dupeStr(self: *PriorityPaths, s: []const u8) ![]const u8 {
		const d = try self.allocator.dupe(u8, s);
		try self.strings.append(self.allocator, d);
		return d;
	}

	/// Add a path and all its parent directories as priority entries.
	fn addPath(self: *PriorityPaths, rel_path: []const u8, is_dir: bool) !void {
		if (rel_path.len == 0) return;

		const key = try self.dupeStr(rel_path);
		if (is_dir) {
			try self.dirs.put(self.allocator, key, {});
		} else {
			try self.files.put(self.allocator, key, {});
		}

		// Add parent directories
		try self.addParentDirs(rel_path);
	}

	fn addParentDirs(self: *PriorityPaths, path: []const u8) !void {
		var p = path;
		while (std.mem.lastIndexOfScalar(u8, p, '/')) |idx| {
			p = p[0..idx];
			if (p.len == 0) break;
			if (self.dirs.contains(p)) break; // already added
			const key = try self.dupeStr(p);
			try self.dirs.put(self.allocator, key, {});
		}
	}
};

/// Collect priority paths from git and/or jj for the given directory.
/// Returns populated PriorityPaths.
/// If DIRTREE_SCM_CHANGES_STAY_HIDDEN_OR_CLOSED is truthy, returns empty (disabled).
pub fn collectPriorityPaths(allocator: std.mem.Allocator, abs_dir: []const u8) !PriorityPaths {
	var priority = PriorityPaths{ .allocator = allocator };
	errdefer priority.deinit();

	// Check if SCM priority is disabled (all locale aliases)
	if (i18n.getEnvLocalized(.dirtree_scm_changes_stay_hidden_or_closed)) |val| {
		if (isTruthy(val)) {
			return priority;
		}
	}

	// jj overrides git: a colocated repo has both, but if this is a jj repo
	// (.jj present) the jj working-copy changeset governs.
	const jj_found = try collectJjPaths(allocator, abs_dir, &priority);
	if (jj_found) {
		if (priority.files.count() > 0 or priority.dirs.count() > 0) {
			priority.enabled = true;
		}
		return priority;
	}

	// Otherwise fall back to git.
	const git_found = try collectGitPaths(allocator, abs_dir, &priority);
	if (git_found) {
		if (priority.files.count() > 0 or priority.dirs.count() > 0) {
			priority.enabled = true;
		}
	}

	return priority;
}

/// Collect changed paths from git.
/// Returns true if we're inside a git repo, false otherwise.
fn collectGitPaths(allocator: std.mem.Allocator, abs_dir: []const u8, priority: *PriorityPaths) !bool {
	// Check if we're in a git repo
	const repo_root = getGitRoot(allocator, abs_dir) catch return false;
	defer allocator.free(repo_root);

	// Get changed files via git status --porcelain -z
	const status_output = runCommand(allocator, &.{ "git", "-C", repo_root, "status", "--porcelain", "-z" }, null) catch return true;
	defer allocator.free(status_output);

	if (status_output.len == 0) return true;

	// Parse NUL-delimited output
	// Each record is: XY path\0 (or XY path\0new_path\0 for renames)
	var iter = std.mem.splitScalar(u8, status_output, 0);
	while (iter.next()) |record| {
		if (record.len < 4) continue; // minimum: "XY path" (2 status chars + space + 1 char)

		var path = record[3..]; // skip "XY " status prefix

		// Handle renames: "old -> new"
		if (std.mem.indexOf(u8, path, " -> ")) |arrow_idx| {
			path = path[arrow_idx + 4 ..];
		}

		if (path.len == 0) continue;

		// Compute path relative to abs_dir
		const rel = computeRelativePath(allocator, abs_dir, repo_root, path) catch continue;
		if (rel) |rel_path| {
			defer allocator.free(rel_path);

			// Check if it's a directory
			const full_path = std.fs.path.join(allocator, &.{ repo_root, path }) catch continue;
			defer allocator.free(full_path);

			const is_dir = blk: {
				var dir = std.Io.Dir.cwd().openDir(runtime.io(), full_path, .{}) catch break :blk false;
				dir.close(runtime.io());
				break :blk true;
			};

			try priority.addPath(rel_path, is_dir);
		}
	}

	return true;
}

/// Collect changed paths from jj.
fn collectJjPaths(allocator: std.mem.Allocator, abs_dir: []const u8, priority: *PriorityPaths) !bool {
	// Check if we're in a jj repo
	const repo_root = getJjRoot(allocator, abs_dir) catch return false;
	defer allocator.free(repo_root);

	// Get changed files via jj diff --name-only
	// Run with cwd = repo_root so jj emits repo-root-relative paths (jj paths
	// are relative to the process cwd, unlike git -C). Without this, paths
	// double-prefix when dirtree is invoked from outside the repo.
	const output = runCommand(allocator, &.{ "jj", "-R", repo_root, "diff", "--name-only" }, repo_root) catch return true;
	defer allocator.free(output);

	var iter = std.mem.splitScalar(u8, output, '\n');
	while (iter.next()) |line| {
		if (line.len == 0) continue;

		const rel = computeRelativePath(allocator, abs_dir, repo_root, line) catch continue;
		if (rel) |rel_path| {
			defer allocator.free(rel_path);

			const full_path = std.fs.path.join(allocator, &.{ repo_root, line }) catch continue;
			defer allocator.free(full_path);

			const is_dir = blk: {
				var dir = std.Io.Dir.cwd().openDir(runtime.io(), full_path, .{}) catch break :blk false;
				dir.close(runtime.io());
				break :blk true;
			};

			try priority.addPath(rel_path, is_dir);
		}
	}

	return true;
}

/// Get the git repository root for a directory.
fn getGitRoot(allocator: std.mem.Allocator, abs_dir: []const u8) ![]const u8 {
	const output = try runCommand(allocator, &.{ "git", "-C", abs_dir, "rev-parse", "--show-toplevel" }, null);
	defer allocator.free(output);

	// Trim trailing newline
	const trimmed = std.mem.trimEnd(u8, output, "\n\r");
	if (trimmed.len == 0) return error.NotAGitRepo;

	return try allocator.dupe(u8, trimmed);
}

/// Get the jj repository root for a directory.
fn getJjRoot(allocator: std.mem.Allocator, abs_dir: []const u8) ![]const u8 {
	const output = try runCommand(allocator, &.{ "jj", "-R", abs_dir, "root" }, null);
	defer allocator.free(output);

	const trimmed = std.mem.trimEnd(u8, output, "\n\r");
	if (trimmed.len == 0) return error.NotAJjRepo;

	return try allocator.dupe(u8, trimmed);
}

/// Compute a path relative to abs_dir from repo_root + repo_relative_path.
/// Returns null if the path is outside abs_dir.
/// Caller owns the returned string (always allocated).
fn computeRelativePath(
	allocator: std.mem.Allocator,
	abs_dir: []const u8,
	repo_root: []const u8,
	repo_rel_path: []const u8,
) !?[]const u8 {
	// Build absolute path
	const abs_path = try std.fs.path.join(allocator, &.{ repo_root, repo_rel_path });
	defer allocator.free(abs_path);

	// Compute relative to abs_dir
	const dir_with_slash = try std.fmt.allocPrint(allocator, "{s}/", .{abs_dir});
	defer allocator.free(dir_with_slash);

	if (std.mem.startsWith(u8, abs_path, dir_with_slash)) {
		return try allocator.dupe(u8, abs_path[dir_with_slash.len..]);
	}

	if (std.mem.eql(u8, abs_path, abs_dir)) {
		return try allocator.dupe(u8, ".");
	}

	// Path is outside abs_dir - use repo_rel_path as fallback
	// (this matches bash behavior where realpath --relative-to fails)
	if (std.mem.startsWith(u8, repo_rel_path, "..")) {
		return null;
	}

	return try allocator.dupe(u8, repo_rel_path);
}

/// Run a command and return its stdout output.
fn runCommand(allocator: std.mem.Allocator, argv: []const []const u8, cwd: ?[]const u8) ![]const u8 {
	const io = runtime.io();
	var child = try std.process.spawn(io, .{
		.argv = argv,
		.stdout = .pipe,
		.stderr = .ignore,
		.cwd = if (cwd) |c| .{ .path = c } else .inherit,
	});

	// Read all stdout from the pipe file
	var read_buf: [4096]u8 = undefined;
	var pipe_reader = child.stdout.?.readerStreaming(io, &read_buf);
	const stdout_output = pipe_reader.interface.allocRemaining(allocator, .limited(1024 * 1024)) catch |err| {
		_ = child.wait(io) catch {};
		return err;
	};
	errdefer allocator.free(stdout_output);

	const term = try child.wait(io);
	switch (term) {
		.exited => |code| if (code != 0) {
			allocator.free(stdout_output);
			return error.CommandFailed;
		},
		else => {
			allocator.free(stdout_output);
			return error.CommandFailed;
		},
	}

	return stdout_output;
}

fn isTruthy(val: []const u8) bool {
	return std.mem.eql(u8, val, "1") or
		std.mem.eql(u8, val, "true") or
		std.mem.eql(u8, val, "TRUE") or
		std.mem.eql(u8, val, "on") or
		std.mem.eql(u8, val, "ON");
}

// Tests

test "PriorityPaths: addPath adds parents" {
	const allocator = std.testing.allocator;
	var priority = PriorityPaths{ .allocator = allocator };
	defer priority.deinit();

	try priority.addPath("src/lib/utils.zig", false);

	try std.testing.expect(priority.files.contains("src/lib/utils.zig"));
	try std.testing.expect(priority.dirs.contains("src/lib"));
	try std.testing.expect(priority.dirs.contains("src"));
}

test "PriorityPaths: addPath directory" {
	const allocator = std.testing.allocator;
	var priority = PriorityPaths{ .allocator = allocator };
	defer priority.deinit();

	try priority.addPath("src/lib", true);

	try std.testing.expect(priority.dirs.contains("src/lib"));
	try std.testing.expect(priority.dirs.contains("src"));
	try std.testing.expect(!priority.files.contains("src/lib"));
}

test "PriorityPaths: empty path ignored" {
	const allocator = std.testing.allocator;
	var priority = PriorityPaths{ .allocator = allocator };
	defer priority.deinit();

	try priority.addPath("", false);

	try std.testing.expectEqual(@as(usize, 0), priority.files.count());
	try std.testing.expectEqual(@as(usize, 0), priority.dirs.count());
}

test "computeRelativePath: inside target dir" {
	const allocator = std.testing.allocator;
	const result = try computeRelativePath(
		allocator,
		"/home/user/project",
		"/home/user/project",
		"src/main.zig",
	);
	try std.testing.expect(result != null);
	// Result is an allocated dupe when repo_root == abs_dir and the path
	// is resolved via the dir_with_slash prefix strip
	defer allocator.free(result.?);
	try std.testing.expectEqualStrings("src/main.zig", result.?);
}

test "computeRelativePath: outside returns null for .." {
	const allocator = std.testing.allocator;
	const result = try computeRelativePath(
		allocator,
		"/home/user/project/sub",
		"/home/user/project",
		"../other/file.zig",
	);
	try std.testing.expect(result == null);
}

test "isTruthy" {
	try std.testing.expect(isTruthy("1"));
	try std.testing.expect(isTruthy("true"));
	try std.testing.expect(isTruthy("TRUE"));
	try std.testing.expect(!isTruthy("0"));
	try std.testing.expect(!isTruthy("false"));
	try std.testing.expect(!isTruthy(""));
}
