const std = @import("std");
const regex_mod = @import("regex.zig");

pub const STATE_VERSION_LABEL = "ver=1.2";
pub const STATE_HEADER_COMMENT = "# Dirtree: Stateful directory trees in the CLI for humans and LLMs. https://github.com/pmarreck/dirtree";

pub const DefaultState = enum {
	opened,
	closed,

	pub fn toString(self: DefaultState) []const u8 {
		return switch (self) {
			.opened => "opened",
			.closed => "closed",
		};
	}
};

pub const SortMode = enum {
	modified,
	alpha,

	pub fn toString(self: SortMode) []const u8 {
		return switch (self) {
			.modified => "modified",
			.alpha => "alpha",
		};
	}
};

pub const SortDirection = enum {
	asc,
	desc,

	pub fn toString(self: SortDirection) []const u8 {
		return switch (self) {
			.asc => "asc",
			.desc => "desc",
		};
	}
};

/// The kind of pattern stored in a state entry.
pub const PatternKind = enum {
	literal,
	regex,
	glob,
};

/// A state entry that can be a literal path, regex pattern, or glob pattern.
pub const StateEntry = struct {
	value: []const u8,
	kind: PatternKind,
	negated: bool,
	comment: ?[]const u8 = null, // preceding comment block
};

/// Parsed .dirtree-state file contents.
pub const StateFile = struct {
	allocator: std.mem.Allocator,

	version: []const u8 = STATE_VERSION_LABEL,
	needs_migration: bool = false,

	// Defaults
	default_state: ?DefaultState = null,
	default_state_set: bool = false,
	// Scalars
	depth: ?u32 = null,
	sort_mode: ?SortMode = null,
	sort_direction: ?SortDirection = null,
	color_preference: ?bool = null,
	hyperlink_preference: ?bool = null,
	max_lines: ?u32 = null,

	// Collections
	open_entries: std.ArrayListUnmanaged(StateEntry) = .{},
	close_entries: std.ArrayListUnmanaged(StateEntry) = .{},
	show_entries: std.ArrayListUnmanaged(StateEntry) = .{},
	hide_entries: std.ArrayListUnmanaged(StateEntry) = .{},

	// Passthrough (unknown keys/lines preserved as-is)
	passthrough_lines: std.ArrayListUnmanaged([]const u8) = .{},

	// All allocated strings tracked for cleanup
	strings: std.ArrayListUnmanaged([]const u8) = .{},

	pub fn deinit(self: *StateFile) void {
		const a = self.allocator;
		for (self.strings.items) |s| {
			a.free(s);
		}
		self.strings.deinit(a);
		self.open_entries.deinit(a);
		self.close_entries.deinit(a);
		self.show_entries.deinit(a);
		self.hide_entries.deinit(a);
		self.passthrough_lines.deinit(a);
	}

	pub fn dupeStr(self: *StateFile, s: []const u8) ![]const u8 {
		const d = try self.allocator.dupe(u8, s);
		try self.strings.append(self.allocator, d);
		return d;
	}

	pub fn addEntry(self: *StateFile, list: *std.ArrayListUnmanaged(StateEntry), entry: StateEntry) !void {
		try list.append(self.allocator, entry);
	}

	/// Check if an entry with matching kind, value, and negation already exists.
	/// Unifies the former hasLiteral/hasRegex/hasGlob functions.
	/// Note: O(n) scan but acceptable for typical state file sizes (< 50 entries).
	pub fn hasEntry(entries: []const StateEntry, kind: PatternKind, value: []const u8, negated: bool) bool {
		for (entries) |e| {
			if (e.kind == kind and e.negated == negated and std.mem.eql(u8, e.value, value)) return true;
		}
		return false;
	}

	/// Convenience wrapper: check if a literal entry exists (literals are never negated).
	pub fn hasLiteral(entries: []const StateEntry, value: []const u8) bool {
		return hasEntry(entries, .literal, value, false);
	}

	/// Convenience wrapper: check if a regex entry exists.
	pub fn hasRegex(entries: []const StateEntry, value: []const u8, negated: bool) bool {
		return hasEntry(entries, .regex, value, negated);
	}

	/// Convenience wrapper: check if a glob entry exists.
	pub fn hasGlob(entries: []const StateEntry, value: []const u8, negated: bool) bool {
		return hasEntry(entries, .glob, value, negated);
	}
};

/// Parse a .dirtree-state file from raw bytes.
pub fn parseStateFile(allocator: std.mem.Allocator, content: []const u8) !StateFile {
	var state = StateFile{ .allocator = allocator };
	errdefer state.deinit();

	var lines_iter = std.mem.splitScalar(u8, content, '\n');
	var format: enum { undetermined, inima, legacy } = .undetermined;
	var current_array: ?[]const u8 = null;
	var collecting_unknown = false;
	var unknown_buffer: std.ArrayListUnmanaged([]const u8) = .{};
	defer unknown_buffer.deinit(allocator);
	var comment_buffer: std.ArrayListUnmanaged(u8) = .{};
	defer comment_buffer.deinit(allocator);

	while (lines_iter.next()) |raw_line| {
		// Strip CR
		const line = if (raw_line.len > 0 and raw_line[raw_line.len - 1] == '\r')
			raw_line[0 .. raw_line.len - 1]
		else
			raw_line;

		// Inside a multi-line array
		if (current_array) |arr_key| {
			if (collecting_unknown) {
				const duped = try state.dupeStr(raw_line);
				try unknown_buffer.append(allocator, duped);
				if (std.mem.eql(u8, stripWhitespace(line), "]")) {
					for (unknown_buffer.items) |ub| {
						try state.passthrough_lines.append(allocator, ub);
					}
					unknown_buffer.clearRetainingCapacity();
					collecting_unknown = false;
					current_array = null;
				}
				continue;
			}

			if (std.mem.eql(u8, stripWhitespace(line), "]")) {
				current_array = null;
				comment_buffer.clearRetainingCapacity();
				continue;
			}

			// Comment inside array
			if (isComment(line)) {
				if (isKnownArrayKey(arr_key)) {
					try comment_buffer.appendSlice(allocator, raw_line);
					try comment_buffer.append(allocator, '\n');
				}
				continue;
			}

			const entry_str = strip(line);
			if (entry_str.len == 0) continue;

			// Try to parse as regex
			const parsed = regex_mod.parseWrappedRegexToken(entry_str) catch {
				// Empty pattern - skip
				comment_buffer.clearRetainingCapacity();
				continue;
			};

			const comment_str: ?[]const u8 = if (comment_buffer.items.len > 0)
				try state.dupeStr(comment_buffer.items)
			else
				null;
			comment_buffer.clearRetainingCapacity();

			if (parsed) |p| {
				const val = try state.dupeStr(p.pattern);
				const target = getEntryList(&state, arr_key);
				if (!StateFile.hasRegex(target.items, val, p.negated)) {
					try state.addEntry(target, .{
						.value = val,
						.kind = .regex,
						.negated = p.negated,
						.comment = comment_str,
					});
				}
				continue;
			}

			// Handle as default token if in default array
			if (std.mem.eql(u8, arr_key, "default")) {
				processDefaultToken(&state, entry_str);
				continue;
			}

			// Check for negated bare entries (e.g. !*.log)
			var bare_entry = entry_str;
			var bare_negated = false;
			if (bare_entry.len > 1 and bare_entry[0] == '!' and !regex_mod.isGlobPattern(entry_str[0..1])) {
				bare_negated = true;
				bare_entry = bare_entry[1..];
			}

			// Check if it's a glob pattern
			if (regex_mod.isGlobPattern(bare_entry)) {
				const gval = try state.dupeStr(bare_entry);
				const gtarget = getEntryList(&state, arr_key);
				if (!StateFile.hasGlob(gtarget.items, gval, bare_negated)) {
					try state.addEntry(gtarget, .{
						.value = gval,
						.kind = .glob,
						.negated = bare_negated,
						.comment = comment_str,
					});
				}
				continue;
			}

			// Literal entry - strip leading '/' (normalize like bash's normalize_rel)
			const normalized = if (bare_entry.len > 1 and bare_entry[0] == '/')
				bare_entry[1..]
			else
				bare_entry;
			const val = try state.dupeStr(normalized);
			const target = getEntryList(&state, arr_key);
			if (!StateFile.hasLiteral(target.items, val)) {
				try state.addEntry(target, .{
					.value = val,
					.kind = .literal,
					.negated = false,
					.comment = comment_str,
				});
			}
			continue;
		}

		// Determine format
		if (format == .undetermined) {
			const stripped = stripWhitespace(line);
			if (stripped.len == 0) continue;
			if (isComment(line)) {
				if (!isHeaderComment(line)) {
					const duped = try state.dupeStr(raw_line);
					try state.passthrough_lines.append(allocator, duped);
				}
				continue;
			}

			// Check for ver=X.X format
			if (std.mem.startsWith(u8, line, "ver")) {
				if (parseVersion(line)) |ver| {
					const duped = try state.dupeStr(ver);
					state.version = duped;
					format = .inima;
					if (!std.mem.eql(u8, ver, "1.2")) {
						state.needs_migration = true;
					}
					continue;
				}
			}

			format = .legacy;
		}

		// Legacy format parsing
		if (format == .legacy) {
			if (isComment(line)) {
				if (!isHeaderComment(line)) {
					const duped = try state.dupeStr(raw_line);
					try state.passthrough_lines.append(allocator, duped);
				}
				continue;
			}
			try parseLegacyLine(&state, line, raw_line);
			continue;
		}

		// INI-MA format parsing
		if (isComment(line)) {
			if (!isHeaderComment(line)) {
				const duped = try state.dupeStr(raw_line);
				try state.passthrough_lines.append(allocator, duped);
			}
			continue;
		}

		const stripped = stripWhitespace(line);
		if (stripped.len == 0) continue;

		// Parse key=value
		if (parseKeyValue(line)) |kv| {
			const key = kv.key;
			const value = strip(kv.value);
			const compact = stripWhitespace(kv.value);

			if (std.mem.eql(u8, key, "default")) {
				if (std.mem.eql(u8, compact, "[")) {
					current_array = "default";
					collecting_unknown = false;
					comment_buffer.clearRetainingCapacity();
				} else if (isInlineArray(value)) {
					const inner = value[1 .. value.len - 1];
					parseInlineDefault(&state, inner);
					state.needs_migration = true;
				} else {
					parseDefaultScalar(&state, value);
				}
			} else if (std.mem.eql(u8, key, "depth")) {
				if (std.fmt.parseInt(u32, value, 10)) |d| {
					state.depth = d;
				} else |_| {
					const duped = try state.dupeStr(raw_line);
					try state.passthrough_lines.append(allocator, duped);
				}
			} else if (std.mem.eql(u8, key, "sort")) {
				if (std.mem.eql(u8, value, "alpha")) {
					state.sort_mode = .alpha;
				} else if (std.mem.eql(u8, value, "modified")) {
					state.sort_mode = .modified;
				} else {
					const duped = try state.dupeStr(raw_line);
					try state.passthrough_lines.append(allocator, duped);
				}
			} else if (std.mem.eql(u8, key, "sort_direction")) {
				if (std.mem.eql(u8, value, "asc")) {
					state.sort_direction = .asc;
				} else if (std.mem.eql(u8, value, "desc")) {
					state.sort_direction = .desc;
				} else {
					const duped = try state.dupeStr(raw_line);
					try state.passthrough_lines.append(allocator, duped);
				}
			} else if (std.mem.eql(u8, key, "color")) {
				if (std.mem.eql(u8, value, "true")) {
					state.color_preference = true;
				} else if (std.mem.eql(u8, value, "false")) {
					state.color_preference = false;
				} else {
					const duped = try state.dupeStr(raw_line);
					try state.passthrough_lines.append(allocator, duped);
				}
			} else if (std.mem.eql(u8, key, "hyperlink")) {
				if (std.mem.eql(u8, value, "true")) {
					state.hyperlink_preference = true;
				} else if (std.mem.eql(u8, value, "false")) {
					state.hyperlink_preference = false;
				} else {
					const duped = try state.dupeStr(raw_line);
					try state.passthrough_lines.append(allocator, duped);
				}
			} else if (std.mem.eql(u8, key, "max_lines")) {
				if (std.fmt.parseInt(u32, value, 10)) |ml| {
					state.max_lines = ml;
				} else |_| {
					const duped = try state.dupeStr(raw_line);
					try state.passthrough_lines.append(allocator, duped);
				}
			} else if (isKnownArrayKey(key)) {
				if (std.mem.eql(u8, compact, "[")) {
					current_array = key;
					collecting_unknown = false;
					comment_buffer.clearRetainingCapacity();
				} else if (isInlineArray(value)) {
					const inner = value[1 .. value.len - 1];
					try parseInlineCollection(&state, key, inner);
					state.needs_migration = true;
				} else {
					const duped = try state.dupeStr(raw_line);
					try state.passthrough_lines.append(allocator, duped);
				}
			} else {
				// Unknown key
				if (std.mem.eql(u8, compact, "[")) {
					current_array = key;
					collecting_unknown = true;
					const duped = try state.dupeStr(raw_line);
					try unknown_buffer.append(allocator, duped);
				} else {
					const duped = try state.dupeStr(raw_line);
					try state.passthrough_lines.append(allocator, duped);
				}
			}
		} else {
			const duped = try state.dupeStr(raw_line);
			try state.passthrough_lines.append(allocator, duped);
		}
	}

	if (format == .legacy) {
		state.needs_migration = true;
	}

	// v1.1 → v1.2 migration: convert regex entries that were originally globs back to globs
	if (state.needs_migration) {
		const collections = [_]*std.ArrayListUnmanaged(StateEntry){
			&state.open_entries,
			&state.close_entries,
			&state.show_entries,
			&state.hide_entries,
		};
		for (collections) |list| {
			for (list.items) |*entry| {
				if (entry.kind == .regex) {
					if (regex_mod.regexToGlob(allocator, entry.value) catch null) |glob| {
						try state.strings.append(allocator, glob);
						entry.value = glob;
						entry.kind = .glob;
					}
				}
			}
		}
	}

	return state;
}

/// Write a state file to the writer in INI-MA format.
pub fn writeStateFile(state: *const StateFile, writer: anytype) !void {
	try writer.print("{s}\n", .{STATE_HEADER_COMMENT});
	try writer.print("{s}\n", .{STATE_VERSION_LABEL});

	var wrote_block = false;

	// Default
	if (state.default_state_set) {
		if (state.default_state) |ds| {
			try writer.print("default={s}\n", .{ds.toString()});
			wrote_block = true;
		}
	} else if (state.default_state != null) {
		try writer.print("default={s}\n", .{state.default_state.?.toString()});
		wrote_block = true;
	}

	// Scalars
	var scalar_count: usize = 0;
	if (state.depth != null) scalar_count += 1;
	if (state.sort_mode != null) scalar_count += 1;
	if (state.sort_direction != null) scalar_count += 1;
	if (state.color_preference != null) scalar_count += 1;
	if (state.hyperlink_preference != null) scalar_count += 1;
	if (state.max_lines != null) scalar_count += 1;

	if (scalar_count > 0) {
		if (wrote_block) try writer.print("\n", .{});
		if (state.depth) |d| {
			try writer.print("depth={}\n", .{d});
		}
		if (state.sort_mode) |m| {
			try writer.print("sort={s}\n", .{m.toString()});
		}
		if (state.sort_direction) |d| {
			try writer.print("sort_direction={s}\n", .{d.toString()});
		}
		if (state.color_preference) |c| {
			try writer.print("color={s}\n", .{if (c) "true" else "false"});
		}
		if (state.hyperlink_preference) |h| {
			try writer.print("hyperlink={s}\n", .{if (h) "true" else "false"});
		}
		if (state.max_lines) |ml| {
			try writer.print("max_lines={}\n", .{ml});
		}
		wrote_block = true;
	}

	// Collections - open, close, show, hide
	inline for (.{ "open", "close", "show", "hide" }) |key| {
		const entries = @field(state, key ++ "_entries");
		if (entries.items.len > 0) {
			if (wrote_block) try writer.print("\n", .{});
			try writer.print("{s}=[\n", .{key});

			// Sort entries alphabetically by their serialized form
			// (matching bash persist_state behavior: literals and /regex/ sorted together)
			const sorted = sortEntriesForOutput(entries.items);
			for (sorted) |entry| {
				if (entry.comment) |c| {
					try writer.writeAll(c);
				}
				switch (entry.kind) {
					.regex => {
						if (entry.negated) {
							try writer.print("\t!/{s}/\n", .{entry.value});
						} else {
							try writer.print("\t/{s}/\n", .{entry.value});
						}
					},
					.glob => {
						if (entry.negated) {
							try writer.print("\t!{s}\n", .{entry.value});
						} else {
							try writer.print("\t{s}\n", .{entry.value});
						}
					},
					.literal => {
						try writer.print("\t{s}\n", .{entry.value});
					},
				}
			}
			try writer.print("]\n", .{});
			wrote_block = true;
		}
	}

	// Passthrough
	if (state.passthrough_lines.items.len > 0) {
		if (wrote_block) try writer.print("\n", .{});
		for (state.passthrough_lines.items) |line| {
			try writer.print("{s}\n", .{line});
		}
	}
}

/// Sort entries by their serialized form for deterministic output.
/// Regex entries are serialized as "/pattern/" or "!/pattern/" before comparison.
/// Uses in-place sort on the items slice.
fn sortEntriesForOutput(items: []StateEntry) []StateEntry {
	std.mem.sort(StateEntry, items, {}, entryLessThan);
	return items;
}

fn entryLessThan(_: void, a: StateEntry, b: StateEntry) bool {
	// Compare by serialized form: regex entries are wrapped as /pattern/ or !/pattern/
	// Literals are compared as-is
	return compareEntrySerialized(a, b);
}

/// Compare two entries by their serialized form (as they'd appear in the state file, minus tab prefix).
/// This matches bash's `sort` on wrapped entries: `/pattern/`, `!/pattern/`, or `literal`.
fn compareEntrySerialized(a: StateEntry, b: StateEntry) bool {
	// Build virtual prefixes for comparison
	// For regex: "/" (or "!/"), for literal: ""
	// Then compare prefix + value + suffix character by character
	const a_prefix: []const u8 = switch (a.kind) {
		.regex => if (a.negated) "!/" else "/",
		.glob => if (a.negated) "!" else "",
		.literal => "",
	};
	const b_prefix: []const u8 = switch (b.kind) {
		.regex => if (b.negated) "!/" else "/",
		.glob => if (b.negated) "!" else "",
		.literal => "",
	};
	const a_suffix: []const u8 = if (a.kind == .regex) "/" else "";
	const b_suffix: []const u8 = if (b.kind == .regex) "/" else "";

	// Total virtual lengths
	const a_total = a_prefix.len + a.value.len + a_suffix.len;
	const b_total = b_prefix.len + b.value.len + b_suffix.len;

	var i: usize = 0;
	while (i < a_total and i < b_total) : (i += 1) {
		const ac = virtualCharAt(a_prefix, a.value, a_suffix, i);
		const bc = virtualCharAt(b_prefix, b.value, b_suffix, i);
		if (ac < bc) return true;
		if (ac > bc) return false;
	}

	return a_total < b_total;
}

fn virtualCharAt(prefix: []const u8, value: []const u8, suffix: []const u8, idx: usize) u8 {
	if (idx < prefix.len) return prefix[idx];
	const val_idx = idx - prefix.len;
	if (val_idx < value.len) return value[val_idx];
	const suf_idx = val_idx - value.len;
	if (suf_idx < suffix.len) return suffix[suf_idx];
	return 0;
}

// Helper functions

fn isComment(line: []const u8) bool {
	const s = stripLeading(line);
	return s.len > 0 and s[0] == '#';
}

fn isHeaderComment(line: []const u8) bool {
	const s = stripLeading(line);
	return std.mem.eql(u8, s, STATE_HEADER_COMMENT);
}

fn isKnownArrayKey(key: []const u8) bool {
	return std.mem.eql(u8, key, "open") or
		std.mem.eql(u8, key, "close") or
		std.mem.eql(u8, key, "show") or
		std.mem.eql(u8, key, "hide");
}

fn isInlineArray(value: []const u8) bool {
	if (value.len < 2) return false;
	return value[0] == '[' and value[value.len - 1] == ']';
}

fn parseVersion(line: []const u8) ?[]const u8 {
	// ver=X.X or verX.X
	if (std.mem.startsWith(u8, line, "ver=")) {
		const rest = strip(line[4..]);
		// Validate it's a version number
		for (rest) |c| {
			if (c != '.' and !std.ascii.isDigit(c)) return null;
		}
		if (rest.len > 0) return rest;
	}
	if (std.mem.startsWith(u8, line, "ver")) {
		const rest = line[3..];
		for (rest) |c| {
			if (c != '.' and !std.ascii.isDigit(c)) return null;
		}
		if (rest.len > 0) return rest;
	}
	return null;
}

const KeyValue = struct {
	key: []const u8,
	value: []const u8,
};

fn parseKeyValue(line: []const u8) ?KeyValue {
	// Find '='
	const eq_pos = std.mem.indexOfScalar(u8, line, '=') orelse return null;
	if (eq_pos == 0) return null;

	const key = strip(line[0..eq_pos]);
	// Validate key is alphanumeric + underscore
	for (key) |c| {
		if (!std.ascii.isAlphanumeric(c) and c != '_') return null;
	}
	if (key.len == 0) return null;

	var value = line[eq_pos + 1 ..];
	// Strip single leading space after =
	if (value.len > 0 and value[0] == ' ') {
		value = value[1..];
	}

	return KeyValue{ .key = key, .value = value };
}

fn processDefaultToken(state: *StateFile, token: []const u8) void {
	if (std.ascii.eqlIgnoreCase(token, "open") or std.ascii.eqlIgnoreCase(token, "opened")) {
		state.default_state = .opened;
		state.default_state_set = true;
		if (std.ascii.eqlIgnoreCase(token, "open")) state.needs_migration = true;
	} else if (std.ascii.eqlIgnoreCase(token, "close") or std.ascii.eqlIgnoreCase(token, "closed")) {
		state.default_state = .closed;
		state.default_state_set = true;
		if (std.ascii.eqlIgnoreCase(token, "close")) state.needs_migration = true;
	}
}

fn parseDefaultScalar(state: *StateFile, value: []const u8) void {
	// Handle semicolon-separated or space-separated tokens
	var iter = std.mem.tokenizeAny(u8, value, "; ");
	while (iter.next()) |token| {
		processDefaultToken(state, token);
	}
}

fn parseInlineDefault(state: *StateFile, content: []const u8) void {
	var iter = splitInlineItems(content);
	while (iter.next()) |token| {
		if (token.len == 0) continue;
		processDefaultToken(state, token);
	}
}

fn parseInlineCollection(state: *StateFile, key: []const u8, content: []const u8) !void {
	var iter = splitInlineItems(content);
	while (iter.next()) |token| {
		if (token.len == 0) continue;

		// Try regex
		const parsed = regex_mod.parseWrappedRegexToken(token) catch continue;
		if (parsed) |p| {
			const val = try state.dupeStr(p.pattern);
			const target = getEntryList(state, key);
			if (!StateFile.hasRegex(target.items, val, p.negated)) {
				try state.addEntry(target, .{
					.value = val,
					.kind = .regex,
					.negated = p.negated,
				});
			}
			continue;
		}

		// Check for glob
		if (regex_mod.isGlobPattern(token)) {
			const val = try state.dupeStr(token);
			const target = getEntryList(state, key);
			if (!StateFile.hasGlob(target.items, val, false)) {
				try state.addEntry(target, .{
					.value = val,
					.kind = .glob,
					.negated = false,
				});
			}
			continue;
		}

		// Literal
		const val = try state.dupeStr(token);
		const target = getEntryList(state, key);
		if (!StateFile.hasLiteral(target.items, val)) {
			try state.addEntry(target, .{
				.value = val,
				.kind = .literal,
				.negated = false,
			});
		}
	}
}

fn parseLegacyLine(state: *StateFile, line: []const u8, raw_line: []const u8) !void {
	if (parseKeyValue(line)) |kv| {
		if (std.mem.eql(u8, kv.key, "default")) {
			parseDefaultScalar(state, kv.value);
		} else if (std.mem.eql(u8, kv.key, "depth")) {
			const value = strip(kv.value);
			if (std.fmt.parseInt(u32, value, 10)) |d| {
				state.depth = d;
			} else |_| {
				const duped = try state.dupeStr(raw_line);
				try state.passthrough_lines.append(state.allocator, duped);
			}
		} else if (std.mem.eql(u8, kv.key, "open") or
			std.mem.eql(u8, kv.key, "close") or
			std.mem.eql(u8, kv.key, "show") or
			std.mem.eql(u8, kv.key, "hide"))
		{
			try parseLegacyCollection(state, kv.key, kv.value);
		} else if (std.mem.eql(u8, kv.key, "open_regex") or
			std.mem.eql(u8, kv.key, "close_regex") or
			std.mem.eql(u8, kv.key, "show_regex") or
			std.mem.eql(u8, kv.key, "hide_regex"))
		{
			const base_key = kv.key[0 .. kv.key.len - 6]; // strip "_regex"
			try parseLegacyRegexList(state, base_key, kv.value);
		} else {
			const duped = try state.dupeStr(raw_line);
			try state.passthrough_lines.append(state.allocator, duped);
		}
	} else {
		const duped = try state.dupeStr(raw_line);
		try state.passthrough_lines.append(state.allocator, duped);
	}
}

fn parseLegacyCollection(state: *StateFile, key: []const u8, value: []const u8) !void {
	var iter = std.mem.tokenizeScalar(u8, value, ';');
	while (iter.next()) |token| {
		const trimmed = strip(token);
		if (trimmed.len == 0) continue;

		// For show/hide, check wrapped regex
		if (std.mem.eql(u8, key, "show") or std.mem.eql(u8, key, "hide")) {
			const parsed = regex_mod.parseWrappedRegexToken(trimmed) catch continue;
			if (parsed) |p| {
				const val = try state.dupeStr(p.pattern);
				const target = getEntryList(state, key);
				if (!StateFile.hasRegex(target.items, val, p.negated)) {
					try state.addEntry(target, .{ .value = val, .kind = .regex, .negated = p.negated });
				}
				continue;
			}
		}

		const val = try state.dupeStr(trimmed);
		const target = getEntryList(state, key);
		if (!StateFile.hasLiteral(target.items, val)) {
			try state.addEntry(target, .{ .value = val, .kind = .literal, .negated = false });
		}
	}
}

fn parseLegacyRegexList(state: *StateFile, base_key: []const u8, value: []const u8) !void {
	var iter = std.mem.tokenizeScalar(u8, value, ';');
	while (iter.next()) |token| {
		const trimmed = strip(token);
		if (trimmed.len == 0) continue;
		const val = try state.dupeStr(trimmed);
		const target = getEntryList(state, base_key);
		if (!StateFile.hasRegex(target.items, val, false)) {
			try state.addEntry(target, .{ .value = val, .kind = .regex, .negated = false });
		}
	}
}

fn getEntryList(state: *StateFile, key: []const u8) *std.ArrayListUnmanaged(StateEntry) {
	if (std.mem.eql(u8, key, "open")) return &state.open_entries;
	if (std.mem.eql(u8, key, "close")) return &state.close_entries;
	if (std.mem.eql(u8, key, "show")) return &state.show_entries;
	if (std.mem.eql(u8, key, "hide")) return &state.hide_entries;
	unreachable;
}

// String utilities

fn strip(s: []const u8) []const u8 {
	return stripTrailing(stripLeading(s));
}

fn stripLeading(s: []const u8) []const u8 {
	var i: usize = 0;
	while (i < s.len and (s[i] == ' ' or s[i] == '\t')) : (i += 1) {}
	return s[i..];
}

fn stripTrailing(s: []const u8) []const u8 {
	var end = s.len;
	while (end > 0 and (s[end - 1] == ' ' or s[end - 1] == '\t')) : (end -= 1) {}
	return s[0..end];
}

fn stripWhitespace(s: []const u8) []const u8 {
	// Remove ALL whitespace to get compact form
	// For simple checks, just strip leading and trailing
	return strip(s);
}

const InlineItemIterator = struct {
	content: []const u8,
	pos: usize,

	fn next(self: *InlineItemIterator) ?[]const u8 {
		// Skip leading whitespace
		while (self.pos < self.content.len and
			(self.content[self.pos] == ' ' or self.content[self.pos] == '\t'))
		{
			self.pos += 1;
		}
		if (self.pos >= self.content.len) return null;

		const start = self.pos;
		var in_escape = false;
		while (self.pos < self.content.len) {
			if (in_escape) {
				in_escape = false;
				self.pos += 1;
				continue;
			}
			if (self.content[self.pos] == '\\') {
				in_escape = true;
				self.pos += 1;
				continue;
			}
			if (self.content[self.pos] == ' ' or self.content[self.pos] == '\t') {
				break;
			}
			self.pos += 1;
		}

		const token = self.content[start..self.pos];
		return if (token.len > 0) token else self.next();
	}
};

fn splitInlineItems(content: []const u8) InlineItemIterator {
	return InlineItemIterator{ .content = content, .pos = 0 };
}

// Tests

test "parse empty state file" {
	var state = try parseStateFile(std.testing.allocator, "");
	defer state.deinit();
	try std.testing.expect(state.default_state == null);
	try std.testing.expect(state.depth == null);
}

test "parse simple state file" {
	const content = "ver=1.1\ndepth=3\n\nclose=[\n\t.git\n\t/^(.*/)?node_modules$/\n]\n\nhide=[\n\t.gitignore\n]";
	var state = try parseStateFile(std.testing.allocator, content);
	defer state.deinit();

	try std.testing.expectEqual(@as(u32, 3), state.depth.?);
	try std.testing.expectEqual(@as(usize, 2), state.close_entries.items.len);

	// First entry: .git (literal)
	try std.testing.expectEqualStrings(".git", state.close_entries.items[0].value);
	try std.testing.expect(state.close_entries.items[0].kind == .literal);

	// Second entry: was regex in v1.1, migrated to glob
	try std.testing.expectEqualStrings("**/node_modules", state.close_entries.items[1].value);
	try std.testing.expect(state.close_entries.items[1].kind == .glob);

	// Hide
	try std.testing.expectEqual(@as(usize, 1), state.hide_entries.items.len);
	try std.testing.expectEqualStrings(".gitignore", state.hide_entries.items[0].value);
}

test "parse state with default" {
	const content =
		\\ver=1.1
		\\default=closed
	;
	var state = try parseStateFile(std.testing.allocator, content);
	defer state.deinit();
	try std.testing.expectEqual(DefaultState.closed, state.default_state.?);
	try std.testing.expect(state.default_state_set);
}

test "parse state with default array" {
	const content = "ver=1.1\ndefault=[\n\tclosed\n]";
	var state = try parseStateFile(std.testing.allocator, content);
	defer state.deinit();
	try std.testing.expectEqual(DefaultState.closed, state.default_state.?);
}

test "round-trip: parse then write produces equivalent output" {
	const input = "ver=1.2\ndepth=3\n\nclose=[\n\t.git\n\t**/node_modules\n]\n\nhide=[\n\t.gitignore\n]";
	var state = try parseStateFile(std.testing.allocator, input);
	defer state.deinit();

	var buf: [4096]u8 = undefined;
	var fbs = std.io.fixedBufferStream(&buf);
	try writeStateFile(&state, fbs.writer());
	const output = fbs.getWritten();

	// The output should have the header comment and ver=1.2,
	// then the same structure
	try std.testing.expect(std.mem.indexOf(u8, output, STATE_HEADER_COMMENT) != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "ver=1.2") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "depth=3") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "close=[") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "\t.git") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "\t**/node_modules\n") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "hide=[") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "\t.gitignore") != null);
}

test "parse suggested-default-home-dir state file" {
	const content = "ver=1.1\ndepth=3\n\nclose=[\n" ++
		"\t/^(.*/)?_build$/\n" ++
		"\t/^(.*/)?\\.cache$/\n" ++
		"\t/^(.*/)?\\.cargo$/\n" ++
		"\t/^(.*/)?\\.claude$/\n" ++
		"\t/^(.*/)?\\.git$/\n" ++
		"\t/^(.*/)?node_modules$/\n" ++
		"\tVideos\n" ++
		"\t/^(.*/)?\\.vscode[^/]*$/\n" ++
		"\t/^(.*/)?\\.vscode$/\n" ++
		"]\n\nhide=[\n\t.gitignore\n]";
	var state = try parseStateFile(std.testing.allocator, content);
	defer state.deinit();

	try std.testing.expectEqual(@as(u32, 3), state.depth.?);
	try std.testing.expectEqual(@as(usize, 9), state.close_entries.items.len);
	try std.testing.expectEqual(@as(usize, 1), state.hide_entries.items.len);

	// Check Videos is a literal
	var found_videos = false;
	for (state.close_entries.items) |e| {
		if (std.mem.eql(u8, e.value, "Videos") and e.kind == .literal) {
			found_videos = true;
		}
	}
	try std.testing.expect(found_videos);
}

test "parse state with passthrough" {
	const content =
		\\ver=1.1
		\\custom_key=some_value
	;
	var state = try parseStateFile(std.testing.allocator, content);
	defer state.deinit();
	try std.testing.expectEqual(@as(usize, 1), state.passthrough_lines.items.len);
	try std.testing.expectEqualStrings("custom_key=some_value", state.passthrough_lines.items[0]);
}

test "parse state with sort" {
	const content =
		\\ver=1.1
		\\sort=alpha
		\\sort_direction=asc
	;
	var state = try parseStateFile(std.testing.allocator, content);
	defer state.deinit();
	try std.testing.expectEqual(SortMode.alpha, state.sort_mode.?);
	try std.testing.expectEqual(SortDirection.asc, state.sort_direction.?);
}

test "parse state with color and hyperlink" {
	const content =
		\\ver=1.1
		\\color=false
		\\hyperlink=false
	;
	var state = try parseStateFile(std.testing.allocator, content);
	defer state.deinit();
	try std.testing.expect(!state.color_preference.?);
	try std.testing.expect(!state.hyperlink_preference.?);
}

test "parse inline array" {
	const content =
		\\ver=1.1
		\\close=[.git node_modules]
	;
	var state = try parseStateFile(std.testing.allocator, content);
	defer state.deinit();
	try std.testing.expectEqual(@as(usize, 2), state.close_entries.items.len);
	try std.testing.expect(state.needs_migration);
}

test "write state file with all fields" {
	var state = StateFile{ .allocator = std.testing.allocator };
	defer state.deinit();

	state.default_state = .closed;
	state.default_state_set = true;
	state.depth = 5;
	state.sort_mode = .alpha;
	state.sort_direction = .asc;

	const val1 = try state.dupeStr("src");
	try state.addEntry(&state.open_entries, .{ .value = val1, .kind = .literal, .negated = false });
	const val2 = try state.dupeStr("^test$");
	try state.addEntry(&state.close_entries, .{ .value = val2, .kind = .regex, .negated = false });

	var buf: [4096]u8 = undefined;
	var fbs = std.io.fixedBufferStream(&buf);
	try writeStateFile(&state, fbs.writer());
	const output = fbs.getWritten();

	try std.testing.expect(std.mem.indexOf(u8, output, "default=closed") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "depth=5") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "sort=alpha") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "sort_direction=asc") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "open=[") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "\tsrc") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "close=[") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "\t/^test$/") != null);
}

test "legacy state sort order matches bash" {
	const allocator = std.testing.allocator;
	const input =
		\\default=open
		\\open=src;lib
		\\open_regex=^docs
		\\close=logs
		\\close_regex=temp$
		\\show=README.md;docs/index.md
		\\show_regex=^docs/.*/index$
		\\hide=temp
		\\hide_regex=\.log$
	;
	var sf = try parseStateFile(allocator, input);
	defer sf.deinit();

	var buf: [4096]u8 = undefined;
	var fbs = std.io.fixedBufferStream(&buf);
	try writeStateFile(&sf, fbs.writer());
	const output = fbs.getWritten();

	// After migration, ^docs/.*/index$ is converted to glob docs/**/index
	// Expected sort order: README.md < docs/**/index < docs/index.md (ASCII: '*' < '/')
	const show_start = std.mem.indexOf(u8, output, "show=[") orelse return error.NoShowSection;
	const show_section = output[show_start..];
	const readme_pos = std.mem.indexOf(u8, show_section, "\tREADME.md\n") orelse return error.NoReadme;
	const docs_pos = std.mem.indexOf(u8, show_section, "\tdocs/index.md\n") orelse return error.NoDocs;
	const glob_pos = std.mem.indexOf(u8, show_section, "\tdocs/**/index\n") orelse return error.NoGlob;
	try std.testing.expect(readme_pos < glob_pos);
	try std.testing.expect(glob_pos < docs_pos);
}

test "v1.1 to v1.2 migration converts regex to glob" {
	const allocator = std.testing.allocator;
	const input = "ver=1.1\nhide=[\n\t/^[^/]*\\.log$/\n\t/^(.*/)?node_modules$/\n\t.gitignore\n]";
	var sf = try parseStateFile(allocator, input);
	defer sf.deinit();

	// Should be flagged for migration
	try std.testing.expect(sf.needs_migration);

	// The glob-convertible regex entries should now be globs
	try std.testing.expectEqual(@as(usize, 3), sf.hide_entries.items.len);

	// *.log was converted from regex to glob
	const e0 = sf.hide_entries.items[0];
	try std.testing.expectEqualStrings("*.log", e0.value);
	try std.testing.expectEqual(PatternKind.glob, e0.kind);

	// **/node_modules was converted from regex to glob
	const e1 = sf.hide_entries.items[1];
	try std.testing.expectEqualStrings("**/node_modules", e1.value);
	try std.testing.expectEqual(PatternKind.glob, e1.kind);

	// .gitignore stays literal (was never regex)
	const e2 = sf.hide_entries.items[2];
	try std.testing.expectEqualStrings(".gitignore", e2.value);
	try std.testing.expectEqual(PatternKind.literal, e2.kind);

	// Written output should have ver=1.2 and bare globs
	var buf: [4096]u8 = undefined;
	var fbs = std.io.fixedBufferStream(&buf);
	try writeStateFile(&sf, fbs.writer());
	const output = fbs.getWritten();

	try std.testing.expect(std.mem.indexOf(u8, output, "ver=1.2") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "\t*.log\n") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "\t**/node_modules\n") != null);
	try std.testing.expect(std.mem.indexOf(u8, output, "\t.gitignore\n") != null);
	// Should NOT contain the old regex forms
	try std.testing.expect(std.mem.indexOf(u8, output, "/^[^/]*\\.log$/") == null);
	try std.testing.expect(std.mem.indexOf(u8, output, "/^(.*/)?node_modules$/") == null);
}

test "v1.2 state file does not trigger migration" {
	const allocator = std.testing.allocator;
	const input = "ver=1.2\nhide=[\n\t*.log\n\t/^custom\\d+$/\n]";
	var sf = try parseStateFile(allocator, input);
	defer sf.deinit();

	try std.testing.expect(!sf.needs_migration);
	try std.testing.expectEqual(PatternKind.glob, sf.hide_entries.items[0].kind);
	try std.testing.expectEqual(PatternKind.regex, sf.hide_entries.items[1].kind);
}

test "unconvertible regex stays as regex during migration" {
	const allocator = std.testing.allocator;
	const input = "ver=1.1\nhide=[\n\t/^[^/]*\\.log$/\n\t/^custom\\d+$/\n]";
	var sf = try parseStateFile(allocator, input);
	defer sf.deinit();

	try std.testing.expect(sf.needs_migration);

	// *.log should be converted
	try std.testing.expectEqual(PatternKind.glob, sf.hide_entries.items[0].kind);
	try std.testing.expectEqualStrings("*.log", sf.hide_entries.items[0].value);

	// \d+ pattern can't be converted — stays as regex
	try std.testing.expectEqual(PatternKind.regex, sf.hide_entries.items[1].kind);
	try std.testing.expectEqualStrings("^custom\\d+$", sf.hide_entries.items[1].value);
}
