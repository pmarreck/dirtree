const std = @import("std");
const icons = @import("icons.zig");

/// Node kind for the in-memory tree the HTML adapter renders.
pub const NodeKind = enum { dir, file, symlink };

/// A pure, in-memory representation of one rendered tree entry. The HTML
/// renderer is a pure function of a tree of these (state + scanned entries are
/// resolved into this shape by an impure builder elsewhere), so the renderer
/// itself does no I/O and is directly unit-testable.
pub const HtmlNode = struct {
	name: []const u8,
	kind: NodeKind,
	/// dir only: <details open> (expanded) vs <details> (collapsed), mapping the
	/// existing open/closed directory state.
	is_open: bool = false,
	is_exec: bool = false,
	note: ?[]const u8 = null,
	/// file:// URL for the entry name link, when hyperlinks are enabled.
	href: ?[]const u8 = null,
	symlink_target: ?[]const u8 = null,
	children: []const HtmlNode = &.{},
};

/// Styling/feature knobs for the HTML renderer. Class names use `class_prefix`
/// so users can restyle without patching the generator (stable hooks like
/// `.dt-dir`, `.dt-file`, `.dt-note`, `.dt-link`).
pub const HtmlConfig = struct {
	use_icons: bool = true,
	show_notes: bool = true,
	use_hyperlinks: bool = true,
	class_prefix: []const u8 = "dt",
	/// Optional `@font-face` source (e.g. a `url(data:font/woff2;base64,...)`
	/// data-URI) for the Nerd Font icon glyphs. When null, icon spans fall back
	/// to the browser's default font (glyphs may render as tofu). Keeping the
	/// single-file packaging means this is embedded inline when present.
	font_data_uri: ?[]const u8 = null,
};

/// Default dark theme. `__P__` is substituted with `config.class_prefix` at
/// render time so the shipped stylesheet always matches the emitted class hooks.
const theme_css =
	\\:root { color-scheme: dark; }
	\\* { box-sizing: border-box; }
	\\body {
	\\  margin: 0; padding: 0;
	\\  background: #1e1e1e; color: #d4d4d4;
	\\  font-family: ui-monospace, "SFMono-Regular", Menlo, Consolas, "Liberation Mono", monospace;
	\\  font-size: 14px; line-height: 1.55;
	\\}
	\\.__P__-tree { padding: 1.25rem 1.5rem; }
	\\.__P__-root { font-size: 1rem; font-weight: 700; color: #4aa3ff; margin: 0 0 .5rem; word-break: break-all; }
	\\details { margin: 0; padding: 0; border: 0; }
	\\details > :not(summary) { margin-left: 1em; border-left: 1px solid #333; }
	\\summary { cursor: pointer; list-style: none; user-select: none; white-space: pre; padding-left: 1.3em; }
	\\summary::-webkit-details-marker { display: none; }
	\\summary::before { content: "\25B8"; display: inline-block; width: 1.3em; margin-left: -1.3em; text-align: center; color: #808080; }
	\\details[open] > summary::before { content: "\25BE"; }
	\\.__P__-file, .__P__-symlink { white-space: pre; padding-left: 1.3em; }
	\\.__P__-dir { color: #4aa3ff; font-weight: 600; }
	\\.__P__-file { color: #d4d4d4; }
	\\.__P__-symlink { color: #3dd0d0; }
	\\.__P__-icon { display: inline-block; width: 1.4em; text-align: center; color: #6f9fd8; }
	\\.__P__-symlink .__P__-icon { color: #3dd0d0; }
	\\.__P__-note { color: #7aa86f; font-style: italic; margin-left: .85em; opacity: .9; font-weight: 400; }
	\\.__P__-link { color: inherit; text-decoration: none; }
	\\.__P__-link:hover { text-decoration: underline; }
	\\.__P__-arrow { color: #808080; }
	\\.__P__-target { color: #3dd0d0; }
;

/// Write `text` to `writer` with HTML special characters escaped, so arbitrary
/// filenames (which may contain `<`, `>`, `&`, `"`, `'`) cannot inject markup.
/// Escapes the five characters relevant to both element text and double-quoted
/// attribute values.
pub fn writeEscaped(writer: anytype, text: []const u8) !void {
	for (text) |c| {
		switch (c) {
			'&' => try writer.writeAll("&amp;"),
			'<' => try writer.writeAll("&lt;"),
			'>' => try writer.writeAll("&gt;"),
			'"' => try writer.writeAll("&quot;"),
			'\'' => try writer.writeAll("&#39;"),
			else => try writer.writeByte(c),
		}
	}
}

/// Render a single node (and its descendants) as an HTML fragment. Pure — writes
/// to `writer`, performs no I/O. Directories become <details>/<details open>;
/// files and symlinks become leaf rows.
pub fn renderNode(writer: anytype, node: HtmlNode, config: HtmlConfig) !void {
	const prefix = config.class_prefix;
	switch (node.kind) {
		.dir => {
			try writer.writeAll(if (node.is_open) "<details open>" else "<details>");
			try writer.print("<summary class=\"{s}-dir\">", .{prefix});
			try writeIcon(writer, node, config);
			try writeName(writer, node, config);
			try writeNote(writer, node, config);
			try writer.writeAll("</summary>");
			for (node.children) |child| {
				try renderNode(writer, child, config);
			}
			try writer.writeAll("</details>");
		},
		.file, .symlink => {
			const kind_class = if (node.kind == .symlink) "symlink" else "file";
			try writer.print("<div class=\"{s}-{s}\">", .{ prefix, kind_class });
			try writeIcon(writer, node, config);
			try writeName(writer, node, config);
			if (node.kind == .symlink) {
				if (node.symlink_target) |target| {
					try writer.print("<span class=\"{s}-arrow\"> \u{2192} </span><span class=\"{s}-target\">", .{ prefix, prefix });
					try writeEscaped(writer, target);
					try writer.writeAll("</span>");
				}
			}
			try writeNote(writer, node, config);
			try writer.writeAll("</div>");
		},
	}
}

/// Write the entry's Nerd Font icon glyph in a `<prefix>-icon` span when icons
/// are enabled. Reuses the same icon-selection logic as the terminal renderer
/// (`icons.zig`); the glyph is a private-use codepoint styled via the embedded
/// @font-face in the document head.
fn writeIcon(writer: anytype, node: HtmlNode, config: HtmlConfig) !void {
	if (!config.use_icons) return;
	const glyph = switch (node.kind) {
		.dir => icons.getDirIcon(node.name),
		.symlink => icons.symlink_icon,
		.file => if (node.is_exec) icons.exec_icon else icons.getFileIcon(node.name),
	};
	try writer.print("<span class=\"{s}-icon\">", .{config.class_prefix});
	try writeEscaped(writer, glyph);
	try writer.writeAll("</span>");
}

/// Write the entry's display name, wrapping it in a `<a class="<prefix>-link">`
/// anchor when hyperlinks are enabled and the node carries an href. Name and
/// href are both HTML-escaped.
fn writeName(writer: anytype, node: HtmlNode, config: HtmlConfig) !void {
	const linked = config.use_hyperlinks and node.href != null;
	if (linked) {
		try writer.print("<a class=\"{s}-link\" href=\"", .{config.class_prefix});
		try writeEscaped(writer, node.href.?);
		try writer.writeAll("\">");
	}
	try writeEscaped(writer, node.name);
	if (linked) try writer.writeAll("</a>");
}

/// Write the entry's annotation as a dim `<prefix>-note` span when notes are
/// enabled and present. The note text is HTML-escaped.
fn writeNote(writer: anytype, node: HtmlNode, config: HtmlConfig) !void {
	if (!config.show_notes) return;
	const note = node.note orelse return;
	try writer.print("<span class=\"{s}-note\">", .{config.class_prefix});
	try writeEscaped(writer, note);
	try writer.writeAll("</span>");
}

/// Emit the default dark theme, substituting `__P__` placeholders with the
/// configured class prefix so the stylesheet matches the emitted hooks.
fn writeThemeCss(writer: anytype, prefix: []const u8) !void {
	var it = std.mem.splitSequence(u8, theme_css, "__P__");
	var first = true;
	while (it.next()) |seg| {
		if (!first) try writer.writeAll(prefix);
		try writer.writeAll(seg);
		first = false;
	}
}

/// Render a complete, self-contained HTML document for a scanned tree. Pure —
/// writes to `writer`, no I/O. `title` is the display path shown as the heading
/// and document title; `root_nodes` are the top-level entries under it. Inlines
/// the dark theme (and the embedded Nerd Font when `config.font_data_uri` is
/// set) so the output is a single shareable `.html` file.
pub fn htmlRender(writer: anytype, title: []const u8, root_nodes: []const HtmlNode, config: HtmlConfig) !void {
	try writer.writeAll("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n");
	try writer.writeAll("<meta charset=\"utf-8\">\n");
	try writer.writeAll("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n");
	try writer.writeAll("<title>");
	try writeEscaped(writer, title);
	try writer.writeAll("</title>\n<style>\n");
	if (config.font_data_uri) |src| {
		try writer.writeAll("@font-face { font-family: \"dt-nerd\"; font-display: swap; src: ");
		try writer.writeAll(src);
		try writer.writeAll("; }\n");
		try writer.print(".{s}-icon {{ font-family: \"dt-nerd\", monospace; }}\n", .{config.class_prefix});
	}
	try writeThemeCss(writer, config.class_prefix);
	try writer.writeAll("\n</style>\n</head>\n<body>\n");
	try writer.print("<main class=\"{s}-tree\">\n", .{config.class_prefix});
	try writer.print("<h1 class=\"{s}-root\">", .{config.class_prefix});
	try writeEscaped(writer, title);
	try writer.writeAll("/</h1>\n");
	for (root_nodes) |node| {
		try renderNode(writer, node, config);
		try writer.writeAll("\n");
	}
	try writer.writeAll("</main>\n</body>\n</html>\n");
}

test "renderNode: icons emit a dt-icon span, toggleable" {
	var buf: [512]u8 = undefined;
	{
		var fbs = std.Io.Writer.fixed(&buf);
		try renderNode(&fbs, .{ .name = "a.txt", .kind = .file }, .{ .use_icons = true });
		try std.testing.expect(std.mem.indexOf(u8, fbs.buffered(), "dt-icon") != null);
	}
	{
		var fbs = std.Io.Writer.fixed(&buf);
		try renderNode(&fbs, .{ .name = "a.txt", .kind = .file }, .{ .use_icons = false });
		try std.testing.expect(std.mem.indexOf(u8, fbs.buffered(), "dt-icon") == null);
	}
}

test "renderNode: symlink shows its target, escaped" {
	var buf: [512]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	try renderNode(&fbs, .{ .name = "link", .kind = .symlink, .symlink_target = "../a&b" }, .{});
	const out = fbs.buffered();
	try std.testing.expect(std.mem.indexOf(u8, out, "-&gt;") != null or std.mem.indexOf(u8, out, "→") != null);
	try std.testing.expect(std.mem.indexOf(u8, out, "../a&amp;b") != null);
}

test "renderNode: notes render in a dt-note element, escaped, toggleable" {
	var buf: [512]u8 = undefined;
	// show_notes on: dt-note element with escaped text
	{
		var fbs = std.Io.Writer.fixed(&buf);
		try renderNode(&fbs, .{ .name = "a.txt", .kind = .file, .note = "tom & jerry" }, .{ .show_notes = true });
		const out = fbs.buffered();
		try std.testing.expect(std.mem.indexOf(u8, out, "dt-note") != null);
		try std.testing.expect(std.mem.indexOf(u8, out, "tom &amp; jerry") != null);
	}
	// show_notes off: no note rendered
	{
		var fbs = std.Io.Writer.fixed(&buf);
		try renderNode(&fbs, .{ .name = "a.txt", .kind = .file, .note = "secret" }, .{ .show_notes = false });
		try std.testing.expect(std.mem.indexOf(u8, fbs.buffered(), "secret") == null);
	}
}

test "renderNode: href wraps the name in a dt-link anchor, escaped, toggleable" {
	var buf: [512]u8 = undefined;
	// hyperlinks on: anchor with dt-link class + escaped href
	{
		var fbs = std.Io.Writer.fixed(&buf);
		try renderNode(&fbs, .{ .name = "a.txt", .kind = .file, .href = "file:///t/a&b.txt" }, .{ .use_hyperlinks = true });
		const out = fbs.buffered();
		try std.testing.expect(std.mem.indexOf(u8, out, "<a ") != null);
		try std.testing.expect(std.mem.indexOf(u8, out, "dt-link") != null);
		try std.testing.expect(std.mem.indexOf(u8, out, "href=\"file:///t/a&amp;b.txt\"") != null);
		try std.testing.expect(std.mem.indexOf(u8, out, "</a>") != null);
	}
	// hyperlinks off: no anchor even when href present
	{
		var fbs = std.Io.Writer.fixed(&buf);
		try renderNode(&fbs, .{ .name = "a.txt", .kind = .file, .href = "file:///t/a.txt" }, .{ .use_hyperlinks = false });
		try std.testing.expect(std.mem.indexOf(u8, fbs.buffered(), "<a ") == null);
	}
}

test "renderNode: kind-specific class hooks honor the prefix" {
	var buf: [512]u8 = undefined;
	// default prefix "dt"
	{
		var fbs = std.Io.Writer.fixed(&buf);
		try renderNode(&fbs, .{ .name = "src", .kind = .dir }, .{});
		try std.testing.expect(std.mem.indexOf(u8, fbs.buffered(), "dt-dir") != null);
	}
	{
		var fbs = std.Io.Writer.fixed(&buf);
		try renderNode(&fbs, .{ .name = "a.txt", .kind = .file }, .{});
		try std.testing.expect(std.mem.indexOf(u8, fbs.buffered(), "dt-file") != null);
	}
	{
		var fbs = std.Io.Writer.fixed(&buf);
		try renderNode(&fbs, .{ .name = "link", .kind = .symlink }, .{});
		try std.testing.expect(std.mem.indexOf(u8, fbs.buffered(), "dt-symlink") != null);
	}
	// custom prefix overrides the hook namespace
	{
		var fbs = std.Io.Writer.fixed(&buf);
		try renderNode(&fbs, .{ .name = "src", .kind = .dir }, .{ .class_prefix = "x" });
		const out = fbs.buffered();
		try std.testing.expect(std.mem.indexOf(u8, out, "x-dir") != null);
		try std.testing.expect(std.mem.indexOf(u8, out, "dt-dir") == null);
	}
}

test "renderNode: entry names are HTML-escaped (no injection)" {
	var buf: [512]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	try renderNode(&fbs, .{ .name = "<script>&\"x\"", .kind = .file }, .{});
	const out = fbs.buffered();
	// The raw, dangerous form must never appear verbatim
	try std.testing.expect(std.mem.indexOf(u8, out, "<script>") == null);
	// Escaped entities must be present
	try std.testing.expect(std.mem.indexOf(u8, out, "&lt;script&gt;") != null);
	try std.testing.expect(std.mem.indexOf(u8, out, "&amp;") != null);
	try std.testing.expect(std.mem.indexOf(u8, out, "&quot;") != null);
}

test "renderNode: directory wraps name in <summary> and nests children, then closes" {
	var buf: [1024]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	const child = HtmlNode{ .name = "a.txt", .kind = .file };
	try renderNode(&fbs, .{ .name = "src", .kind = .dir, .is_open = true, .children = &.{child} }, .{});
	const out = fbs.buffered();

	const summary_start = std.mem.indexOf(u8, out, "<summary").?;
	const summary_end = std.mem.indexOf(u8, out, "</summary>").?;
	const name_pos = std.mem.indexOf(u8, out, "src").?;
	const child_pos = std.mem.indexOf(u8, out, "a.txt").?;
	const close_pos = std.mem.indexOf(u8, out, "</details>").?;

	// name sits inside the summary; child nests after the summary; details closes last
	try std.testing.expect(summary_start < name_pos);
	try std.testing.expect(name_pos < summary_end);
	try std.testing.expect(summary_end < child_pos);
	try std.testing.expect(child_pos < close_pos);
}

test "htmlRender: locks the approved v1 dark-theme specifics (regression)" {
	// Visual output approved by Peter 2026-06-30 in a browser; these assertions
	// lock the verified appearance so a regression is caught.
	var buf: [8192]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	try htmlRender(&fbs, "/p", &.{}, .{});
	const out = fbs.buffered();
	// dark background + core palette
	try std.testing.expect(std.mem.indexOf(u8, out, "background: #1e1e1e; color: #d4d4d4;") != null);
	try std.testing.expect(std.mem.indexOf(u8, out, ".dt-dir { color: #4aa3ff; font-weight: 600; }") != null);
	try std.testing.expect(std.mem.indexOf(u8, out, ".dt-symlink { color: #3dd0d0; }") != null);
	try std.testing.expect(std.mem.indexOf(u8, out, ".dt-note { color: #7aa86f; font-style: italic;") != null);
	// custom disclosure triangles (▸ collapsed, ▾ open)
	try std.testing.expect(std.mem.indexOf(u8, out, "summary::before { content: \"\\25B8\"; display: inline-block; width: 1.3em; margin-left: -1.3em;") != null);
	try std.testing.expect(std.mem.indexOf(u8, out, "details[open] > summary::before { content: \"\\25BE\"; }") != null);
}

test "htmlRender: embeds the Nerd Font @font-face when a data-URI is supplied" {
	var buf: [4096]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	try htmlRender(&fbs, "/p", &.{}, .{ .font_data_uri = "url(data:font/woff2;base64,AAAA)" });
	const out = fbs.buffered();
	try std.testing.expect(std.mem.indexOf(u8, out, "@font-face") != null);
	try std.testing.expect(std.mem.indexOf(u8, out, "url(data:font/woff2;base64,AAAA)") != null);
	try std.testing.expect(std.mem.indexOf(u8, out, "dt-nerd") != null);
}

test "htmlRender: omits @font-face when no font is supplied" {
	var buf: [4096]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	try htmlRender(&fbs, "/p", &.{}, .{});
	try std.testing.expect(std.mem.indexOf(u8, fbs.buffered(), "@font-face") == null);
}

test "htmlRender: emits a self-contained document wrapping the tree" {
	var buf: [4096]u8 = undefined;
	var fbs = std.Io.Writer.fixed(&buf);
	const nodes = [_]HtmlNode{
		.{ .name = "a.txt", .kind = .file },
		.{ .name = "src", .kind = .dir, .is_open = true, .children = &.{} },
	};
	try htmlRender(&fbs, "/home/<me>/proj", &nodes, .{});
	const out = fbs.buffered();

	try std.testing.expect(std.mem.startsWith(u8, out, "<!DOCTYPE html>"));
	try std.testing.expect(std.mem.indexOf(u8, out, "<meta charset=\"utf-8\">") != null);
	try std.testing.expect(std.mem.indexOf(u8, out, "<style>") != null);
	try std.testing.expect(std.mem.indexOf(u8, out, "</html>") != null);
	// title is escaped (no raw injection)
	try std.testing.expect(std.mem.indexOf(u8, out, "/home/&lt;me&gt;/proj") != null);
	try std.testing.expect(std.mem.indexOf(u8, out, "<me>") == null);
	// the tree content is present
	try std.testing.expect(std.mem.indexOf(u8, out, "a.txt") != null);
	try std.testing.expect(std.mem.indexOf(u8, out, "<details open>") != null);
}

test "renderNode: open directory emits <details open>, closed emits plain <details>" {
	var buf: [256]u8 = undefined;
	{
		var fbs = std.Io.Writer.fixed(&buf);
		try renderNode(&fbs, .{ .name = "src", .kind = .dir, .is_open = true }, .{});
		const out = fbs.buffered();
		try std.testing.expect(std.mem.indexOf(u8, out, "<details open>") != null);
	}
	{
		var fbs = std.Io.Writer.fixed(&buf);
		try renderNode(&fbs, .{ .name = "src", .kind = .dir, .is_open = false }, .{});
		const out = fbs.buffered();
		try std.testing.expect(std.mem.indexOf(u8, out, "<details>") != null);
		try std.testing.expect(std.mem.indexOf(u8, out, "<details open>") == null);
	}
}
