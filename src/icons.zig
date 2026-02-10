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
	const ext = getExtension(name);
	if (ext.len > 0) {
		if (extensionIcon(ext)) |icon| return icon;
	}
	// Check special filenames
	if (filenameIcon(name)) |icon| return icon;
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
