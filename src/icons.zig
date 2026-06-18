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

fn extensionIcon(ext: []const u8) ?[]const u8 {
	// Programming languages
	if (eql(ext, "zig")) return "\u{e6a9}"; //
	if (eql(ext, "rs")) return "\u{e7a8}"; //
	if (eql(ext, "go")) return "\u{e626}"; //
	if (eql(ext, "py")) return "\u{e73c}"; //
	if (eql(ext, "rb")) return "\u{e739}"; //
	if (eql(ext, "js")) return "\u{e74e}"; //
	if (eql(ext, "ts")) return "\u{e628}"; //
	if (eql(ext, "jsx")) return "\u{e7ba}"; //
	if (eql(ext, "tsx")) return "\u{e7ba}"; //
	if (eql(ext, "c")) return "\u{e61e}"; //
	if (eql(ext, "h")) return "\u{e61e}"; //
	if (eql(ext, "cpp") or eql(ext, "cc") or eql(ext, "cxx")) return "\u{e61d}"; //
	if (eql(ext, "hpp") or eql(ext, "hh") or eql(ext, "hxx")) return "\u{e61d}"; //
	if (eql(ext, "java")) return "\u{e738}"; //
	if (eql(ext, "lua")) return "\u{e620}"; //
	if (eql(ext, "ex") or eql(ext, "exs")) return "\u{e62d}"; //
	if (eql(ext, "erl") or eql(ext, "hrl")) return "\u{e7b1}"; //
	if (eql(ext, "sh") or eql(ext, "bash") or eql(ext, "zsh")) return "\u{f489}"; //
	if (eql(ext, "pl") or eql(ext, "pm")) return "\u{e769}"; //
	if (eql(ext, "swift")) return "\u{e755}"; //
	if (eql(ext, "kt") or eql(ext, "kts")) return "\u{e634}"; //
	if (eql(ext, "scala")) return "\u{e737}"; //
	if (eql(ext, "cs")) return "\u{f81a}"; //
	if (eql(ext, "fs") or eql(ext, "fsx")) return "\u{e7a7}"; //
	if (eql(ext, "hs")) return "\u{e777}"; //
	if (eql(ext, "clj") or eql(ext, "cljs")) return "\u{e768}"; //
	if (eql(ext, "r") or eql(ext, "R")) return "\u{f25d}"; //
	if (eql(ext, "dart")) return "\u{e798}"; //
	if (eql(ext, "nim")) return "\u{e677}"; //
	if (eql(ext, "v")) return "\u{e6ac}"; //
	if (eql(ext, "asm") or eql(ext, "s") or eql(ext, "S")) return "\u{f471}"; //
	if (eql(ext, "wasm")) return "\u{e6a1}"; //

	// Web
	if (eql(ext, "html") or eql(ext, "htm")) return "\u{e736}"; //
	if (eql(ext, "css")) return "\u{e749}"; //
	if (eql(ext, "scss") or eql(ext, "sass")) return "\u{e749}"; //
	if (eql(ext, "less")) return "\u{e749}"; //
	if (eql(ext, "vue")) return "\u{e6a0}"; //
	if (eql(ext, "svelte")) return "\u{e697}"; //

	// Data / config
	if (eql(ext, "json")) return "\u{e60b}"; //
	if (eql(ext, "yaml") or eql(ext, "yml")) return "\u{e6a8}"; //
	if (eql(ext, "toml")) return "\u{e6b2}"; //
	if (eql(ext, "xml")) return "\u{e619}"; //
	if (eql(ext, "csv")) return "\u{f1c3}"; //
	if (eql(ext, "sql")) return "\u{e706}"; //
	if (eql(ext, "graphql") or eql(ext, "gql")) return "\u{e662}"; //
	if (eql(ext, "ini") or eql(ext, "cfg") or eql(ext, "conf")) return "\u{e615}"; //

	// Documentation
	if (eql(ext, "md") or eql(ext, "markdown")) return "\u{e73e}"; //
	if (eql(ext, "txt")) return "\u{f0f6}"; //
	if (eql(ext, "pdf")) return "\u{f1c1}"; //
	if (eql(ext, "doc") or eql(ext, "docx")) return "\u{f1c2}"; //
	if (eql(ext, "xls") or eql(ext, "xlsx")) return "\u{f1c3}"; //
	if (eql(ext, "ppt") or eql(ext, "pptx")) return "\u{f1c4}"; //
	if (eql(ext, "tex") or eql(ext, "latex")) return "\u{e69b}"; //
	if (eql(ext, "org")) return "\u{e633}"; //
	if (eql(ext, "rst")) return "\u{f0f6}"; //

	// Images
	if (eql(ext, "png") or eql(ext, "jpg") or eql(ext, "jpeg") or
		eql(ext, "gif") or eql(ext, "bmp") or eql(ext, "ico") or
		eql(ext, "svg") or eql(ext, "webp") or eql(ext, "tiff") or
		eql(ext, "heic") or eql(ext, "heif") or eql(ext, "avif")) return "\u{f1c5}"; //

	// Audio/Video
	if (eql(ext, "mp3") or eql(ext, "wav") or eql(ext, "flac") or
		eql(ext, "ogg") or eql(ext, "aac") or eql(ext, "m4a") or
		eql(ext, "wma")) return "\u{f1c7}"; //
	if (eql(ext, "mp4") or eql(ext, "mkv") or eql(ext, "avi") or
		eql(ext, "mov") or eql(ext, "wmv") or eql(ext, "webm") or
		eql(ext, "flv")) return "\u{f1c8}"; //

	// Archives
	if (eql(ext, "zip") or eql(ext, "tar") or eql(ext, "gz") or
		eql(ext, "bz2") or eql(ext, "xz") or eql(ext, "7z") or
		eql(ext, "rar") or eql(ext, "zst")) return "\u{f1c6}"; //

	// Build / DevOps
	if (eql(ext, "nix")) return "\u{f313}"; //
	if (eql(ext, "dockerfile") or eql(ext, "docker")) return "\u{f308}"; //
	if (eql(ext, "lock")) return "\u{f023}"; //
	if (eql(ext, "log")) return "\u{f18d}"; //
	if (eql(ext, "env")) return "\u{f462}"; //
	if (eql(ext, "zon")) return "\u{e6a9}"; // Zig (build.zig.zon)

	return null;
}

fn filenameIcon(name: []const u8) ?[]const u8 {
	if (eql(name, "Makefile") or eql(name, "makefile")) return "\u{e615}"; //
	if (eql(name, "Dockerfile")) return "\u{f308}"; //
	if (eql(name, "LICENSE") or eql(name, "LICENCE")) return "\u{f0e3}"; //
	if (eql(name, "README.md") or eql(name, "README")) return "\u{e73e}"; //
	if (eql(name, ".gitignore")) return "\u{e725}"; //
	if (eql(name, ".gitmodules")) return "\u{e725}"; //
	if (eql(name, ".envrc")) return "\u{f462}"; //
	if (eql(name, "flake.nix")) return "\u{f313}"; //
	if (eql(name, "flake.lock")) return "\u{f313}"; //
	if (eql(name, "build.zig")) return "\u{e6a9}"; //
	if (eql(name, "build.zig.zon")) return "\u{e6a9}"; //
	if (eql(name, "Cargo.toml") or eql(name, "Cargo.lock")) return "\u{e7a8}"; //
	if (eql(name, "package.json") or eql(name, "package-lock.json")) return "\u{e718}"; //
	if (eql(name, "tsconfig.json")) return "\u{e628}"; //
	if (eql(name, "Gemfile") or eql(name, "Gemfile.lock")) return "\u{e739}"; //
	if (eql(name, "mix.exs") or eql(name, "mix.lock")) return "\u{e62d}"; //
	if (eql(name, "go.mod") or eql(name, "go.sum")) return "\u{e626}"; //

	return null;
}

fn eql(a: []const u8, b: []const u8) bool {
	return std.mem.eql(u8, a, b);
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
