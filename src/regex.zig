const std = @import("std");

/// Result of parsing a /pattern/ or !/pattern/ token
pub const ParsedRegex = struct {
	pattern: []const u8,
	negated: bool,
};

/// Parse a wrapped regex token like /pattern/ or !/pattern/.
/// Returns null if the token is not a wrapped regex.
/// Returns error.EmptyPattern if the delimiters are present but the pattern is empty.
pub fn parseWrappedRegexToken(token: []const u8) !?ParsedRegex {
	if (token.len == 0) return null;

	// Check for !/pattern/ form
	if (token[0] == '!' and token.len >= 2 and token[1] == '/') {
		if (token[token.len - 1] != '/') return null;
		if (token.len <= 3) return error.EmptyPattern;
		const inner = token[2 .. token.len - 1];
		if (inner.len == 0) return error.EmptyPattern;
		return ParsedRegex{ .pattern = inner, .negated = true };
	}

	// Check for /pattern/ form
	if (token[0] == '/') {
		if (token[token.len - 1] != '/') return null;
		if (token.len <= 2) return error.EmptyPattern;
		const inner = token[1 .. token.len - 1];
		if (inner.len == 0) return error.EmptyPattern;
		return ParsedRegex{ .pattern = inner, .negated = false };
	}

	return null;
}

/// Check if a token is a glob pattern (contains *, ?, or [).
/// Tokens starting with re: or RE: are not considered globs.
/// Escaped wildcards (\*) are not considered globs.
pub fn isGlobPattern(token: []const u8) bool {
	// re: prefix means not a glob
	if (token.len >= 3 and (std.mem.eql(u8, token[0..3], "re:") or std.mem.eql(u8, token[0..3], "RE:"))) {
		return false;
	}
	// Check for trailing backslash (escaped)
	if (token.len > 0 and token[token.len - 1] == '\\') {
		return false;
	}
	for (token) |c| {
		if (c == '*' or c == '?' or c == '[') return true;
	}
	return false;
}

/// Convert a glob pattern to a regex pattern.
/// Supports: * (non-slash), ** (any), ?  (non-slash char), [class]
/// Escapes regex metacharacters in literal portions.
pub fn globToRegex(allocator: std.mem.Allocator, glob: []const u8) ![]u8 {
	var result: std.ArrayListUnmanaged(u8) = .{};
	defer result.deinit(allocator);

	try result.append(allocator, '^');

	var i: usize = 0;
	while (i < glob.len) {
		const c = glob[i];
		switch (c) {
			'*' => {
				if (i + 1 < glob.len and glob[i + 1] == '*') {
					if (i + 2 < glob.len and glob[i + 2] == '/') {
						try result.appendSlice(allocator, "(.*/)?" );
						i += 3;
					} else {
						try result.appendSlice(allocator, ".*");
						i += 2;
					}
					continue;
				} else {
					try result.appendSlice(allocator, "[^/]*");
				}
			},
			'?' => {
				try result.appendSlice(allocator, "[^/]");
			},
			'[' => {
				// Parse character class
				var j = i + 1;
				var class_buf: std.ArrayListUnmanaged(u8) = .{};
				defer class_buf.deinit(allocator);

				try class_buf.append(allocator, '[');

				// Handle negation
				if (j < glob.len) {
					if (glob[j] == '!' or glob[j] == '^') {
						try class_buf.append(allocator, '^');
						j += 1;
					}
				}
				// Handle ] as first char in class
				if (j < glob.len and glob[j] == ']') {
					try class_buf.append(allocator, ']');
					j += 1;
				}

				var valid = false;
				while (j < glob.len) {
					const ch = glob[j];
					if (ch == ']') {
						valid = true;
						j += 1;
						break;
					}
					switch (ch) {
						'\\', '-', '[', ']', '^' => {
							try class_buf.append(allocator, '\\');
							try class_buf.append(allocator, ch);
						},
						else => {
							try class_buf.append(allocator, ch);
						},
					}
					j += 1;
				}

				if (!valid) {
					// Invalid class, treat [ as literal
					try result.appendSlice(allocator, "\\[");
					i += 1;
					continue;
				}

				try class_buf.append(allocator, ']');
				try result.appendSlice(allocator, class_buf.items);
				i = j;
				continue;
			},
			// Escape regex metacharacters
			'.', '+', '^', '$', '(', ')', '{', '}', '|', '\\' => {
				try result.append(allocator, '\\');
				try result.append(allocator, c);
			},
			else => {
				try result.append(allocator, c);
			},
		}
		i += 1;
	}

	try result.append(allocator, '$');
	return try result.toOwnedSlice(allocator);
}

// Tests
test "parseWrappedRegexToken: normal regex" {
	const result = try parseWrappedRegexToken("/^foo$/");
	try std.testing.expect(result != null);
	try std.testing.expectEqualStrings("^foo$", result.?.pattern);
	try std.testing.expect(!result.?.negated);
}

test "parseWrappedRegexToken: negated regex" {
	const result = try parseWrappedRegexToken("!/^bar$/");
	try std.testing.expect(result != null);
	try std.testing.expectEqualStrings("^bar$", result.?.pattern);
	try std.testing.expect(result.?.negated);
}

test "parseWrappedRegexToken: not a regex" {
	const result = try parseWrappedRegexToken("foo");
	try std.testing.expect(result == null);
}

test "parseWrappedRegexToken: empty pattern errors" {
	const result = parseWrappedRegexToken("//");
	try std.testing.expectError(error.EmptyPattern, result);
}

test "parseWrappedRegexToken: single slash is empty pattern" {
	const result = parseWrappedRegexToken("/");
	try std.testing.expectError(error.EmptyPattern, result);
}

test "isGlobPattern: wildcards detected" {
	try std.testing.expect(isGlobPattern("*.txt"));
	try std.testing.expect(isGlobPattern("foo?bar"));
	try std.testing.expect(isGlobPattern("[abc]"));
}

test "isGlobPattern: no wildcards" {
	try std.testing.expect(!isGlobPattern("foo.txt"));
	try std.testing.expect(!isGlobPattern("re:something"));
	try std.testing.expect(!isGlobPattern("RE:something"));
}

test "globToRegex: simple star" {
	const allocator = std.testing.allocator;
	const result = try globToRegex(allocator, "*.txt");
	defer allocator.free(result);
	try std.testing.expectEqualStrings("^[^/]*\\.txt$", result);
}

test "globToRegex: double star with slash" {
	const allocator = std.testing.allocator;
	const result = try globToRegex(allocator, "**/node_modules");
	defer allocator.free(result);
	try std.testing.expectEqualStrings("^(.*/)?node_modules$", result);
}

test "globToRegex: question mark" {
	const allocator = std.testing.allocator;
	const result = try globToRegex(allocator, "file?.log");
	defer allocator.free(result);
	try std.testing.expectEqualStrings("^file[^/]\\.log$", result);
}

test "globToRegex: character class" {
	const allocator = std.testing.allocator;
	const result = try globToRegex(allocator, "[abc].txt");
	defer allocator.free(result);
	try std.testing.expectEqualStrings("^[abc]\\.txt$", result);
}
