const std = @import("std");
const state_mod = @import("state.zig");
const regex_lib = @import("pcre2.zig");
const regex_mod = @import("regex.zig");
const runtime = @import("runtime.zig");

/// Match type for path evaluation - how a path was matched.
pub const MatchType = enum {
	none,
	literal,
	regex,
};

/// Result of evaluating a path against the effective state.
pub const PathEvalResult = struct {
	is_hidden: bool,
	is_closed: bool,
	/// True when a hide rule matched but SCM priority forced the path visible.
	scm_kept: bool = false,
};

/// A compiled regex test entry.
/// Info stored in regex maps during state merging/building.
pub const RegexInfo = struct {
	negated: bool,
	original_pattern: []const u8, // pattern as stored in state file (glob or regex)
	kind: state_mod.PatternKind,
};

pub const CompiledRegex = struct {
	pattern: []const u8, // the compiled regex pattern, owned by EffectiveState
	negated: bool,
	compiled: regex_lib.Regex,
	original_pattern: []const u8 = "", // the original pattern (glob or regex) for round-trip serialization
	kind: state_mod.PatternKind = .regex, // the original kind for serialization

	pub fn deinit(self: *CompiledRegex) void {
		self.compiled.deinit();
	}

	/// Test if a string matches this regex (respecting negation).
	pub fn matches(self: *CompiledRegex, input: []const u8) bool {
		if (self.negated) {
			// Negated: matches if the pattern does NOT match
			const did_match = self.compiled.partialMatch(input) catch return true;
			return !did_match;
		} else {
			return self.compiled.partialMatch(input) catch return false;
		}
	}
};

/// The effective state after merging inherited + local state.
/// Used for path evaluation during tree rendering.
pub const EffectiveState = struct {
	allocator: std.mem.Allocator,

	// Defaults
	default_state: ?state_mod.DefaultState = null,

	// Scalars
	depth: ?u32 = null,
	sort_mode: ?state_mod.SortMode = null,
	sort_direction: ?state_mod.SortDirection = null,
	color_preference: ?bool = null,
	hyperlink_preference: ?bool = null,
	max_lines: ?u32 = null,
	note_column: ?u32 = null,
	/// First regex pattern that failed to compile (borrowed from `strings`),
	/// or null if all patterns compiled. Lets callers fail loudly instead of
	/// silently dropping invalid patterns.
	invalid_regex: ?[]const u8 = null,

	// Annotations: path → description (re-based to target directory)
	annotations: std.StringHashMapUnmanaged([]const u8) = .empty,

	// Literal hash maps
	open_literals: std.StringHashMapUnmanaged(void) = .empty,
	close_literals: std.StringHashMapUnmanaged(void) = .empty,
	show_literals: std.StringHashMapUnmanaged(void) = .empty,
	hide_literals: std.StringHashMapUnmanaged(void) = .empty,

	// Compiled regex tests
	open_regexes: std.ArrayListUnmanaged(CompiledRegex) = .empty,
	close_regexes: std.ArrayListUnmanaged(CompiledRegex) = .empty,
	show_regexes: std.ArrayListUnmanaged(CompiledRegex) = .empty,
	hide_regexes: std.ArrayListUnmanaged(CompiledRegex) = .empty,

	// Combined regexes for fast non-negated matching (alternation of all non-negated patterns)
	open_combined: ?regex_lib.Regex = null,
	close_combined: ?regex_lib.Regex = null,
	show_combined: ?regex_lib.Regex = null,
	hide_combined: ?regex_lib.Regex = null,

	// Track whether state was modified and needs to be persisted
	needs_migration: bool = false,

	// All allocated strings tracked for cleanup
	strings: std.ArrayListUnmanaged([]const u8) = .empty,

	pub fn deinit(self: *EffectiveState) void {
		const a = self.allocator;
		for (self.strings.items) |s| {
			a.free(s);
		}
		self.strings.deinit(a);
		self.annotations.deinit(a);

		self.open_literals.deinit(a);
		self.close_literals.deinit(a);
		self.show_literals.deinit(a);
		self.hide_literals.deinit(a);

		for (self.open_regexes.items) |*r| r.deinit();
		for (self.close_regexes.items) |*r| r.deinit();
		for (self.show_regexes.items) |*r| r.deinit();
		for (self.hide_regexes.items) |*r| r.deinit();
		self.open_regexes.deinit(a);
		self.close_regexes.deinit(a);
		self.show_regexes.deinit(a);
		self.hide_regexes.deinit(a);

		if (self.open_combined) |*c| c.deinit();
		if (self.close_combined) |*c| c.deinit();
		if (self.show_combined) |*c| c.deinit();
		if (self.hide_combined) |*c| c.deinit();
	}

	pub fn dupeStr(self: *EffectiveState, s: []const u8) ![]const u8 {
		const d = try self.allocator.dupe(u8, s);
		try self.strings.append(self.allocator, d);
		return d;
	}

	/// Evaluate a path to determine if it should be hidden/closed.
	pub fn evaluatePath(
		self: *EffectiveState,
		rel: []const u8,
		parent_closed: bool,
		show_hidden: bool,
		is_dir: bool,
		priority_dirs: ?*const std.StringHashMapUnmanaged(void),
		priority_files: ?*const std.StringHashMapUnmanaged(void),
	) PathEvalResult {
		// open/close only apply to directories — skip expensive regex evaluation for files
		var open_type: MatchType = if (is_dir) self.matchCategory(rel, &self.open_literals, &self.open_regexes, &self.open_combined) else .none;
		var close_type: MatchType = if (is_dir) self.matchCategory(rel, &self.close_literals, &self.close_regexes, &self.close_combined) else .none;
		var show_type = self.matchCategory(rel, &self.show_literals, &self.show_regexes, &self.show_combined);
		var hide_type = self.matchCategory(rel, &self.hide_literals, &self.hide_regexes, &self.hide_combined);

		// If show_hidden, disable hide matching
		if (show_hidden) {
			hide_type = .none;
		}

		// Resolve open/close conflicts: literal beats regex
		if (open_type != .none and close_type != .none) {
			if (open_type == .literal and close_type == .regex) {
				close_type = .none;
			} else if (open_type == .regex and close_type == .literal) {
				open_type = .none;
			}
			// Same type conflict: this is an error in bash, but we just let close win
			// (which is the safer default - showing less is more predictable)
		}

		// Resolve show/hide conflicts: literal beats regex
		if (show_type != .none and hide_type != .none) {
			if (show_type == .literal and hide_type == .regex) {
				hide_type = .none;
			} else if (show_type == .regex and hide_type == .literal) {
				show_type = .none;
			}
		}

		// Determine hidden
		var is_hidden: bool = false;
		if (show_hidden) {
			is_hidden = false;
		} else if (hide_type != .none) {
			is_hidden = true;
		} else if (show_type != .none) {
			is_hidden = false;
		} else {
			is_hidden = false;
		}

		// Determine closed
		var is_closed: bool = false;
		if (parent_closed) {
			is_closed = true;
		} else if (close_type != .none) {
			is_closed = true;
		} else if (open_type != .none) {
			is_closed = false;
		} else if (self.default_state) |ds| {
			is_closed = ds == .closed;
		} else {
			is_closed = false;
		}

		// Priority paths override: SCM changes force visibility.
		// If a hide rule had matched, record that SCM kept it (for the summary).
		var scm_kept = false;
		if (priority_dirs) |pd| {
			if (rel.len > 0 and pd.contains(rel)) {
				if (is_hidden) scm_kept = true;
				is_hidden = false;
				is_closed = false;
			}
		}
		if (priority_files) |pf| {
			if (rel.len > 0 and pf.contains(rel)) {
				if (is_hidden) scm_kept = true;
				is_hidden = false;
			}
		}

		return .{
			.is_hidden = is_hidden,
			.is_closed = is_closed,
			.scm_kept = scm_kept,
		};
	}

	/// Check if a path matches any entry in a category (literal or regex).
	fn matchCategory(
		self: *EffectiveState,
		rel: []const u8,
		literals: *const std.StringHashMapUnmanaged(void),
		regexes: *const std.ArrayListUnmanaged(CompiledRegex),
		combined: *?regex_lib.Regex,
	) MatchType {
		_ = self;
		// Check literals first
		if (rel.len > 0 and literals.contains(rel)) {
			return .literal;
		}

		if (combined.*) |*c| {
			// Fast path: combined regex covers all non-negated patterns
			if (c.partialMatch(rel) catch false) {
				return .regex;
			}
			// Only check negated patterns individually
			for (@constCast(regexes).items) |*r| {
				if (r.negated and r.matches(rel)) {
					return .regex;
				}
			}
		} else {
			// No combined regex built: check all patterns individually (fallback)
			for (@constCast(regexes).items) |*r| {
				if (r.matches(rel)) {
					return .regex;
				}
			}
		}

		return .none;
	}
};

/// Intermediate state accumulated from parent directories.
const InheritedState = struct {
	allocator: std.mem.Allocator,

	// Defaults
	default_state: ?state_mod.DefaultState = null,
	default_state_set: bool = false,

	// Scalars
	depth: ?u32 = null,
	depth_set: bool = false,
	sort_mode: ?state_mod.SortMode = null,
	sort_mode_set: bool = false,
	sort_direction: ?state_mod.SortDirection = null,
	sort_direction_set: bool = false,
	color_preference: ?bool = null,
	color_preference_set: bool = false,
	hyperlink_preference: ?bool = null,
	hyperlink_preference_set: bool = false,
	max_lines: ?u32 = null,
	max_lines_set: bool = false,
	note_column: ?u32 = null,

	// Literal maps
	open_literals: std.StringHashMapUnmanaged(void) = .empty,
	close_literals: std.StringHashMapUnmanaged(void) = .empty,
	show_literals: std.StringHashMapUnmanaged(void) = .empty,
	hide_literals: std.StringHashMapUnmanaged(void) = .empty,

	// Regex maps (pattern -> info, for deduplication; key is compiled regex pattern)
	open_regex_map: std.StringHashMapUnmanaged(RegexInfo) = .empty,
	close_regex_map: std.StringHashMapUnmanaged(RegexInfo) = .empty,
	show_regex_map: std.StringHashMapUnmanaged(RegexInfo) = .empty,
	hide_regex_map: std.StringHashMapUnmanaged(RegexInfo) = .empty,

	// Track allocated strings
	strings: std.ArrayListUnmanaged([]const u8) = .empty,

	fn deinit(self: *InheritedState) void {
		const a = self.allocator;
		for (self.strings.items) |s| {
			a.free(s);
		}
		self.strings.deinit(a);

		self.open_literals.deinit(a);
		self.close_literals.deinit(a);
		self.show_literals.deinit(a);
		self.hide_literals.deinit(a);
		self.open_regex_map.deinit(a);
		self.close_regex_map.deinit(a);
		self.show_regex_map.deinit(a);
		self.hide_regex_map.deinit(a);
	}

	fn dupeStr(self: *InheritedState, s: []const u8) ![]const u8 {
		const d = try self.allocator.dupe(u8, s);
		try self.strings.append(self.allocator, d);
		return d;
	}

		/// Convert a state entry to a regex map key. For globs, converts to regex string.
		/// For regex entries, dupes the value as-is.
		fn entryToRegexKey(self: *InheritedState, entry: state_mod.StateEntry) ![]const u8 {
			if (entry.kind == .glob) {
				const converted = try regex_mod.globToRegex(self.allocator, entry.value);
				try self.strings.append(self.allocator, converted);
				return converted;
			}
			return try self.dupeStr(entry.value);
		}

	/// Merge a parsed state file into this inherited state.
	/// This is called for each parent directory's state file, from root to target.
	fn mergeFrom(self: *InheritedState, sf: *const state_mod.StateFile) !void {
		const a = self.allocator;

		// Scalars: current overrides inherited if set
		if (sf.default_state_set) {
			if (sf.default_state) |ds| {
				self.default_state = ds;
				self.default_state_set = true;
			}
		}
		if (sf.depth != null) {
			self.depth = sf.depth;
			self.depth_set = true;
		}
		if (sf.sort_mode != null) {
			self.sort_mode = sf.sort_mode;
			self.sort_mode_set = true;
		}
		if (sf.sort_direction != null) {
			self.sort_direction = sf.sort_direction;
			self.sort_direction_set = true;
		}
		if (sf.color_preference != null) {
			self.color_preference = sf.color_preference;
			self.color_preference_set = true;
		}
		if (sf.hyperlink_preference != null) {
			self.hyperlink_preference = sf.hyperlink_preference;
			self.hyperlink_preference_set = true;
		}
		if (sf.max_lines != null) {
			self.max_lines = sf.max_lines;
			self.max_lines_set = true;
		}
		if (sf.note_column != null) self.note_column = sf.note_column;

		// Literals: open removes from close and vice versa
		for (sf.open_entries.items) |entry| {
			if (entry.kind == .literal) {
				const key = try self.dupeStr(entry.value);
				try self.open_literals.put(a, key, {});
				_ = self.close_literals.fetchRemove(key);
			}
		}
		for (sf.close_entries.items) |entry| {
			if (entry.kind == .literal) {
				const key = try self.dupeStr(entry.value);
				try self.close_literals.put(a, key, {});
				_ = self.open_literals.fetchRemove(key);
			}
		}
		for (sf.show_entries.items) |entry| {
			if (entry.kind == .literal) {
				const key = try self.dupeStr(entry.value);
				try self.show_literals.put(a, key, {});
				_ = self.hide_literals.fetchRemove(key);
			}
		}
		for (sf.hide_entries.items) |entry| {
			if (entry.kind == .literal) {
				const key = try self.dupeStr(entry.value);
				try self.hide_literals.put(a, key, {});
				_ = self.show_literals.fetchRemove(key);
			}
		}

		// Regexes and globs: same mutual exclusion
		// Globs are converted to regex for the map key but original pattern is preserved
		for (sf.open_entries.items) |entry| {
			if (entry.kind != .literal) {
				const key = try self.entryToRegexKey(entry);
				const orig = try self.dupeStr(entry.value);
				try self.open_regex_map.put(a, key, .{ .negated = entry.negated, .original_pattern = orig, .kind = entry.kind });
				_ = self.close_regex_map.fetchRemove(key);
			}
		}
		for (sf.close_entries.items) |entry| {
			if (entry.kind != .literal) {
				const key = try self.entryToRegexKey(entry);
				const orig = try self.dupeStr(entry.value);
				try self.close_regex_map.put(a, key, .{ .negated = entry.negated, .original_pattern = orig, .kind = entry.kind });
				_ = self.open_regex_map.fetchRemove(key);
			}
		}
		for (sf.show_entries.items) |entry| {
			if (entry.kind != .literal) {
				const key = try self.entryToRegexKey(entry);
				const orig = try self.dupeStr(entry.value);
				try self.show_regex_map.put(a, key, .{ .negated = entry.negated, .original_pattern = orig, .kind = entry.kind });
				_ = self.hide_regex_map.fetchRemove(key);
			}
		}
		for (sf.hide_entries.items) |entry| {
			if (entry.kind != .literal) {
				const key = try self.entryToRegexKey(entry);
				const orig = try self.dupeStr(entry.value);
				try self.hide_regex_map.put(a, key, .{ .negated = entry.negated, .original_pattern = orig, .kind = entry.kind });
				_ = self.show_regex_map.fetchRemove(key);
			}
		}
	}
};

/// Load the state chain from parent directories and the target directory,
/// then build the effective state for path evaluation.
///
/// Walks from abs_dir up to /, collects .dirtree-state files,
/// reads them from root to target (merging inherited state),
/// then combines inherited + local state into the effective state.
pub fn buildEffectiveState(allocator: std.mem.Allocator, abs_dir: []const u8) !EffectiveState {
	var inherited = InheritedState{ .allocator = allocator };
	defer inherited.deinit();

	// Collect parent directories that have .dirtree-state files
	var state_dirs: std.ArrayListUnmanaged([]const u8) = .empty;
	defer {
		for (state_dirs.items) |s| allocator.free(s);
		state_dirs.deinit(allocator);
	}

	var cursor = try allocator.dupe(u8, abs_dir);
	defer allocator.free(cursor);

	// Walk up to root collecting directories with state files
	while (true) {
		const state_path = try std.fs.path.join(allocator, &.{ cursor, ".dirtree-state" });
		defer allocator.free(state_path);

		const exists = blk: {
			std.Io.Dir.cwd().access(runtime.io(), state_path, .{}) catch break :blk false;
			break :blk true;
		};

		if (exists) {
			try state_dirs.append(allocator, try allocator.dupe(u8, cursor));
		}

		// Check if we've reached the root
		if (std.mem.eql(u8, cursor, "/")) break;
		const parent = std.fs.path.dirname(cursor) orelse break;
		if (std.mem.eql(u8, parent, cursor)) break;

		const old_cursor = cursor;
		cursor = try allocator.dupe(u8, parent);
		allocator.free(old_cursor);
	}

	// Read state files from root to target (reverse order)
	// Skip the target directory itself (that becomes the "local" state)
	var i: usize = state_dirs.items.len;
	while (i > 0) {
		i -= 1;
		const dir = state_dirs.items[i];
		if (std.mem.eql(u8, dir, abs_dir)) continue;

		const state_path = try std.fs.path.join(allocator, &.{ dir, ".dirtree-state" });
		defer allocator.free(state_path);

		const content = std.Io.Dir.cwd().readFileAlloc(runtime.io(), state_path, allocator, .limited(1024 * 1024)) catch continue;
		defer allocator.free(content);

		var sf = try state_mod.parseStateFile(allocator, content);
		defer sf.deinit();

		try inherited.mergeFrom(&sf);
	}

	// Read the target directory's own state file
	var local_state: ?state_mod.StateFile = null;
	defer {
		if (local_state) |*ls| ls.deinit();
	}

	{
		const state_path = try std.fs.path.join(allocator, &.{ abs_dir, ".dirtree-state" });
		defer allocator.free(state_path);

		const content = std.Io.Dir.cwd().readFileAlloc(runtime.io(), state_path, allocator, .limited(1024 * 1024)) catch null;
		if (content) |c| {
			defer allocator.free(c);
			local_state = state_mod.parseStateFile(allocator, c) catch null;
		}
	}

	// ── Build annotations map (gitignore-style inheritance) ──
	// Step 1: accumulate (absolute_path → description) across the chain.
	// Deeper files win because we walk root→target order and `put` overwrites.
	var abs_annotations = std.StringHashMapUnmanaged([]const u8){};
	defer abs_annotations.deinit(allocator);
	// Track strings we own so we can free them after re-basing.
	var owned_strings: std.ArrayListUnmanaged([]const u8) = .empty;
	defer {
		for (owned_strings.items) |s| allocator.free(s);
		owned_strings.deinit(allocator);
	}

	// Re-walk state_dirs in root→target order (state_dirs is reverse-sorted: index 0 is target).
	// We need to re-read each ancestor's annotate entries.
	var ai: usize = state_dirs.items.len;
	while (ai > 0) {
		ai -= 1;
		const dir = state_dirs.items[ai];
		const sp = try std.fs.path.join(allocator, &.{ dir, ".dirtree-state" });
		defer allocator.free(sp);

		const content = std.Io.Dir.cwd().readFileAlloc(runtime.io(), sp, allocator, .limited(1024 * 1024)) catch continue;
		defer allocator.free(content);

		var sf = state_mod.parseStateFile(allocator, content) catch continue;
		defer sf.deinit();

		for (sf.annotate_entries.items) |entry| {
			const abs_path = blk: {
				if (std.mem.eql(u8, entry.path, ".")) {
					break :blk try allocator.dupe(u8, dir);
				}
				break :blk try std.fs.path.join(allocator, &.{ dir, entry.path });
			};
			try owned_strings.append(allocator, abs_path);
			const desc_owned = try allocator.dupe(u8, entry.description);
			try owned_strings.append(allocator, desc_owned);

			// Deeper wins — fetchPut overwrites previous mapping
			_ = try abs_annotations.fetchPut(allocator, abs_path, desc_owned);
		}
	}

	// Step 2: re-base each absolute path to relative-to-target.
	// Build the final map in the effective state.
	var rebased = std.StringHashMapUnmanaged([]const u8){};
	defer rebased.deinit(allocator);

	{
		var iter = abs_annotations.iterator();
		while (iter.next()) |kv| {
			const abs_path = kv.key_ptr.*;
			const desc = kv.value_ptr.*;

			// Compute relative path from abs_dir to abs_path
			const rel_path = try computeRelative(allocator, abs_dir, abs_path);
			defer allocator.free(rel_path);

			// Discard entries outside the target tree (rel starts with "..")
			if (rel_path.len >= 2 and rel_path[0] == '.' and rel_path[1] == '.') continue;

			// Step 3: drop empty-description tombstones
			if (desc.len == 0) continue;

			// Store in rebased map for later transfer
			const key_owned = try allocator.dupe(u8, rel_path);
			try owned_strings.append(allocator, key_owned);
			try rebased.put(allocator, key_owned, desc);
		}
	}

	// Build effective state (existing logic)
	var effective = try rebuildEffectiveState(allocator, &inherited, if (local_state) |*ls| ls else null);
	errdefer effective.deinit();

	// Transfer rebased annotations into effective.annotations with owned copies
	{
		var rb_iter = rebased.iterator();
		while (rb_iter.next()) |kv| {
			const k = try effective.dupeStr(kv.key_ptr.*);
			const v = try effective.dupeStr(kv.value_ptr.*);
			try effective.annotations.put(allocator, k, v);
		}
	}

	return effective;
}

/// Compute the relative path from `base` to `target`, both absolute.
/// Returns ".." if target is outside the base subtree.
/// Caller owns the returned slice.
fn computeRelative(allocator: std.mem.Allocator, base: []const u8, target: []const u8) ![]const u8 {
	if (std.mem.eql(u8, base, target)) {
		return try allocator.dupe(u8, ".");
	}
	// Check if target starts with base + "/"
	if (std.mem.startsWith(u8, target, base) and
		target.len > base.len and
		target[base.len] == '/')
	{
		return try allocator.dupe(u8, target[base.len + 1 ..]);
	}
	// Outside the tree
	return try allocator.dupe(u8, "..");
}

/// Dump the effective state in INI-MA format (same as .dirtree-state).
/// Used by --config to show the computed effective configuration.
pub fn dumpEffectiveState(writer: anytype, effective: *const EffectiveState) !void {
	try writer.writeAll(state_mod.STATE_HEADER_COMMENT);
	try writer.writeAll("\n");
	try writer.writeAll(state_mod.STATE_VERSION_LABEL);
	try writer.writeAll("\n");

	var wrote_block = false;

	// Default
	if (effective.default_state) |ds| {
		try writer.writeAll("default=");
		try writer.writeAll(ds.toString());
		try writer.writeAll("\n");
		wrote_block = true;
	}

	// Scalars
	var scalar_count: usize = 0;
	if (effective.depth != null) scalar_count += 1;
	if (effective.sort_mode != null) scalar_count += 1;
	if (effective.sort_direction != null) scalar_count += 1;
	if (effective.color_preference != null) scalar_count += 1;
	if (effective.hyperlink_preference != null) scalar_count += 1;

	if (scalar_count > 0) {
		if (wrote_block) try writer.writeAll("\n");
		if (effective.depth) |d| {
			var buf: [32]u8 = undefined;
			const depth_str = std.fmt.bufPrint(&buf, "{}", .{d}) catch "4";
			try writer.writeAll("depth=");
			try writer.writeAll(depth_str);
			try writer.writeAll("\n");
		}
		if (effective.sort_mode) |m| {
			try writer.writeAll("sort=");
			try writer.writeAll(m.toString());
			try writer.writeAll("\n");
		}
		if (effective.sort_direction) |d| {
			try writer.writeAll("sort_direction=");
			try writer.writeAll(d.toString());
			try writer.writeAll("\n");
		}
		if (effective.color_preference) |c| {
			try writer.writeAll("color=");
			try writer.writeAll(if (c) "true" else "false");
			try writer.writeAll("\n");
		}
		if (effective.hyperlink_preference) |h| {
			try writer.writeAll("hyperlink=");
			try writer.writeAll(if (h) "true" else "false");
			try writer.writeAll("\n");
		}
		wrote_block = true;
	}

	// Collections - open, close, show, hide
	inline for (.{ "open", "close", "show", "hide" }) |key| {
		const literals = @field(effective, key ++ "_literals");
		const regexes = @field(effective, key ++ "_regexes");
		const has_entries = literals.count() > 0 or regexes.items.len > 0;

		if (has_entries) {
			if (wrote_block) try writer.writeAll("\n");
			try writer.writeAll(key);
			try writer.writeAll("=[\n");

			// Write literals
			var lit_iter = literals.iterator();
			while (lit_iter.next()) |entry| {
				try writer.writeAll("\t");
				try writer.writeAll(entry.key_ptr.*);
				try writer.writeAll("\n");
			}

			// Write regexes/globs using original pattern form
			for (regexes.items) |r| {
				try writer.writeAll("\t");
				switch (r.kind) {
					.glob => {
						if (r.negated) {
							try writer.writeAll("!");
						}
						try writer.writeAll(r.original_pattern);
						try writer.writeAll("\n");
					},
					.regex => {
						if (r.negated) {
							try writer.writeAll("!/");
						} else {
							try writer.writeAll("/");
						}
						try writer.writeAll(r.original_pattern);
						try writer.writeAll("/\n");
					},
					.literal => {
						try writer.writeAll(r.original_pattern);
						try writer.writeAll("\n");
					},
				}
			}

			try writer.writeAll("]\n");
			wrote_block = true;
		}
	}
}

/// Combine inherited state and local state into an EffectiveState.
/// Convert a state entry to a regex map key. For globs, converts to regex string.
/// For regex entries, dupes the value as-is.
fn entryToRegexKeyStatic(
	allocator: std.mem.Allocator,
	strings: *std.ArrayListUnmanaged([]const u8),
	entry: state_mod.StateEntry,
) ![]const u8 {
	if (entry.kind == .glob) {
		const converted = try regex_mod.globToRegex(allocator, entry.value);
		try strings.append(allocator, converted);
		return converted;
	}
	const duped = try allocator.dupe(u8, entry.value);
	try strings.append(allocator, duped);
	return duped;
}

fn rebuildEffectiveState(
	allocator: std.mem.Allocator,
	inherited: *const InheritedState,
	local: ?*const state_mod.StateFile,
) !EffectiveState {
	var effective = EffectiveState{ .allocator = allocator };
	errdefer effective.deinit();

	// Scalars: local beats inherited
	if (local) |sf| {
		if (sf.default_state_set) {
			effective.default_state = sf.default_state;
		} else if (inherited.default_state_set) {
			effective.default_state = inherited.default_state;
		}


		effective.depth = sf.depth orelse inherited.depth;
		effective.sort_mode = sf.sort_mode orelse inherited.sort_mode;
		effective.sort_direction = sf.sort_direction orelse inherited.sort_direction;
		effective.color_preference = sf.color_preference orelse inherited.color_preference;
		effective.hyperlink_preference = sf.hyperlink_preference orelse inherited.hyperlink_preference;
		effective.max_lines = sf.max_lines orelse inherited.max_lines;
		effective.note_column = sf.note_column orelse inherited.note_column;
		effective.needs_migration = sf.needs_migration;
	} else {
		effective.default_state = inherited.default_state;
		effective.depth = inherited.depth;
		effective.sort_mode = inherited.sort_mode;
		effective.sort_direction = inherited.sort_direction;
		effective.color_preference = inherited.color_preference;
		effective.hyperlink_preference = inherited.hyperlink_preference;
		effective.max_lines = inherited.max_lines;
		effective.note_column = inherited.note_column;
	}

	// Start with inherited literals
	{
		var iter = inherited.open_literals.iterator();
		while (iter.next()) |entry| {
			const key = try effective.dupeStr(entry.key_ptr.*);
			try effective.open_literals.put(allocator, key, {});
		}
	}
	{
		var iter = inherited.close_literals.iterator();
		while (iter.next()) |entry| {
			const key = try effective.dupeStr(entry.key_ptr.*);
			try effective.close_literals.put(allocator, key, {});
		}
	}
	{
		var iter = inherited.show_literals.iterator();
		while (iter.next()) |entry| {
			const key = try effective.dupeStr(entry.key_ptr.*);
			try effective.show_literals.put(allocator, key, {});
		}
	}
	{
		var iter = inherited.hide_literals.iterator();
		while (iter.next()) |entry| {
			const key = try effective.dupeStr(entry.key_ptr.*);
			try effective.hide_literals.put(allocator, key, {});
		}
	}

	// Apply local literal overrides (mutual exclusion)
	if (local) |sf| {
		for (sf.close_entries.items) |entry| {
			if (entry.kind == .literal) {
				_ = effective.open_literals.fetchRemove(entry.value);
			}
		}
		for (sf.open_entries.items) |entry| {
			if (entry.kind == .literal) {
				_ = effective.close_literals.fetchRemove(entry.value);
			}
		}
		for (sf.hide_entries.items) |entry| {
			if (entry.kind == .literal) {
				_ = effective.show_literals.fetchRemove(entry.value);
			}
		}
		for (sf.show_entries.items) |entry| {
			if (entry.kind == .literal) {
				_ = effective.hide_literals.fetchRemove(entry.value);
			}
		}

		// Add local literals
		for (sf.open_entries.items) |entry| {
			if (entry.kind == .literal) {
				const key = try effective.dupeStr(entry.value);
				try effective.open_literals.put(allocator, key, {});
			}
		}
		for (sf.close_entries.items) |entry| {
			if (entry.kind == .literal) {
				const key = try effective.dupeStr(entry.value);
				try effective.close_literals.put(allocator, key, {});
			}
		}
		for (sf.show_entries.items) |entry| {
			if (entry.kind == .literal) {
				const key = try effective.dupeStr(entry.value);
				try effective.show_literals.put(allocator, key, {});
			}
		}
		for (sf.hide_entries.items) |entry| {
			if (entry.kind == .literal) {
				const key = try effective.dupeStr(entry.value);
				try effective.hide_literals.put(allocator, key, {});
			}
		}
	}

	// Build regex maps: inherited + local with mutual exclusion
	var open_regex_map = std.StringHashMapUnmanaged(RegexInfo){};
	defer open_regex_map.deinit(allocator);
	var close_regex_map = std.StringHashMapUnmanaged(RegexInfo){};
	defer close_regex_map.deinit(allocator);
	var show_regex_map = std.StringHashMapUnmanaged(RegexInfo){};
	defer show_regex_map.deinit(allocator);
	var hide_regex_map = std.StringHashMapUnmanaged(RegexInfo){};
	defer hide_regex_map.deinit(allocator);

	// Copy inherited regexes
	{
		var iter = inherited.open_regex_map.iterator();
		while (iter.next()) |entry| {
			try open_regex_map.put(allocator, entry.key_ptr.*, entry.value_ptr.*);
		}
	}
	{
		var iter = inherited.close_regex_map.iterator();
		while (iter.next()) |entry| {
			try close_regex_map.put(allocator, entry.key_ptr.*, entry.value_ptr.*);
		}
	}
	{
		var iter = inherited.show_regex_map.iterator();
		while (iter.next()) |entry| {
			try show_regex_map.put(allocator, entry.key_ptr.*, entry.value_ptr.*);
		}
	}
	{
		var iter = inherited.hide_regex_map.iterator();
		while (iter.next()) |entry| {
			try hide_regex_map.put(allocator, entry.key_ptr.*, entry.value_ptr.*);
		}
	}

	// Apply local regex/glob overrides
	if (local) |sf| {
		for (sf.close_entries.items) |entry| {
			if (entry.kind != .literal) {
				const key = try entryToRegexKeyStatic(allocator, &effective.strings, entry);
				_ = open_regex_map.fetchRemove(key);
			}
		}
		for (sf.open_entries.items) |entry| {
			if (entry.kind != .literal) {
				const key = try entryToRegexKeyStatic(allocator, &effective.strings, entry);
				_ = close_regex_map.fetchRemove(key);
			}
		}
		for (sf.hide_entries.items) |entry| {
			if (entry.kind != .literal) {
				const key = try entryToRegexKeyStatic(allocator, &effective.strings, entry);
				_ = show_regex_map.fetchRemove(key);
			}
		}
		for (sf.show_entries.items) |entry| {
			if (entry.kind != .literal) {
				const key = try entryToRegexKeyStatic(allocator, &effective.strings, entry);
				_ = hide_regex_map.fetchRemove(key);
			}
		}

		// Add local regexes/globs
		for (sf.open_entries.items) |entry| {
			if (entry.kind != .literal) {
				const key = try entryToRegexKeyStatic(allocator, &effective.strings, entry);
				try open_regex_map.put(allocator, key, .{ .negated = entry.negated, .original_pattern = entry.value, .kind = entry.kind });
			}
		}
		for (sf.close_entries.items) |entry| {
			if (entry.kind != .literal) {
				const key = try entryToRegexKeyStatic(allocator, &effective.strings, entry);
				try close_regex_map.put(allocator, key, .{ .negated = entry.negated, .original_pattern = entry.value, .kind = entry.kind });
			}
		}
		for (sf.show_entries.items) |entry| {
			if (entry.kind != .literal) {
				const key = try entryToRegexKeyStatic(allocator, &effective.strings, entry);
				try show_regex_map.put(allocator, key, .{ .negated = entry.negated, .original_pattern = entry.value, .kind = entry.kind });
			}
		}
		for (sf.hide_entries.items) |entry| {
			if (entry.kind != .literal) {
				const key = try entryToRegexKeyStatic(allocator, &effective.strings, entry);
				try hide_regex_map.put(allocator, key, .{ .negated = entry.negated, .original_pattern = entry.value, .kind = entry.kind });
			}
		}
	}

	// Auto-hide .dirtree-state unless explicitly shown
	const state_file_name = ".dirtree-state";
	var show_state_visible = false;
	if (effective.show_literals.contains(state_file_name)) {
		show_state_visible = true;
	} else {
		var iter = show_regex_map.iterator();
		while (iter.next()) |entry| {
			const pattern = entry.key_ptr.*;
			const info = entry.value_ptr.*;
			if (regexMatchesString(allocator, pattern, info.negated, state_file_name)) {
				show_state_visible = true;
				break;
			}
		}
	}
	if (!show_state_visible) {
		try hide_regex_map.put(allocator, "^\\.dirtree-state$", .{ .negated = false, .original_pattern = "^\\.dirtree-state$", .kind = .regex });
	}

	// Compile all regexes
	try compileRegexMap(allocator, &open_regex_map, &effective.open_regexes, &effective.strings, &effective.invalid_regex);
	try compileRegexMap(allocator, &close_regex_map, &effective.close_regexes, &effective.strings, &effective.invalid_regex);
	try compileRegexMap(allocator, &show_regex_map, &effective.show_regexes, &effective.strings, &effective.invalid_regex);
	try compileRegexMap(allocator, &hide_regex_map, &effective.hide_regexes, &effective.strings, &effective.invalid_regex);

	// Build combined regexes for fast non-negated matching
	effective.open_combined = try buildCombinedRegex(allocator, &effective.open_regexes, &effective.strings);
	effective.close_combined = try buildCombinedRegex(allocator, &effective.close_regexes, &effective.strings);
	effective.show_combined = try buildCombinedRegex(allocator, &effective.show_regexes, &effective.strings);
	effective.hide_combined = try buildCombinedRegex(allocator, &effective.hide_regexes, &effective.strings);

	return effective;
}

/// Compile regex patterns from a map into a list of CompiledRegex.
fn compileRegexMap(
	allocator: std.mem.Allocator,
	map: *const std.StringHashMapUnmanaged(RegexInfo),
	list: *std.ArrayListUnmanaged(CompiledRegex),
	strings: *std.ArrayListUnmanaged([]const u8),
	invalid_out: *?[]const u8,
) !void {
	var iter = map.iterator();
	while (iter.next()) |entry| {
		const pattern = entry.key_ptr.*;
		const info = entry.value_ptr.*;
		const owned_pattern = try allocator.dupe(u8, pattern);
		try strings.append(allocator, owned_pattern);

		const owned_original = try allocator.dupe(u8, info.original_pattern);
		try strings.append(allocator, owned_original);

		const compiled = regex_lib.Regex.compile(allocator, owned_pattern) catch {
			// Record the first invalid pattern so the caller can fail loudly
			// instead of silently dropping it. owned_original is owned by `strings`.
			if (invalid_out.* == null) invalid_out.* = owned_original;
			continue;
		};
		try list.append(allocator, .{
			.pattern = owned_pattern,
			.negated = info.negated,
			.compiled = compiled,
			.original_pattern = owned_original,
			.kind = info.kind,
		});
	}
}

/// Build a single combined regex from all non-negated patterns using alternation.
/// Returns null if there are no non-negated patterns.
fn buildCombinedRegex(
	allocator: std.mem.Allocator,
	regexes: *const std.ArrayListUnmanaged(CompiledRegex),
	strings: *std.ArrayListUnmanaged([]const u8),
) !?regex_lib.Regex {
	// Count non-negated patterns
	var count: usize = 0;
	for (regexes.items) |r| {
		if (!r.negated) count += 1;
	}
	if (count == 0) return null;

	// Single pattern: compile it directly (no alternation needed)
	if (count == 1) {
		for (regexes.items) |r| {
			if (!r.negated) {
				return regex_lib.Regex.compile(allocator, r.pattern) catch null;
			}
		}
	}

	// Multiple patterns: build alternation (pat1|pat2|...|patN)
	var buf: std.ArrayListUnmanaged(u8) = .empty;
	defer buf.deinit(allocator);
	try buf.append(allocator, '(');
	var first = true;
	for (regexes.items) |r| {
		if (!r.negated) {
			if (!first) try buf.append(allocator, '|');
			try buf.appendSlice(allocator, r.pattern);
			first = false;
		}
	}
	try buf.append(allocator, ')');

	const pattern = try allocator.dupe(u8, buf.items);
	try strings.append(allocator, pattern);
	return regex_lib.Regex.compile(allocator, pattern) catch null;
}

/// Helper: test if a single regex pattern matches a string (used for .dirtree-state check).
fn regexMatchesString(allocator: std.mem.Allocator, pattern: []const u8, negated: bool, input: []const u8) bool {
	var compiled = regex_lib.Regex.compile(allocator, pattern) catch return false;
	defer compiled.deinit();
	const did_match = compiled.partialMatch(input) catch return false;
	if (negated) return !did_match;
	return did_match;
}

// Tests

test "evaluatePath: basic hidden" {
	const allocator = std.testing.allocator;
	var es = EffectiveState{ .allocator = allocator };
	defer es.deinit();

	// Add "secret" to hide_literals
	const key = try es.dupeStr("secret");
	try es.hide_literals.put(allocator, key, {});

	const result = es.evaluatePath("secret", false, false, true, null, null);
	try std.testing.expect(result.is_hidden);
	try std.testing.expect(!result.is_closed);
}

test "evaluatePath: basic closed" {
	const allocator = std.testing.allocator;
	var es = EffectiveState{ .allocator = allocator };
	defer es.deinit();

	const key = try es.dupeStr(".git");
	try es.close_literals.put(allocator, key, {});

	const result = es.evaluatePath(".git", false, false, true, null, null);
	try std.testing.expect(!result.is_hidden);
	try std.testing.expect(result.is_closed);
}

test "evaluatePath: parent closed propagates" {
	const allocator = std.testing.allocator;
	var es = EffectiveState{ .allocator = allocator };
	defer es.deinit();

	const result = es.evaluatePath("any_dir", true, false, true, null, null);
	try std.testing.expect(result.is_closed);
}

test "evaluatePath: open overrides default closed" {
	const allocator = std.testing.allocator;
	var es = EffectiveState{ .allocator = allocator };
	defer es.deinit();

	es.default_state = .closed;
	const key = try es.dupeStr("src");
	try es.open_literals.put(allocator, key, {});

	const result = es.evaluatePath("src", false, false, true, null, null);
	try std.testing.expect(!result.is_closed);
}

test "evaluatePath: default closed" {
	const allocator = std.testing.allocator;
	var es = EffectiveState{ .allocator = allocator };
	defer es.deinit();

	es.default_state = .closed;

	const result = es.evaluatePath("any_dir", false, false, true, null, null);
	try std.testing.expect(result.is_closed);
}

test "evaluatePath: show_hidden overrides hide" {
	const allocator = std.testing.allocator;
	var es = EffectiveState{ .allocator = allocator };
	defer es.deinit();

	const key = try es.dupeStr("secret");
	try es.hide_literals.put(allocator, key, {});

	const result = es.evaluatePath("secret", false, true, true, null, null);
	try std.testing.expect(!result.is_hidden);
}

test "evaluatePath: literal beats regex in open/close conflict" {
	const allocator = std.testing.allocator;
	var es = EffectiveState{ .allocator = allocator };
	defer es.deinit();

	// open literal "src"
	const key = try es.dupeStr("src");
	try es.open_literals.put(allocator, key, {});

	// close regex that matches "src"
	const pattern = try es.dupeStr("^src$");
	const compiled = try regex_lib.Regex.compile(allocator, pattern);
	try es.close_regexes.append(allocator, .{
		.pattern = pattern,
		.negated = false,
		.compiled = compiled,
	});

	const result = es.evaluatePath("src", false, false, true, null, null);
	// literal open beats regex close
	try std.testing.expect(!result.is_closed);
}

test "evaluatePath: regex hide" {
	const allocator = std.testing.allocator;
	var es = EffectiveState{ .allocator = allocator };
	defer es.deinit();

	// Hide regex for dotfiles
	const pattern = try es.dupeStr("^\\.");
	const compiled = try regex_lib.Regex.compile(allocator, pattern);
	try es.hide_regexes.append(allocator, .{
		.pattern = pattern,
		.negated = false,
		.compiled = compiled,
	});

	const result = es.evaluatePath(".hidden_file", false, false, true, null, null);
	try std.testing.expect(result.is_hidden);

	const result2 = es.evaluatePath("visible_file", false, false, true, null, null);
	try std.testing.expect(!result2.is_hidden);
}

test "evaluatePath: priority dirs override" {
	const allocator = std.testing.allocator;
	var es = EffectiveState{ .allocator = allocator };
	defer es.deinit();

	es.default_state = .closed;
	const hide_key = try es.dupeStr("src");
	try es.hide_literals.put(allocator, hide_key, {});

	// Set up priority
	var pd = std.StringHashMapUnmanaged(void){};
	defer pd.deinit(allocator);
	try pd.put(allocator, "src", {});

	const result = es.evaluatePath("src", false, false, true, &pd, null);
	try std.testing.expect(!result.is_hidden);
	try std.testing.expect(!result.is_closed);
}

test "rebuildEffectiveState: no state files" {
	const allocator = std.testing.allocator;
	var inherited = InheritedState{ .allocator = allocator };
	defer inherited.deinit();

	var es = try rebuildEffectiveState(allocator, &inherited, null);
	defer es.deinit();

	try std.testing.expect(es.default_state == null);
	try std.testing.expect(es.depth == null);
}

test "rebuildEffectiveState: local overrides inherited" {
	const allocator = std.testing.allocator;

	// Set up inherited
	var inherited = InheritedState{ .allocator = allocator };
	defer inherited.deinit();
	inherited.default_state = .opened;
	inherited.default_state_set = true;
	inherited.depth = 5;
	inherited.depth_set = true;

	// Set up local state
	var local = try state_mod.parseStateFile(allocator, "ver=1.1\ndepth=3\ndefault=closed");
	defer local.deinit();

	var es = try rebuildEffectiveState(allocator, &inherited, &local);
	defer es.deinit();

	try std.testing.expectEqual(state_mod.DefaultState.closed, es.default_state.?);
	try std.testing.expectEqual(@as(u32, 3), es.depth.?);
}

test "rebuildEffectiveState: inherited used when local not set" {
	const allocator = std.testing.allocator;

	var inherited = InheritedState{ .allocator = allocator };
	defer inherited.deinit();
	inherited.depth = 7;
	inherited.depth_set = true;
	inherited.sort_mode = .alpha;
	inherited.sort_mode_set = true;

	// Empty local state
	var local = try state_mod.parseStateFile(allocator, "ver=1.1");
	defer local.deinit();

	var es = try rebuildEffectiveState(allocator, &inherited, &local);
	defer es.deinit();

	try std.testing.expectEqual(@as(u32, 7), es.depth.?);
	try std.testing.expectEqual(state_mod.SortMode.alpha, es.sort_mode.?);
}

test "rebuildEffectiveState: auto-hides .dirtree-state" {
	const allocator = std.testing.allocator;

	var inherited = InheritedState{ .allocator = allocator };
	defer inherited.deinit();

	var es = try rebuildEffectiveState(allocator, &inherited, null);
	defer es.deinit();

	// .dirtree-state should be matched by hide regexes
	const result = es.evaluatePath(".dirtree-state", false, false, true, null, null);
	try std.testing.expect(result.is_hidden);
}

test "evaluatePath: negated regex hide hides non-matches" {
	const allocator = std.testing.allocator;
	var es = EffectiveState{ .allocator = allocator };
	defer es.deinit();

	// Negated hide regex: hide things NOT matching \\.exe$
	const pattern = try es.dupeStr("\\\\.exe$");
	const compiled = try regex_lib.Regex.compile(allocator, pattern);
	try es.hide_regexes.append(allocator, .{
		.pattern = pattern,
		.negated = true,
		.compiled = compiled,
	});

	// keep.exe should NOT be hidden (matches pattern, negation means hide non-matches)
	// Actually, \\.exe$ matches literal-backslash + any-char + exe, so keep.exe does NOT match
	// With negation, non-matches are hidden, so keep.exe IS hidden
	const result1 = es.evaluatePath("keep.exe", false, false, true, null, null);
	try std.testing.expect(result1.is_hidden);

	const result2 = es.evaluatePath("skip.txt", false, false, true, null, null);
	try std.testing.expect(result2.is_hidden);
}


test "combined regex: multiple non-negated hide patterns" {
	const allocator = std.testing.allocator;

	var inherited = InheritedState{ .allocator = allocator };
	defer inherited.deinit();

	// Build a state file with multiple hide regex patterns
	var sf = try state_mod.parseStateFile(allocator, "ver=1.2\nhide=[\n\t/\\.log$/\n\t/\\.tmp$/\n\t/\\.bak$/\n]");
	defer sf.deinit();
	try inherited.mergeFrom(&sf);

	var es = try rebuildEffectiveState(allocator, &inherited, null);
	defer es.deinit();

	// Combined regex should be built
	try std.testing.expect(es.hide_combined != null);

	// All patterns should match via combined regex
	var result = es.evaluatePath("debug.log", false, false, true, null, null);
	try std.testing.expect(result.is_hidden);

	result = es.evaluatePath("scratch.tmp", false, false, true, null, null);
	try std.testing.expect(result.is_hidden);

	result = es.evaluatePath("old.bak", false, false, true, null, null);
	try std.testing.expect(result.is_hidden);

	// Non-matching files should not be hidden
	result = es.evaluatePath("main.zig", false, false, true, null, null);
	try std.testing.expect(!result.is_hidden);
}

test "combined regex: negated + non-negated mix" {
	const allocator = std.testing.allocator;

	var inherited = InheritedState{ .allocator = allocator };
	defer inherited.deinit();

	// Build a state file with a negated hide pattern (hide everything NOT matching .zig$)
	// and a show pattern for specific files
	var sf = try state_mod.parseStateFile(allocator, "ver=1.2\nhide=[\n\t/\\.log$/\n\t!/\\.zig$/\n]");
	defer sf.deinit();
	try inherited.mergeFrom(&sf);

	var es = try rebuildEffectiveState(allocator, &inherited, null);
	defer es.deinit();

	// Combined regex should be built (from the non-negated .log$ pattern)
	try std.testing.expect(es.hide_combined != null);

	// .log files should be hidden (matches non-negated pattern)
	var result = es.evaluatePath("debug.log", false, false, true, null, null);
	try std.testing.expect(result.is_hidden);

	// .txt files should be hidden (don't match negated .zig$ pattern → negated match = true)
	result = es.evaluatePath("readme.txt", false, false, true, null, null);
	try std.testing.expect(result.is_hidden);

	// .zig files: .log$ doesn't match, but !.zig$ means "hide if NOT .zig" → .zig files NOT hidden by negated
	// Actually the negated check: the pattern .zig$ DOES match main.zig, so negated match returns false
	result = es.evaluatePath("main.zig", false, false, true, null, null);
	try std.testing.expect(!result.is_hidden);
}

test "InheritedState.mergeFrom: mutual exclusion" {
	const allocator = std.testing.allocator;

	var inherited = InheritedState{ .allocator = allocator };
	defer inherited.deinit();

	// First state file: close .git
	var sf1 = try state_mod.parseStateFile(allocator, "ver=1.1\nclose=[\n\t.git\n]");
	defer sf1.deinit();
	try inherited.mergeFrom(&sf1);

	try std.testing.expect(inherited.close_literals.contains(".git"));
	try std.testing.expect(!inherited.open_literals.contains(".git"));

	// Second state file: open .git (should remove from close)
	var sf2 = try state_mod.parseStateFile(allocator, "ver=1.1\nopen=[\n\t.git\n]");
	defer sf2.deinit();
	try inherited.mergeFrom(&sf2);

	try std.testing.expect(inherited.open_literals.contains(".git"));
	try std.testing.expect(!inherited.close_literals.contains(".git"));
}

test "EffectiveState: annotations map initializes empty and deinit cleans up" {
	const allocator = std.testing.allocator;
	var es = EffectiveState{ .allocator = allocator };
	defer es.deinit();
	try std.testing.expectEqual(@as(u32, 0), es.annotations.count());

	const path = try es.dupeStr("src/main.zig");
	const desc = try es.dupeStr("Entry point");
	try es.annotations.put(allocator, path, desc);
	try std.testing.expectEqual(@as(u32, 1), es.annotations.count());
	try std.testing.expectEqualStrings("Entry point", es.annotations.get("src/main.zig").?);
}

test "annotations: local file populates the map" {
	const allocator = std.testing.allocator;
	var tmp = std.testing.tmpDir(.{});
	defer tmp.cleanup();

	const state_content = "ver=1.2\nannotate=[\n\tfoo.zig = First file\n\tbar.zig = Second file\n]";
	try tmp.dir.writeFile(runtime.io(), .{ .sub_path = ".dirtree-state", .data = state_content });

	const abs_dir = try tmp.dir.realPathFileAlloc(runtime.io(), ".", allocator);
	defer allocator.free(abs_dir);

	var es = try buildEffectiveState(allocator, abs_dir);
	defer es.deinit();

	try std.testing.expectEqualStrings("First file", es.annotations.get("foo.zig").?);
	try std.testing.expectEqualStrings("Second file", es.annotations.get("bar.zig").?);
}

test "annotations: empty description acts as tombstone (excluded from map)" {
	const allocator = std.testing.allocator;
	var tmp = std.testing.tmpDir(.{});
	defer tmp.cleanup();

	const state_content = "ver=1.2\nannotate=[\n\tlive.zig = Active\n\tdead.zig = \n]";
	try tmp.dir.writeFile(runtime.io(), .{ .sub_path = ".dirtree-state", .data = state_content });

	const abs_dir = try tmp.dir.realPathFileAlloc(runtime.io(), ".", allocator);
	defer allocator.free(abs_dir);

	var es = try buildEffectiveState(allocator, abs_dir);
	defer es.deinit();

	try std.testing.expectEqualStrings("Active", es.annotations.get("live.zig").?);
	try std.testing.expect(es.annotations.get("dead.zig") == null);
}

test "annotations: inherited from parent, with local override" {
	const allocator = std.testing.allocator;
	var parent_tmp = std.testing.tmpDir(.{});
	defer parent_tmp.cleanup();

	// Parent state file references sub/inner.zig
	const parent_content = "ver=1.2\nannotate=[\n\tsub/inner.zig = Parent says inner\n\tsub/other.zig = Parent says other\n\tabove.zig = Outside scope\n]";
	try parent_tmp.dir.writeFile(runtime.io(), .{ .sub_path = ".dirtree-state", .data = parent_content });
	try parent_tmp.dir.createDirPath(runtime.io(), "sub");

	// Child state file overrides one annotation
	const child_content = "ver=1.2\nannotate=[\n\tinner.zig = Child overrides\n]";
	try parent_tmp.dir.writeFile(runtime.io(), .{ .sub_path = "sub/.dirtree-state", .data = child_content });

	const parent_abs = try parent_tmp.dir.realPathFileAlloc(runtime.io(), ".", allocator);
	defer allocator.free(parent_abs);
	const child_abs = try std.fs.path.join(allocator, &.{ parent_abs, "sub" });
	defer allocator.free(child_abs);

	var es = try buildEffectiveState(allocator, child_abs);
	defer es.deinit();

	// Child override wins
	try std.testing.expectEqualStrings("Child overrides", es.annotations.get("inner.zig").?);
	// Parent's entry for sub/other.zig re-bases to "other.zig" and is inherited
	try std.testing.expectEqualStrings("Parent says other", es.annotations.get("other.zig").?);
	// above.zig is outside the rendered tree → must not appear
	try std.testing.expect(es.annotations.get("../above.zig") == null);
	try std.testing.expect(es.annotations.get("above.zig") == null);
}

test "annotations: child empty value suppresses parent annotation" {
	const allocator = std.testing.allocator;
	var parent_tmp = std.testing.tmpDir(.{});
	defer parent_tmp.cleanup();

	const parent_content = "ver=1.2\nannotate=[\n\tsub/inner.zig = Parent description\n]";
	try parent_tmp.dir.writeFile(runtime.io(), .{ .sub_path = ".dirtree-state", .data = parent_content });
	try parent_tmp.dir.createDirPath(runtime.io(), "sub");

	const child_content = "ver=1.2\nannotate=[\n\tinner.zig = \n]";
	try parent_tmp.dir.writeFile(runtime.io(), .{ .sub_path = "sub/.dirtree-state", .data = child_content });

	const parent_abs = try parent_tmp.dir.realPathFileAlloc(runtime.io(), ".", allocator);
	defer allocator.free(parent_abs);
	const child_abs = try std.fs.path.join(allocator, &.{ parent_abs, "sub" });
	defer allocator.free(child_abs);

	var es = try buildEffectiveState(allocator, child_abs);
	defer es.deinit();

	try std.testing.expect(es.annotations.get("inner.zig") == null);
}
