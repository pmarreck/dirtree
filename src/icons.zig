const std = @import("std");

/// Nerd Font icon codepoints for common file types.
/// These are UTF-8 encoded strings ready for output.

// Directory icons
pub const dir_icon = "\u{f115}"; //
pub const dir_open_icon = "\u{f115}"; //

// Special directory icons
pub const git_icon = "\u{e725}"; //
pub const node_modules_icon = "\u{e718}"; //

// Default file icon
pub const file_icon = "\u{f016}"; //

// Symlink
pub const symlink_icon = "\u{f0c1}"; //

// Executable
pub const exec_icon = "\u{f489}"; //

/// Get the icon for a file based on its extension.
pub fn getFileIcon(name: []const u8) []const u8 {
	// Exact-filename match takes precedence over the extension: Cargo.toml is
	// rust (not toml), package.json is node (not json), flake.lock is nix (not a
	// generic lock). Otherwise any special filename whose trailing extension also
	// matches extensionIcon would be shadowed and its arm rendered dead.
	if (filenameIcon(name)) |icon| return icon;
	const ext = getExtension(name);
	if (ext.len > 0) {
		if (extensionIcon(ext)) |icon| return icon;
	}
	return file_icon;
}

/// Get the icon for a directory based on its name.
pub fn getDirIcon(name: []const u8) []const u8 {
	if (std.mem.eql(u8, name, ".git")) return git_icon;
	if (std.mem.eql(u8, name, "node_modules")) return node_modules_icon;
	if (std.mem.eql(u8, name, ".github")) return git_icon;
	return dir_icon;
}

fn getExtension(name: []const u8) []const u8 {
	// Find last dot
	var i = name.len;
	while (i > 0) {
		i -= 1;
		if (name[i] == '.') {
			if (i == 0) return ""; // hidden file, no extension
			return name[i + 1 ..];
		}
	}
	return "";
}

// Extension -> Nerd Font icon. Comptime perfect-hash lookup (StaticStringMap)
// replacing the former linear if/eql chain. Each former `or`-group is expanded
// into one row per key; case-sensitive (e.g. `r` and `R` are distinct rows).
const extension_icons = std.StaticStringMap([]const u8).initComptime(.{
	// Programming languages
	.{ "zig", "\u{e6a9}" },
	.{ "rs", "\u{e7a8}" },
	.{ "go", "\u{e626}" },
	.{ "py", "\u{e73c}" },
	.{ "rb", "\u{e739}" },
	.{ "js", "\u{e74e}" },
	.{ "ts", "\u{e628}" },
	.{ "jsx", "\u{e7ba}" },
	.{ "tsx", "\u{e7ba}" },
	.{ "c", "\u{e61e}" },
	.{ "h", "\u{e61e}" },
	.{ "cpp", "\u{e61d}" },
	.{ "cc", "\u{e61d}" },
	.{ "cxx", "\u{e61d}" },
	.{ "hpp", "\u{e61d}" },
	.{ "hh", "\u{e61d}" },
	.{ "hxx", "\u{e61d}" },
	.{ "java", "\u{e738}" },
	.{ "lua", "\u{e620}" },
	.{ "ex", "\u{e62d}" },
	.{ "exs", "\u{e62d}" },
	.{ "erl", "\u{e7b1}" },
	.{ "hrl", "\u{e7b1}" },
	.{ "sh", "\u{f489}" },
	.{ "bash", "\u{f489}" },
	.{ "zsh", "\u{f489}" },
	.{ "pl", "\u{e769}" },
	.{ "pm", "\u{e769}" },
	.{ "swift", "\u{e755}" },
	.{ "kt", "\u{e634}" },
	.{ "kts", "\u{e634}" },
	.{ "scala", "\u{e737}" },
	.{ "cs", "\u{f81a}" },
	.{ "fs", "\u{e7a7}" },
	.{ "fsx", "\u{e7a7}" },
	.{ "hs", "\u{e777}" },
	.{ "clj", "\u{e768}" },
	.{ "cljs", "\u{e768}" },
	.{ "r", "\u{f25d}" },
	.{ "R", "\u{f25d}" },
	.{ "dart", "\u{e798}" },
	.{ "nim", "\u{e677}" },
	.{ "v", "\u{e6ac}" },
	.{ "asm", "\u{f471}" },
	.{ "s", "\u{f471}" },
	.{ "S", "\u{f471}" },
	.{ "wasm", "\u{e6a1}" },
	// Web
	.{ "html", "\u{e736}" },
	.{ "htm", "\u{e736}" },
	.{ "css", "\u{e749}" },
	.{ "scss", "\u{e749}" },
	.{ "sass", "\u{e749}" },
	.{ "less", "\u{e749}" },
	.{ "vue", "\u{e6a0}" },
	.{ "svelte", "\u{e697}" },
	// Data / config
	.{ "json", "\u{e60b}" },
	.{ "yaml", "\u{e6a8}" },
	.{ "yml", "\u{e6a8}" },
	.{ "toml", "\u{e6b2}" },
	.{ "xml", "\u{e619}" },
	.{ "csv", "\u{f1c3}" },
	.{ "sql", "\u{e706}" },
	.{ "graphql", "\u{e662}" },
	.{ "gql", "\u{e662}" },
	.{ "ini", "\u{e615}" },
	.{ "cfg", "\u{e615}" },
	.{ "conf", "\u{e615}" },
	// Documentation
	.{ "md", "\u{e73e}" },
	.{ "markdown", "\u{e73e}" },
	.{ "txt", "\u{f0f6}" },
	.{ "pdf", "\u{f1c1}" },
	.{ "doc", "\u{f1c2}" },
	.{ "docx", "\u{f1c2}" },
	.{ "xls", "\u{f1c3}" },
	.{ "xlsx", "\u{f1c3}" },
	.{ "ppt", "\u{f1c4}" },
	.{ "pptx", "\u{f1c4}" },
	.{ "tex", "\u{e69b}" },
	.{ "latex", "\u{e69b}" },
	.{ "org", "\u{e633}" },
	.{ "rst", "\u{f0f6}" },
	// Images
	.{ "png", "\u{f1c5}" },
	.{ "jpg", "\u{f1c5}" },
	.{ "jpeg", "\u{f1c5}" },
	.{ "gif", "\u{f1c5}" },
	.{ "bmp", "\u{f1c5}" },
	.{ "ico", "\u{f1c5}" },
	.{ "svg", "\u{f1c5}" },
	.{ "webp", "\u{f1c5}" },
	.{ "tiff", "\u{f1c5}" },
	.{ "heic", "\u{f1c5}" },
	.{ "heif", "\u{f1c5}" },
	.{ "avif", "\u{f1c5}" },
	// Audio
	.{ "mp3", "\u{f1c7}" },
	.{ "wav", "\u{f1c7}" },
	.{ "flac", "\u{f1c7}" },
	.{ "ogg", "\u{f1c7}" },
	.{ "aac", "\u{f1c7}" },
	.{ "m4a", "\u{f1c7}" },
	.{ "wma", "\u{f1c7}" },
	// Video
	.{ "mp4", "\u{f1c8}" },
	.{ "mkv", "\u{f1c8}" },
	.{ "avi", "\u{f1c8}" },
	.{ "mov", "\u{f1c8}" },
	.{ "wmv", "\u{f1c8}" },
	.{ "webm", "\u{f1c8}" },
	.{ "flv", "\u{f1c8}" },
	// Archives
	.{ "zip", "\u{f1c6}" },
	.{ "tar", "\u{f1c6}" },
	.{ "gz", "\u{f1c6}" },
	.{ "bz2", "\u{f1c6}" },
	.{ "xz", "\u{f1c6}" },
	.{ "7z", "\u{f1c6}" },
	.{ "rar", "\u{f1c6}" },
	.{ "zst", "\u{f1c6}" },
	// Build / DevOps
	.{ "nix", "\u{f313}" },
	.{ "dockerfile", "\u{f308}" },
	.{ "docker", "\u{f308}" },
	.{ "lock", "\u{f023}" },
	.{ "log", "\u{f18d}" },
	.{ "env", "\u{f462}" },
	.{ "zon", "\u{e6a9}" }, // Zig (build.zig.zon)
});

// Exact-filename -> icon. Same StaticStringMap refactor; expanded `or`-groups.
const filename_icons = std.StaticStringMap([]const u8).initComptime(.{
	.{ "Makefile", "\u{e615}" },
	.{ "makefile", "\u{e615}" },
	.{ "Dockerfile", "\u{f308}" },
	.{ "LICENSE", "\u{f0e3}" },
	.{ "LICENCE", "\u{f0e3}" },
	.{ "README.md", "\u{e73e}" },
	.{ "README", "\u{e73e}" },
	.{ ".gitignore", "\u{e725}" },
	.{ ".gitmodules", "\u{e725}" },
	.{ ".envrc", "\u{f462}" },
	.{ "flake.nix", "\u{f313}" },
	.{ "flake.lock", "\u{f313}" },
	.{ "build.zig", "\u{e6a9}" },
	.{ "build.zig.zon", "\u{e6a9}" },
	.{ "Cargo.toml", "\u{e7a8}" },
	.{ "Cargo.lock", "\u{e7a8}" },
	.{ "package.json", "\u{e718}" },
	.{ "package-lock.json", "\u{e718}" },
	.{ "tsconfig.json", "\u{e628}" },
	.{ "Gemfile", "\u{e739}" },
	.{ "Gemfile.lock", "\u{e739}" },
	.{ "mix.exs", "\u{e62d}" },
	.{ "mix.lock", "\u{e62d}" },
	.{ "go.mod", "\u{e626}" },
	.{ "go.sum", "\u{e626}" },
});

fn extensionIcon(ext: []const u8) ?[]const u8 {
	return extension_icons.get(ext);
}

fn filenameIcon(name: []const u8) ?[]const u8 {
	return filename_icons.get(name);
}

// Tests

test "getFileIcon: zig file" {
	try std.testing.expectEqualStrings("\u{e6a9}", getFileIcon("main.zig"));
}

test "getFileIcon: unknown extension" {
	try std.testing.expectEqualStrings(file_icon, getFileIcon("unknown.xyz"));
}

test "getFileIcon: special filename" {
	try std.testing.expectEqualStrings("\u{e725}", getFileIcon(".gitignore"));
}

test "getDirIcon: git directory" {
	try std.testing.expectEqualStrings(git_icon, getDirIcon(".git"));
}

test "getDirIcon: regular directory" {
	try std.testing.expectEqualStrings(dir_icon, getDirIcon("src"));
}

test "getExtension: normal file" {
	const ext = getExtension("main.zig");
	try std.testing.expectEqualStrings("zig", ext);
}

test "getExtension: no extension" {
	const ext = getExtension("Makefile");
	try std.testing.expectEqualStrings("", ext);
}

test "getExtension: hidden file no ext" {
	const ext = getExtension(".gitignore");
	try std.testing.expectEqualStrings("", ext);
}

test "getFileIcon: hidden file matched by filename" {
	// .gitignore is matched by filename, not extension
	try std.testing.expectEqualStrings("\u{e725}", getFileIcon(".gitignore"));
}

// ---------------------------------------------------------------------------
// Exhaustive table-driven classifier test over the FULL icon map.
//
// Every row corresponds to a real mapping in extensionIcon / filenameIcon (and
// a handful of negatives + directory cases). `want` is the icon the *mapping*
// intends. Because getFileIcon consults extensionIcon BEFORE filenameIcon, any
// special filename whose trailing extension also matches extensionIcon is
// shadowed: the filename arm is dead code. Where the shadowing extension icon
// happens to equal the intended filename icon, the row still passes (harmless
// dead arm). Where they differ, the row FAILS — surfacing a latent bug. Those
// rows are marked LATENT BUG below and are intentionally kept failing per TDD.
// ---------------------------------------------------------------------------

const IconCase = struct { name: []const u8, want: []const u8 };

test "exhaustive: every extensionIcon mapping" {
	const cases = [_]IconCase{
		// Programming languages
		.{ .name = "a.zig", .want = "\u{e6a9}" },
		.{ .name = "a.rs", .want = "\u{e7a8}" },
		.{ .name = "a.go", .want = "\u{e626}" },
		.{ .name = "a.py", .want = "\u{e73c}" },
		.{ .name = "a.rb", .want = "\u{e739}" },
		.{ .name = "a.js", .want = "\u{e74e}" },
		.{ .name = "a.ts", .want = "\u{e628}" },
		.{ .name = "a.jsx", .want = "\u{e7ba}" },
		.{ .name = "a.tsx", .want = "\u{e7ba}" },
		.{ .name = "a.c", .want = "\u{e61e}" },
		.{ .name = "a.h", .want = "\u{e61e}" },
		.{ .name = "a.cpp", .want = "\u{e61d}" },
		.{ .name = "a.cc", .want = "\u{e61d}" },
		.{ .name = "a.cxx", .want = "\u{e61d}" },
		.{ .name = "a.hpp", .want = "\u{e61d}" },
		.{ .name = "a.hh", .want = "\u{e61d}" },
		.{ .name = "a.hxx", .want = "\u{e61d}" },
		.{ .name = "a.java", .want = "\u{e738}" },
		.{ .name = "a.lua", .want = "\u{e620}" },
		.{ .name = "a.ex", .want = "\u{e62d}" },
		.{ .name = "a.exs", .want = "\u{e62d}" },
		.{ .name = "a.erl", .want = "\u{e7b1}" },
		.{ .name = "a.hrl", .want = "\u{e7b1}" },
		.{ .name = "a.sh", .want = "\u{f489}" },
		.{ .name = "a.bash", .want = "\u{f489}" },
		.{ .name = "a.zsh", .want = "\u{f489}" },
		.{ .name = "a.pl", .want = "\u{e769}" },
		.{ .name = "a.pm", .want = "\u{e769}" },
		.{ .name = "a.swift", .want = "\u{e755}" },
		.{ .name = "a.kt", .want = "\u{e634}" },
		.{ .name = "a.kts", .want = "\u{e634}" },
		.{ .name = "a.scala", .want = "\u{e737}" },
		.{ .name = "a.cs", .want = "\u{f81a}" },
		.{ .name = "a.fs", .want = "\u{e7a7}" },
		.{ .name = "a.fsx", .want = "\u{e7a7}" },
		.{ .name = "a.hs", .want = "\u{e777}" },
		.{ .name = "a.clj", .want = "\u{e768}" },
		.{ .name = "a.cljs", .want = "\u{e768}" },
		.{ .name = "a.r", .want = "\u{f25d}" },
		.{ .name = "a.R", .want = "\u{f25d}" },
		.{ .name = "a.dart", .want = "\u{e798}" },
		.{ .name = "a.nim", .want = "\u{e677}" },
		.{ .name = "a.v", .want = "\u{e6ac}" },
		.{ .name = "a.asm", .want = "\u{f471}" },
		.{ .name = "a.s", .want = "\u{f471}" },
		.{ .name = "a.S", .want = "\u{f471}" },
		.{ .name = "a.wasm", .want = "\u{e6a1}" },
		// Web
		.{ .name = "a.html", .want = "\u{e736}" },
		.{ .name = "a.htm", .want = "\u{e736}" },
		.{ .name = "a.css", .want = "\u{e749}" },
		.{ .name = "a.scss", .want = "\u{e749}" },
		.{ .name = "a.sass", .want = "\u{e749}" },
		.{ .name = "a.less", .want = "\u{e749}" },
		.{ .name = "a.vue", .want = "\u{e6a0}" },
		.{ .name = "a.svelte", .want = "\u{e697}" },
		// Data / config
		.{ .name = "a.json", .want = "\u{e60b}" },
		.{ .name = "a.yaml", .want = "\u{e6a8}" },
		.{ .name = "a.yml", .want = "\u{e6a8}" },
		.{ .name = "a.toml", .want = "\u{e6b2}" },
		.{ .name = "a.xml", .want = "\u{e619}" },
		.{ .name = "a.csv", .want = "\u{f1c3}" },
		.{ .name = "a.sql", .want = "\u{e706}" },
		.{ .name = "a.graphql", .want = "\u{e662}" },
		.{ .name = "a.gql", .want = "\u{e662}" },
		.{ .name = "a.ini", .want = "\u{e615}" },
		.{ .name = "a.cfg", .want = "\u{e615}" },
		.{ .name = "a.conf", .want = "\u{e615}" },
		// Documentation
		.{ .name = "a.md", .want = "\u{e73e}" },
		.{ .name = "a.markdown", .want = "\u{e73e}" },
		.{ .name = "a.txt", .want = "\u{f0f6}" },
		.{ .name = "a.pdf", .want = "\u{f1c1}" },
		.{ .name = "a.doc", .want = "\u{f1c2}" },
		.{ .name = "a.docx", .want = "\u{f1c2}" },
		.{ .name = "a.xls", .want = "\u{f1c3}" },
		.{ .name = "a.xlsx", .want = "\u{f1c3}" },
		.{ .name = "a.ppt", .want = "\u{f1c4}" },
		.{ .name = "a.pptx", .want = "\u{f1c4}" },
		.{ .name = "a.tex", .want = "\u{e69b}" },
		.{ .name = "a.latex", .want = "\u{e69b}" },
		.{ .name = "a.org", .want = "\u{e633}" },
		.{ .name = "a.rst", .want = "\u{f0f6}" },
		// Images
		.{ .name = "a.png", .want = "\u{f1c5}" },
		.{ .name = "a.jpg", .want = "\u{f1c5}" },
		.{ .name = "a.jpeg", .want = "\u{f1c5}" },
		.{ .name = "a.gif", .want = "\u{f1c5}" },
		.{ .name = "a.bmp", .want = "\u{f1c5}" },
		.{ .name = "a.ico", .want = "\u{f1c5}" },
		.{ .name = "a.svg", .want = "\u{f1c5}" },
		.{ .name = "a.webp", .want = "\u{f1c5}" },
		.{ .name = "a.tiff", .want = "\u{f1c5}" },
		.{ .name = "a.heic", .want = "\u{f1c5}" },
		.{ .name = "a.heif", .want = "\u{f1c5}" },
		.{ .name = "a.avif", .want = "\u{f1c5}" },
		// Audio
		.{ .name = "a.mp3", .want = "\u{f1c7}" },
		.{ .name = "a.wav", .want = "\u{f1c7}" },
		.{ .name = "a.flac", .want = "\u{f1c7}" },
		.{ .name = "a.ogg", .want = "\u{f1c7}" },
		.{ .name = "a.aac", .want = "\u{f1c7}" },
		.{ .name = "a.m4a", .want = "\u{f1c7}" },
		.{ .name = "a.wma", .want = "\u{f1c7}" },
		// Video
		.{ .name = "a.mp4", .want = "\u{f1c8}" },
		.{ .name = "a.mkv", .want = "\u{f1c8}" },
		.{ .name = "a.avi", .want = "\u{f1c8}" },
		.{ .name = "a.mov", .want = "\u{f1c8}" },
		.{ .name = "a.wmv", .want = "\u{f1c8}" },
		.{ .name = "a.webm", .want = "\u{f1c8}" },
		.{ .name = "a.flv", .want = "\u{f1c8}" },
		// Archives
		.{ .name = "a.zip", .want = "\u{f1c6}" },
		.{ .name = "a.tar", .want = "\u{f1c6}" },
		.{ .name = "a.gz", .want = "\u{f1c6}" },
		.{ .name = "a.bz2", .want = "\u{f1c6}" },
		.{ .name = "a.xz", .want = "\u{f1c6}" },
		.{ .name = "a.7z", .want = "\u{f1c6}" },
		.{ .name = "a.rar", .want = "\u{f1c6}" },
		.{ .name = "a.zst", .want = "\u{f1c6}" },
		// Build / DevOps
		.{ .name = "a.nix", .want = "\u{f313}" },
		.{ .name = "a.dockerfile", .want = "\u{f308}" },
		.{ .name = "a.docker", .want = "\u{f308}" },
		.{ .name = "a.lock", .want = "\u{f023}" },
		.{ .name = "a.log", .want = "\u{f18d}" },
		.{ .name = "a.env", .want = "\u{f462}" },
		.{ .name = "a.zon", .want = "\u{e6a9}" },
	};
	for (cases) |c| {
		std.testing.expectEqualStrings(c.want, getFileIcon(c.name)) catch |err| {
			std.debug.print("FAILED extension row: name='{s}'\n", .{c.name});
			return err;
		};
	}
}

test "exhaustive: every filenameIcon mapping (intended semantics)" {
	const cases = [_]IconCase{
		// Reachable (no matching trailing extension)
		.{ .name = "Makefile", .want = "\u{e615}" },
		.{ .name = "makefile", .want = "\u{e615}" },
		.{ .name = "Dockerfile", .want = "\u{f308}" },
		.{ .name = "LICENSE", .want = "\u{f0e3}" },
		.{ .name = "LICENCE", .want = "\u{f0e3}" },
		.{ .name = "README", .want = "\u{e73e}" },
		.{ .name = ".gitignore", .want = "\u{e725}" },
		.{ .name = ".gitmodules", .want = "\u{e725}" },
		.{ .name = ".envrc", .want = "\u{f462}" },
		.{ .name = "Gemfile", .want = "\u{e739}" },
		.{ .name = "go.mod", .want = "\u{e626}" },
		.{ .name = "go.sum", .want = "\u{e626}" },
		// Shadowed-but-harmless (extension icon == intended filename icon)
		.{ .name = "README.md", .want = "\u{e73e}" },
		.{ .name = "flake.nix", .want = "\u{f313}" },
		.{ .name = "build.zig", .want = "\u{e6a9}" },
		.{ .name = "build.zig.zon", .want = "\u{e6a9}" },
		.{ .name = "mix.exs", .want = "\u{e62d}" },
		// Shadowed AND divergent => LATENT BUG (kept failing; see report)
		.{ .name = "Cargo.toml", .want = "\u{e7a8}" }, // gets toml \u{e6b2}
		.{ .name = "Cargo.lock", .want = "\u{e7a8}" }, // gets lock \u{f023}
		.{ .name = "package.json", .want = "\u{e718}" }, // gets json \u{e60b}
		.{ .name = "package-lock.json", .want = "\u{e718}" }, // gets json \u{e60b}
		.{ .name = "tsconfig.json", .want = "\u{e628}" }, // gets json \u{e60b}
		.{ .name = "Gemfile.lock", .want = "\u{e739}" }, // gets lock \u{f023}
		.{ .name = "mix.lock", .want = "\u{e62d}" }, // gets lock \u{f023}
		.{ .name = "flake.lock", .want = "\u{f313}" }, // gets lock \u{f023}
	};
	for (cases) |c| {
		std.testing.expectEqualStrings(c.want, getFileIcon(c.name)) catch |err| {
			std.debug.print("FAILED filename row: name='{s}' (extensionIcon shadows filenameIcon?)\n", .{c.name});
			return err;
		};
	}
}

test "exhaustive: negative set falls back to default file icon" {
	const negatives = [_][]const u8{
		"weird.xyz",   "a.qqq",   "noext",
		"a.unknownext", ".dotonly", "data.frobnicate",
		"a.123",       "Cakefile",
	};
	for (negatives) |n| {
		std.testing.expectEqualStrings(file_icon, getFileIcon(n)) catch |err| {
			std.debug.print("FAILED negative row: name='{s}'\n", .{n});
			return err;
		};
	}
}

test "exhaustive: directory icon cases" {
	try std.testing.expectEqualStrings(git_icon, getDirIcon(".git"));
	try std.testing.expectEqualStrings(git_icon, getDirIcon(".github"));
	try std.testing.expectEqualStrings(node_modules_icon, getDirIcon("node_modules"));
	try std.testing.expectEqualStrings(dir_icon, getDirIcon("src"));
	try std.testing.expectEqualStrings(dir_icon, getDirIcon("anything_else"));
}
