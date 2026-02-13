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

/// Attempt to reverse a regex pattern back to a glob, if it was produced by globToRegex.
/// Returns null if the regex uses features that globToRegex never produces.
/// The caller owns the returned slice (if non-null).
pub fn regexToGlob(allocator: std.mem.Allocator, pattern: []const u8) !?[]u8 {
	// Must start with ^ and end with $
	if (pattern.len < 2 or pattern[0] != '^' or pattern[pattern.len - 1] != '$') return null;

	const inner = pattern[1 .. pattern.len - 1];
	var result: std.ArrayListUnmanaged(u8) = .{};
	defer result.deinit(allocator);

	var i: usize = 0;
	while (i < inner.len) {
		const c = inner[i];

		// Try to match known globToRegex output patterns:

		// "(.*/)?" → "**/"
		if (i + 6 <= inner.len and std.mem.eql(u8, inner[i .. i + 6], "(.*/)?")) {
			try result.appendSlice(allocator, "**/");
			i += 6;
			continue;
		}

		// "[^/]*" → "*"
		if (i + 5 <= inner.len and std.mem.eql(u8, inner[i .. i + 5], "[^/]*")) {
			try result.append(allocator, '*');
			i += 5;
			continue;
		}

		// ".*" → "**" (only if not part of "(.*/?)")
		if (i + 2 <= inner.len and std.mem.eql(u8, inner[i .. i + 2], ".*")) {
			try result.appendSlice(allocator, "**");
			i += 2;
			continue;
		}

		// "[^/]" (without trailing *) → "?"
		if (i + 4 <= inner.len and std.mem.eql(u8, inner[i .. i + 4], "[^/]")) {
			// Make sure this isn't "[^/]*" (already handled above)
			try result.append(allocator, '?');
			i += 4;
			continue;
		}

		// "[...]" character class → pass through as glob "[...]"
		if (c == '[') {
			var j = i + 1;
			// Skip negation
			if (j < inner.len and inner[j] == '^') j += 1;
			// Skip ] as first char in class
			if (j < inner.len and inner[j] == ']') j += 1;
			// Find closing ]
			while (j < inner.len) {
				if (inner[j] == '\\' and j + 1 < inner.len) {
					j += 2; // skip escaped char
					continue;
				}
				if (inner[j] == ']') {
					// Found valid class — copy it through, unescaping internal chars
					try result.append(allocator, '[');
					var k = i + 1;
					// Handle negation: ^ in regex → ! in glob
					if (k < j and inner[k] == '^') {
						try result.append(allocator, '!');
						k += 1;
					}
					while (k < j) {
						if (inner[k] == '\\' and k + 1 < j) {
							// Unescape chars that globToRegex escapes inside classes
							try result.append(allocator, inner[k + 1]);
							k += 2;
						} else {
							try result.append(allocator, inner[k]);
							k += 1;
						}
					}
					try result.append(allocator, ']');
					i = j + 1;
					break;
				}
				j += 1;
			}
			if (j >= inner.len) return null; // unclosed class — not from globToRegex
			continue;
		}

		// Escaped metacharacter → literal in glob
		if (c == '\\' and i + 1 < inner.len) {
			const escaped = inner[i + 1];
			switch (escaped) {
				'.', '+', '^', '$', '(', ')', '{', '}', '|', '\\', '[' => {
					try result.append(allocator, escaped);
					i += 2;
					continue;
				},
				else => {
					// \d, \w, \s, etc. — not produced by globToRegex
					return null;
				},
			}
		}

		// Unescaped regex metacharacters that globToRegex never produces
		switch (c) {
			'|', '(', ')', '{', '}', '+', '?' => return null,
			'.' => return null, // unescaped dot — globToRegex always escapes dots
			else => {
				// Literal character — pass through
				try result.append(allocator, c);
			},
		}
		i += 1;
	}

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

test "regexToGlob: simple star" {
	const allocator = std.testing.allocator;
	const result = try regexToGlob(allocator, "^[^/]*\\.txt$");
	defer allocator.free(result.?);
	try std.testing.expectEqualStrings("*.txt", result.?);
}

test "regexToGlob: double star with slash prefix" {
	const allocator = std.testing.allocator;
	const result = try regexToGlob(allocator, "^(.*/)?node_modules$");
	defer allocator.free(result.?);
	try std.testing.expectEqualStrings("**/node_modules", result.?);
}

test "regexToGlob: bare double star" {
	const allocator = std.testing.allocator;
	const result = try regexToGlob(allocator, "^.*$");
	defer allocator.free(result.?);
	try std.testing.expectEqualStrings("**", result.?);
}

test "regexToGlob: question mark" {
	const allocator = std.testing.allocator;
	const result = try regexToGlob(allocator, "^file[^/]\\.log$");
	defer allocator.free(result.?);
	try std.testing.expectEqualStrings("file?.log", result.?);
}

test "regexToGlob: character class passthrough" {
	const allocator = std.testing.allocator;
	const result = try regexToGlob(allocator, "^[abc]\\.txt$");
	defer allocator.free(result.?);
	try std.testing.expectEqualStrings("[abc].txt", result.?);
}

test "regexToGlob: escaped metacharacters" {
	const allocator = std.testing.allocator;
	const result = try regexToGlob(allocator, "^foo\\.bar\\+baz$");
	defer allocator.free(result.?);
	try std.testing.expectEqualStrings("foo.bar+baz", result.?);
}

test "regexToGlob: not a converted glob returns null" {
	const allocator = std.testing.allocator;
	// Alternation - not produced by globToRegex
	try std.testing.expect(try regexToGlob(allocator, "^foo|bar$") == null);
	// No anchors
	try std.testing.expect(try regexToGlob(allocator, "foo") == null);
	// Shorthand character classes - not produced by globToRegex
	try std.testing.expect(try regexToGlob(allocator, "^\\d+$") == null);
}

test "regexToGlob: roundtrip with globToRegex" {
	const allocator = std.testing.allocator;
	const globs = [_][]const u8{ "*.log", "**/src", "file?.txt", "[abc].md", "foo.bar" };
	for (globs) |glob| {
		const re = try globToRegex(allocator, glob);
		defer allocator.free(re);
		const back = try regexToGlob(allocator, re);
		defer allocator.free(back.?);
		try std.testing.expectEqualStrings(glob, back.?);
	}
}
