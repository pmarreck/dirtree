//! Embedded Nerd Font for the HTML output adapter.
//!
//! `data_uri` is a complete CSS `@font-face` `src` value
//! (`url(data:font/woff2;base64,...) format("woff2")`) for the Nerd Font icon
//! glyphs, so the single-file HTML output renders icons with no external font.
//!
//! The embedded font is a SUBSET of the MIT-licensed Symbols Nerd Font (Mono)
//! containing only the glyphs `src/icons.zig` uses (~12.7 KB woff2). It is
//! committed at `assets/symbols-nerd-font-subset.woff2` and base64-encoded here
//! at comptime, so the build needs no font tooling and stays reproducible.
//! Regenerate the asset with `scripts/gen_html_font_subset.sh` when the icon set
//! changes. License/attribution: see `assets/NOTICE-nerd-font.md`.

const std = @import("std");

/// The raw subset woff2, embedded at compile time.
const woff2 = @embedFile("assets/symbols-nerd-font-subset.woff2");

/// Base64 of the woff2, computed at comptime (no runtime allocation).
const woff2_b64 = blk: {
	@setEvalBranchQuota(200000);
	const enc = std.base64.standard.Encoder;
	var buf: [enc.calcSize(woff2.len)]u8 = undefined;
	_ = enc.encode(&buf, woff2);
	const final = buf;
	break :blk final;
};

/// Complete `@font-face` `src` value with the embedded font inline.
pub const data_uri: ?[]const u8 =
	"url(data:font/woff2;base64," ++ &woff2_b64 ++ ") format(\"woff2\")";

test "data_uri is a well-formed woff2 data-URI whose payload decodes to a woff2" {
	const uri = data_uri.?;
	try std.testing.expect(std.mem.startsWith(u8, uri, "url(data:font/woff2;base64,"));
	try std.testing.expect(std.mem.endsWith(u8, uri, ") format(\"woff2\")"));

	// Extract and decode the base64 payload; it must begin with the woff2 magic.
	const head = "url(data:font/woff2;base64,";
	const tail = ") format(\"woff2\")";
	const b64 = uri[head.len .. uri.len - tail.len];
	const dec = std.base64.standard.Decoder;
	const n = try dec.calcSizeForSlice(b64);
	const out = try std.testing.allocator.alloc(u8, n);
	defer std.testing.allocator.free(out);
	try dec.decode(out, b64);
	try std.testing.expect(std.mem.eql(u8, out[0..4], "wOF2"));
}
