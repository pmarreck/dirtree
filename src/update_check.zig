//! GitHub-release update-check cache + version comparison.
//!
//! Cache lives at `${XDG_CACHE_HOME:-$HOME/.cache}/dirtree/update_check`.
//! Two-channel throttling:
//!   - success path: once per calendar day (UTC)
//!   - failure path: exponential backoff (1s, 2s, 4s, ..., capped at next day)
//! Reset triggers:
//!   - new calendar day
//!   - binary mtime changed (new install)
//!   - `--version-check` success forces a fresh fetch and resets counters

const std = @import("std");
const runtime = @import("runtime.zig");

pub const CacheState = struct {
	last_known_version: ?[]const u8 = null,
	last_check_date: u32 = 0, // YYYYMMDD (UTC); 0 = never checked
	binary_mtime: i128 = 0, // nanoseconds since epoch
	fail_count: u32 = 0,
	last_fail_ts: i64 = 0, // unix seconds; 0 = no recent failure
};

pub const VersionOrdering = enum { older, equal, newer };

/// Resolve the cache file path. Caller owns the returned slice.
pub fn cachePath(allocator: std.mem.Allocator) ![]u8 {
	if (runtime.getEnv("XDG_CACHE_HOME")) |xdg| {
		if (xdg.len > 0) {
			return try std.fs.path.join(allocator, &.{ xdg, "dirtree", "update_check" });
		}
	}
	const home = runtime.getEnv("HOME") orelse return error.NoHome;
	return try std.fs.path.join(allocator, &.{ home, ".cache", "dirtree", "update_check" });
}

/// Compare two dotted-semver strings ("1.2.3"). Tolerates a leading 'v'.
/// Returns `.older` if `lhs < rhs`, `.equal` if equal, `.newer` if `lhs > rhs`.
pub fn compareSemver(lhs_in: []const u8, rhs_in: []const u8) VersionOrdering {
	const lhs = stripV(lhs_in);
	const rhs = stripV(rhs_in);
	var li: usize = 0;
	var ri: usize = 0;
	while (true) {
		const l_part = nextPart(lhs, &li);
		const r_part = nextPart(rhs, &ri);
		if (l_part == null and r_part == null) return .equal;
		const l = l_part orelse 0;
		const r = r_part orelse 0;
		if (l < r) return .older;
		if (l > r) return .newer;
	}
}

fn stripV(s: []const u8) []const u8 {
	if (s.len > 0 and (s[0] == 'v' or s[0] == 'V')) return s[1..];
	return s;
}

fn nextPart(s: []const u8, cursor: *usize) ?u64 {
	if (cursor.* >= s.len) return null;
	const start = cursor.*;
	while (cursor.* < s.len and s[cursor.*] != '.') : (cursor.* += 1) {}
	const segment = s[start..cursor.*];
	if (cursor.* < s.len) cursor.* += 1; // skip the '.'
	return std.fmt.parseInt(u64, segment, 10) catch 0;
}

/// Read and parse the cache file. Returns null if missing/unreadable.
/// Caller owns the strings inside the returned state (allocated from `arena`).
pub fn loadCache(arena: std.mem.Allocator, path: []const u8) ?CacheState {
	const io = runtime.io();
	const file = std.Io.Dir.cwd().openFile(io, path, .{}) catch return null;
	defer file.close(io);
	var buf: [4096]u8 = undefined;
	var fr = file.reader(io, &buf);
	const reader = &fr.interface;
	const contents = reader.allocRemaining(arena, .unlimited) catch return null;
	return parseCache(arena, contents) catch null;
}

fn parseCache(arena: std.mem.Allocator, body: []const u8) !CacheState {
	var state = CacheState{};
	var lines = std.mem.splitScalar(u8, body, '\n');
	while (lines.next()) |raw| {
		const line = std.mem.trim(u8, raw, " \t\r");
		if (line.len == 0 or line[0] == '#') continue;
		const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
		const key = std.mem.trim(u8, line[0..eq], " \t");
		const val = std.mem.trim(u8, line[eq + 1 ..], " \t");
		if (std.mem.eql(u8, key, "last_known_version")) {
			state.last_known_version = try arena.dupe(u8, val);
		} else if (std.mem.eql(u8, key, "last_check_date")) {
			state.last_check_date = std.fmt.parseInt(u32, val, 10) catch 0;
		} else if (std.mem.eql(u8, key, "binary_mtime")) {
			state.binary_mtime = std.fmt.parseInt(i128, val, 10) catch 0;
		} else if (std.mem.eql(u8, key, "fail_count")) {
			state.fail_count = std.fmt.parseInt(u32, val, 10) catch 0;
		} else if (std.mem.eql(u8, key, "last_fail_ts")) {
			state.last_fail_ts = std.fmt.parseInt(i64, val, 10) catch 0;
		}
	}
	return state;
}

/// Atomically write the cache file (create dir if needed).
pub fn saveCache(allocator: std.mem.Allocator, path: []const u8, state: CacheState) !void {
	const io = runtime.io();
	if (std.fs.path.dirname(path)) |dir| {
		std.Io.Dir.cwd().createDirPath(io, dir) catch {};
	}
	const tmp_path = try std.fmt.allocPrint(allocator, "{s}.tmp", .{path});
	defer allocator.free(tmp_path);
	{
		const file = try std.Io.Dir.cwd().createFile(io, tmp_path, .{});
		defer file.close(io);
		var buf: [4096]u8 = undefined;
		var fw = file.writer(io, &buf);
		const writer = &fw.interface;
		try writer.writeAll("# dirtree update-check cache\n");
		if (state.last_known_version) |v| {
			try writer.print("last_known_version={s}\n", .{v});
		}
		try writer.print("last_check_date={d}\n", .{state.last_check_date});
		try writer.print("binary_mtime={d}\n", .{state.binary_mtime});
		try writer.print("fail_count={d}\n", .{state.fail_count});
		try writer.print("last_fail_ts={d}\n", .{state.last_fail_ts});
		try writer.flush();
	}
	try std.Io.Dir.cwd().rename(tmp_path, std.Io.Dir.cwd(), path, io);
}

/// Compute today's date as YYYYMMDD in UTC.
pub fn todayUtc(now_unix: i64) u32 {
	const day_secs: i64 = 86_400;
	const days_since_epoch = @divFloor(now_unix, day_secs);
	const ymd = civilFromDays(days_since_epoch);
	return @as(u32, @intCast(ymd.year)) * 10_000 +
		@as(u32, @intCast(ymd.month)) * 100 +
		@as(u32, @intCast(ymd.day));
}

const YMD = struct { year: i32, month: u8, day: u8 };

/// Convert days-since-Unix-epoch (1970-01-01) to Gregorian Y/M/D.
/// Howard Hinnant's algorithm (public domain).
fn civilFromDays(days: i64) YMD {
	const z = days + 719_468;
	const era = @divFloor(z, 146_097);
	const doe: u32 = @intCast(z - era * 146_097);
	const yoe: u32 = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365;
	const y = @as(i64, @intCast(yoe)) + era * 400;
	const doy: u32 = doe - (365 * yoe + yoe / 4 - yoe / 100);
	const mp: u32 = (5 * doy + 2) / 153;
	const d: u8 = @intCast(doy - (153 * mp + 2) / 5 + 1);
	const m: u8 = @intCast(if (mp < 10) mp + 3 else mp - 9);
	const yy: i32 = @intCast(if (m <= 2) y + 1 else y);
	return .{ .year = yy, .month = m, .day = d };
}

/// Decide whether a fresh network check should run.
/// Logic:
///   - new install (cached binary_mtime != current) -> yes
///   - never checked or new day -> yes
///   - currently in failure backoff -> yes only if backoff elapsed
///   - else no
pub fn shouldFetch(state: CacheState, now_unix: i64, current_binary_mtime: i128) bool {
	if (state.binary_mtime != current_binary_mtime) return true;
	const today = todayUtc(now_unix);
	if (state.last_check_date < today) {
		// New day: check unless we're still inside the failure backoff window.
		if (state.fail_count > 0) {
			const backoff_secs = backoffSeconds(state.fail_count);
			if (now_unix - state.last_fail_ts < backoff_secs) return false;
		}
		return true;
	}
	return false;
}

/// Exponential backoff with cap. 1s, 2s, 4s, ..., max 86400s (one day).
pub fn backoffSeconds(fail_count: u32) i64 {
	if (fail_count == 0) return 0;
	const shift: u6 = if (fail_count >= 17) 17 else @intCast(fail_count - 1);
	const v: i64 = @as(i64, 1) << shift;
	return @min(v, 86_400);
}

/// stat the file at the given absolute path for its mtime (nanoseconds since epoch).
/// Returns 0 if unavailable (so cache comparison falls back to forcing a check).
pub fn binaryMtime(abs_path: []const u8) i128 {
	const io = runtime.io();
	const file = std.Io.Dir.cwd().openFile(io, abs_path, .{}) catch return 0;
	defer file.close(io);
	const st = file.stat(io) catch return 0;
	return st.mtime.nanoseconds;
}

pub const default_url = "https://api.github.com/repos/pmarreck/dirtree/releases/latest";

pub const FetchError = error{
	NetworkUnavailable,
	HttpStatus,
	MalformedResponse,
};

/// Fetch the latest release tag from GitHub. Returns the tag string (e.g. "v1.2.0").
/// The URL is overridable via the DIRTREE_UPDATE_URL env var for tests.
/// Caller owns the returned slice.
pub fn fetchLatestTag(allocator: std.mem.Allocator) FetchError![]u8 {
	const url = runtime.getEnv("DIRTREE_UPDATE_URL") orelse default_url;

	var client = std.http.Client{ .allocator = allocator, .io = runtime.io() };
	defer client.deinit();

	var body: std.Io.Writer.Allocating = .init(allocator);
	defer body.deinit();

	const result = client.fetch(.{
		.location = .{ .url = url },
		.response_writer = &body.writer,
		.extra_headers = &.{
			.{ .name = "user-agent", .value = "dirtree-update-check" },
			.{ .name = "accept", .value = "application/vnd.github+json" },
		},
	}) catch return error.NetworkUnavailable;

	if (result.status != .ok) return error.HttpStatus;

	// Tiny ad-hoc parser: find the first occurrence of `"tag_name":` and read the
	// following JSON string. Avoids pulling in std.json for one field.
	const written = body.written();
	const marker = "\"tag_name\"";
	const start = std.mem.indexOf(u8, written, marker) orelse return error.MalformedResponse;
	const after = start + marker.len;
	const colon = std.mem.indexOfScalarPos(u8, written, after, ':') orelse return error.MalformedResponse;
	const quote_start = std.mem.indexOfScalarPos(u8, written, colon + 1, '"') orelse return error.MalformedResponse;
	const quote_end = std.mem.indexOfScalarPos(u8, written, quote_start + 1, '"') orelse return error.MalformedResponse;
	const tag = written[quote_start + 1 .. quote_end];
	return allocator.dupe(u8, tag) catch return error.NetworkUnavailable;
}
// ── Tests ────────────────────────────────────────────────────────────────

test "compareSemver: numerical not lexical" {
	try std.testing.expectEqual(VersionOrdering.older, compareSemver("1.0.0", "1.0.1"));
	try std.testing.expectEqual(VersionOrdering.newer, compareSemver("1.0.10", "1.0.9"));
	try std.testing.expectEqual(VersionOrdering.equal, compareSemver("1.0.0", "1.0.0"));
	try std.testing.expectEqual(VersionOrdering.older, compareSemver("1.0.0", "v2.0.0"));
	try std.testing.expectEqual(VersionOrdering.equal, compareSemver("v1.0.0", "1.0.0"));
	try std.testing.expectEqual(VersionOrdering.older, compareSemver("1.0", "1.0.1"));
}

test "todayUtc: known Unix-epoch dates" {
	try std.testing.expectEqual(@as(u32, 19700101), todayUtc(0));
	try std.testing.expectEqual(@as(u32, 20000101), todayUtc(946_684_800));
	try std.testing.expectEqual(@as(u32, 20260525), todayUtc(1_779_667_200));
}

test "backoffSeconds: doubles until cap" {
	try std.testing.expectEqual(@as(i64, 0), backoffSeconds(0));
	try std.testing.expectEqual(@as(i64, 1), backoffSeconds(1));
	try std.testing.expectEqual(@as(i64, 2), backoffSeconds(2));
	try std.testing.expectEqual(@as(i64, 4), backoffSeconds(3));
	try std.testing.expectEqual(@as(i64, 65536), backoffSeconds(17));
	try std.testing.expectEqual(@as(i64, 86400), backoffSeconds(18));
	try std.testing.expectEqual(@as(i64, 86400), backoffSeconds(100));
}

test "shouldFetch: new install always triggers" {
	const state = CacheState{ .binary_mtime = 100, .last_check_date = 20260525 };
	try std.testing.expect(shouldFetch(state, 1_779_667_200, 200));
}

test "shouldFetch: same day, same binary, no failures -> skip" {
	const state = CacheState{ .binary_mtime = 100, .last_check_date = 20260525 };
	try std.testing.expect(!shouldFetch(state, 1_779_667_200, 100));
}

test "shouldFetch: new day -> fetch (no failures)" {
	const state = CacheState{ .binary_mtime = 100, .last_check_date = 20260524 };
	try std.testing.expect(shouldFetch(state, 1_779_667_200, 100));
}

test "shouldFetch: failure backoff blocks until elapsed" {
	const now: i64 = 1_779_667_200;
	const state = CacheState{
		.binary_mtime = 100,
		.last_check_date = 20260524,
		.fail_count = 5, // backoff = 16s
		.last_fail_ts = now - 5,
	};
	try std.testing.expect(!shouldFetch(state, now, 100));

	const elapsed = CacheState{
		.binary_mtime = 100,
		.last_check_date = 20260524,
		.fail_count = 5,
		.last_fail_ts = now - 20,
	};
	try std.testing.expect(shouldFetch(elapsed, now, 100));
}
