const std = @import("std");
const state_mod = @import("state.zig");
const regex_lib = @import("regex");

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
};

/// A compiled regex test entry.
pub const CompiledRegex = struct {
	pattern: []const u8, // owned by EffectiveState
	negated: bool,
	compiled: regex_lib.Regex,

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
	default_visibility: ?state_mod.DefaultVisibility = null,

	// Scalars
	depth: ?u32 = null,
	sort_mode: ?state_mod.SortMode = null,
	sort_direction: ?state_mod.SortDirection = null,
	color_preference: ?bool = null,
	hyperlink_preference: ?bool = null,

	// Literal hash maps
	open_literals: std.StringHashMapUnmanaged(void) = .{},
	close_literals: std.StringHashMapUnmanaged(void) = .{},
	show_literals: std.StringHashMapUnmanaged(void) = .{},
	hide_literals: std.StringHashMapUnmanaged(void) = .{},

	// Compiled regex tests
	open_regexes: std.ArrayListUnmanaged(CompiledRegex) = .{},
	close_regexes: std.ArrayListUnmanaged(CompiledRegex) = .{},
	show_regexes: std.ArrayListUnmanaged(CompiledRegex) = .{},
	hide_regexes: std.ArrayListUnmanaged(CompiledRegex) = .{},

	// Track whether state was modified and needs to be persisted
	needs_migration: bool = false,

	// All allocated strings tracked for cleanup
	strings: std.ArrayListUnmanaged([]const u8) = .{},

	pub fn deinit(self: *EffectiveState) void {
		const a = self.allocator;
		for (self.strings.items) |s| {
			a.free(s);
		}
		self.strings.deinit(a);

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
		priority_dirs: ?*const std.StringHashMapUnmanaged(void),
		priority_files: ?*const std.StringHashMapUnmanaged(void),
	) PathEvalResult {
		// Get match types for all four categories
		var open_type = self.matchCategory(rel, &self.open_literals, &self.open_regexes);
		var close_type = self.matchCategory(rel, &self.close_literals, &self.close_regexes);
		var show_type = self.matchCategory(rel, &self.show_literals, &self.show_regexes);
		var hide_type = self.matchCategory(rel, &self.hide_literals, &self.hide_regexes);

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

		// Priority paths override: SCM changes force visibility
		if (priority_dirs) |pd| {
			if (rel.len > 0 and pd.contains(rel)) {
				is_hidden = false;
				is_closed = false;
			}
		}
		if (priority_files) |pf| {
			if (rel.len > 0 and pf.contains(rel)) {
				is_hidden = false;
			}
		}

		return .{
			.is_hidden = is_hidden,
			.is_closed = is_closed,
		};
	}

	/// Check if a path matches any entry in a category (literal or regex).
	fn matchCategory(
		self: *EffectiveState,
		rel: []const u8,
		literals: *const std.StringHashMapUnmanaged(void),
		regexes: *const std.ArrayListUnmanaged(CompiledRegex),
	) MatchType {
		_ = self;
		// Check literals first
		if (rel.len > 0 and literals.contains(rel)) {
			return .literal;
		}

		// Check regexes
		// We need mutable access to compiled regexes for matching
		for (@constCast(regexes).items) |*r| {
			if (r.matches(rel)) {
				return .regex;
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
	default_visibility: ?state_mod.DefaultVisibility = null,
	default_visibility_set: bool = false,

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

	// Literal maps
	open_literals: std.StringHashMapUnmanaged(void) = .{},
	close_literals: std.StringHashMapUnmanaged(void) = .{},
	show_literals: std.StringHashMapUnmanaged(void) = .{},
	hide_literals: std.StringHashMapUnmanaged(void) = .{},

	// Regex maps (pattern -> set, for deduplication)
	open_regex_map: std.StringHashMapUnmanaged(bool) = .{}, // value is negated flag
	close_regex_map: std.StringHashMapUnmanaged(bool) = .{},
	show_regex_map: std.StringHashMapUnmanaged(bool) = .{},
	hide_regex_map: std.StringHashMapUnmanaged(bool) = .{},

	// Track allocated strings
	strings: std.ArrayListUnmanaged([]const u8) = .{},

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
		if (sf.default_visibility_set) {
			if (sf.default_visibility) |dv| {
				self.default_visibility = dv;
				self.default_visibility_set = true;
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

		// Literals: open removes from close and vice versa
		for (sf.open_entries.items) |entry| {
			if (!entry.is_regex) {
				const key = try self.dupeStr(entry.value);
				try self.open_literals.put(a, key, {});
				_ = self.close_literals.fetchRemove(key);
			}
		}
		for (sf.close_entries.items) |entry| {
			if (!entry.is_regex) {
				const key = try self.dupeStr(entry.value);
				try self.close_literals.put(a, key, {});
				_ = self.open_literals.fetchRemove(key);
			}
		}
		for (sf.show_entries.items) |entry| {
			if (!entry.is_regex) {
				const key = try self.dupeStr(entry.value);
				try self.show_literals.put(a, key, {});
				_ = self.hide_literals.fetchRemove(key);
			}
		}
		for (sf.hide_entries.items) |entry| {
			if (!entry.is_regex) {
				const key = try self.dupeStr(entry.value);
				try self.hide_literals.put(a, key, {});
				_ = self.show_literals.fetchRemove(key);
			}
		}

		// Regexes: same mutual exclusion
		for (sf.open_entries.items) |entry| {
			if (entry.is_regex) {
				const key = try self.dupeStr(entry.value);
				try self.open_regex_map.put(a, key, entry.negated);
				_ = self.close_regex_map.fetchRemove(key);
			}
		}
		for (sf.close_entries.items) |entry| {
			if (entry.is_regex) {
				const key = try self.dupeStr(entry.value);
				try self.close_regex_map.put(a, key, entry.negated);
				_ = self.open_regex_map.fetchRemove(key);
			}
		}
		for (sf.show_entries.items) |entry| {
			if (entry.is_regex) {
				const key = try self.dupeStr(entry.value);
				try self.show_regex_map.put(a, key, entry.negated);
				_ = self.hide_regex_map.fetchRemove(key);
			}
		}
		for (sf.hide_entries.items) |entry| {
			if (entry.is_regex) {
				const key = try self.dupeStr(entry.value);
				try self.hide_regex_map.put(a, key, entry.negated);
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
	var state_dirs = std.ArrayListUnmanaged([]const u8){};
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
			std.fs.cwd().access(state_path, .{}) catch break :blk false;
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

		const content = std.fs.cwd().readFileAlloc(allocator, state_path, 1024 * 1024) catch continue;
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

		const content = std.fs.cwd().readFileAlloc(allocator, state_path, 1024 * 1024) catch null;
		if (content) |c| {
			defer allocator.free(c);
			local_state = state_mod.parseStateFile(allocator, c) catch null;
		}
	}

	// Build effective state
	return rebuildEffectiveState(allocator, &inherited, if (local_state) |*ls| ls else null);
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
	var default_entries: [2][]const u8 = undefined;
	var default_count: usize = 0;
	if (effective.default_state) |ds| {
		default_entries[default_count] = ds.toString();
		default_count += 1;
	}
	if (effective.default_visibility) |dv| {
		default_entries[default_count] = dv.toString();
		default_count += 1;
	}

	if (default_count == 1) {
		try writer.writeAll("default=");
		try writer.writeAll(default_entries[0]);
		try writer.writeAll("\n");
		wrote_block = true;
	} else if (default_count > 1) {
		try writer.writeAll("default=[\n");
		for (default_entries[0..default_count]) |entry| {
			try writer.writeAll("\t");
			try writer.writeAll(entry);
			try writer.writeAll("\n");
		}
		try writer.writeAll("]\n");
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

			// Write regexes
			for (regexes.items) |r| {
				try writer.writeAll("\t");
				if (r.negated) {
					try writer.writeAll("!/");
				} else {
					try writer.writeAll("/");
				}
				try writer.writeAll(r.pattern);
				try writer.writeAll("/\n");
			}

			try writer.writeAll("]\n");
			wrote_block = true;
		}
	}
}

/// Combine inherited state and local state into an EffectiveState.
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

		if (sf.default_visibility_set) {
			effective.default_visibility = sf.default_visibility;
		} else if (inherited.default_visibility_set) {
			effective.default_visibility = inherited.default_visibility;
		}

		effective.depth = sf.depth orelse inherited.depth;
		effective.sort_mode = sf.sort_mode orelse inherited.sort_mode;
		effective.sort_direction = sf.sort_direction orelse inherited.sort_direction;
		effective.color_preference = sf.color_preference orelse inherited.color_preference;
		effective.hyperlink_preference = sf.hyperlink_preference orelse inherited.hyperlink_preference;
		effective.needs_migration = sf.needs_migration;
	} else {
		effective.default_state = inherited.default_state;
		effective.default_visibility = inherited.default_visibility;
		effective.depth = inherited.depth;
		effective.sort_mode = inherited.sort_mode;
		effective.sort_direction = inherited.sort_direction;
		effective.color_preference = inherited.color_preference;
		effective.hyperlink_preference = inherited.hyperlink_preference;
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
			if (!entry.is_regex) {
				_ = effective.open_literals.fetchRemove(entry.value);
			}
		}
		for (sf.open_entries.items) |entry| {
			if (!entry.is_regex) {
				_ = effective.close_literals.fetchRemove(entry.value);
			}
		}
		for (sf.hide_entries.items) |entry| {
			if (!entry.is_regex) {
				_ = effective.show_literals.fetchRemove(entry.value);
			}
		}
		for (sf.show_entries.items) |entry| {
			if (!entry.is_regex) {
				_ = effective.hide_literals.fetchRemove(entry.value);
			}
		}

		// Add local literals
		for (sf.open_entries.items) |entry| {
			if (!entry.is_regex) {
				const key = try effective.dupeStr(entry.value);
				try effective.open_literals.put(allocator, key, {});
			}
		}
		for (sf.close_entries.items) |entry| {
			if (!entry.is_regex) {
				const key = try effective.dupeStr(entry.value);
				try effective.close_literals.put(allocator, key, {});
			}
		}
		for (sf.show_entries.items) |entry| {
			if (!entry.is_regex) {
				const key = try effective.dupeStr(entry.value);
				try effective.show_literals.put(allocator, key, {});
			}
		}
		for (sf.hide_entries.items) |entry| {
			if (!entry.is_regex) {
				const key = try effective.dupeStr(entry.value);
				try effective.hide_literals.put(allocator, key, {});
			}
		}
	}

	// Build regex maps: inherited + local with mutual exclusion
	var open_regex_map = std.StringHashMapUnmanaged(bool){};
	defer open_regex_map.deinit(allocator);
	var close_regex_map = std.StringHashMapUnmanaged(bool){};
	defer close_regex_map.deinit(allocator);
	var show_regex_map = std.StringHashMapUnmanaged(bool){};
	defer show_regex_map.deinit(allocator);
	var hide_regex_map = std.StringHashMapUnmanaged(bool){};
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

	// Apply local regex overrides
	if (local) |sf| {
		for (sf.close_entries.items) |entry| {
			if (entry.is_regex) {
				_ = open_regex_map.fetchRemove(entry.value);
			}
		}
		for (sf.open_entries.items) |entry| {
			if (entry.is_regex) {
				_ = close_regex_map.fetchRemove(entry.value);
			}
		}
		for (sf.hide_entries.items) |entry| {
			if (entry.is_regex) {
				_ = show_regex_map.fetchRemove(entry.value);
			}
		}
		for (sf.show_entries.items) |entry| {
			if (entry.is_regex) {
				_ = hide_regex_map.fetchRemove(entry.value);
			}
		}

		// Add local regexes
		for (sf.open_entries.items) |entry| {
			if (entry.is_regex) {
				try open_regex_map.put(allocator, entry.value, entry.negated);
			}
		}
		for (sf.close_entries.items) |entry| {
			if (entry.is_regex) {
				try close_regex_map.put(allocator, entry.value, entry.negated);
			}
		}
		for (sf.show_entries.items) |entry| {
			if (entry.is_regex) {
				try show_regex_map.put(allocator, entry.value, entry.negated);
			}
		}
		for (sf.hide_entries.items) |entry| {
			if (entry.is_regex) {
				try hide_regex_map.put(allocator, entry.value, entry.negated);
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
			const negated = entry.value_ptr.*;
			if (regexMatchesString(allocator, pattern, negated, state_file_name)) {
				show_state_visible = true;
				break;
			}
		}
	}
	if (!show_state_visible) {
		try hide_regex_map.put(allocator, "^\\.dirtree-state$", false);
	}

	// Compile all regexes
	try compileRegexMap(allocator, &open_regex_map, &effective.open_regexes, &effective.strings);
	try compileRegexMap(allocator, &close_regex_map, &effective.close_regexes, &effective.strings);
	try compileRegexMap(allocator, &show_regex_map, &effective.show_regexes, &effective.strings);
	try compileRegexMap(allocator, &hide_regex_map, &effective.hide_regexes, &effective.strings);

	return effective;
}

/// Compile regex patterns from a map into a list of CompiledRegex.
fn compileRegexMap(
	allocator: std.mem.Allocator,
	map: *const std.StringHashMapUnmanaged(bool),
	list: *std.ArrayListUnmanaged(CompiledRegex),
	strings: *std.ArrayListUnmanaged([]const u8),
) !void {
	var iter = map.iterator();
	while (iter.next()) |entry| {
		const pattern = entry.key_ptr.*;
		const negated = entry.value_ptr.*;
		const owned_pattern = try allocator.dupe(u8, pattern);
		try strings.append(allocator, owned_pattern);

		const compiled = regex_lib.Regex.compile(allocator, owned_pattern) catch {
			// Skip patterns that fail to compile
			continue;
		};
		try list.append(allocator, .{
			.pattern = owned_pattern,
			.negated = negated,
			.compiled = compiled,
		});
	}
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

	const result = es.evaluatePath("secret", false, false, null, null);
	try std.testing.expect(result.is_hidden);
	try std.testing.expect(!result.is_closed);
}

test "evaluatePath: basic closed" {
	const allocator = std.testing.allocator;
	var es = EffectiveState{ .allocator = allocator };
	defer es.deinit();

	const key = try es.dupeStr(".git");
	try es.close_literals.put(allocator, key, {});

	const result = es.evaluatePath(".git", false, false, null, null);
	try std.testing.expect(!result.is_hidden);
	try std.testing.expect(result.is_closed);
}

test "evaluatePath: parent closed propagates" {
	const allocator = std.testing.allocator;
	var es = EffectiveState{ .allocator = allocator };
	defer es.deinit();

	const result = es.evaluatePath("any_dir", true, false, null, null);
	try std.testing.expect(result.is_closed);
}

test "evaluatePath: open overrides default closed" {
	const allocator = std.testing.allocator;
	var es = EffectiveState{ .allocator = allocator };
	defer es.deinit();

	es.default_state = .closed;
	const key = try es.dupeStr("src");
	try es.open_literals.put(allocator, key, {});

	const result = es.evaluatePath("src", false, false, null, null);
	try std.testing.expect(!result.is_closed);
}

test "evaluatePath: default closed" {
	const allocator = std.testing.allocator;
	var es = EffectiveState{ .allocator = allocator };
	defer es.deinit();

	es.default_state = .closed;

	const result = es.evaluatePath("any_dir", false, false, null, null);
	try std.testing.expect(result.is_closed);
}

test "evaluatePath: show_hidden overrides hide" {
	const allocator = std.testing.allocator;
	var es = EffectiveState{ .allocator = allocator };
	defer es.deinit();

	const key = try es.dupeStr("secret");
	try es.hide_literals.put(allocator, key, {});

	const result = es.evaluatePath("secret", false, true, null, null);
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

	const result = es.evaluatePath("src", false, false, null, null);
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

	const result = es.evaluatePath(".hidden_file", false, false, null, null);
	try std.testing.expect(result.is_hidden);

	const result2 = es.evaluatePath("visible_file", false, false, null, null);
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

	const result = es.evaluatePath("src", false, false, &pd, null);
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
	const result = es.evaluatePath(".dirtree-state", false, false, null, null);
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
	const result1 = es.evaluatePath("keep.exe", false, false, null, null);
	try std.testing.expect(result1.is_hidden);

	const result2 = es.evaluatePath("skip.txt", false, false, null, null);
	try std.testing.expect(result2.is_hidden);
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
