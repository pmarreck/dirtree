//! A streaming std.Io.Writer wrapper that buffers output only up to a line
//! threshold, then (if the threshold is crossed) emits a precomputed warning to a
//! side channel, flushes what it buffered, and streams the remainder directly.
//!
//! Why: dirtree's "large output" warning must appear BEFORE the bulk of a big
//! tree when piped, which historically meant a second whole-tree walk just to
//! estimate the line count. This wrapper lets a SINGLE render produce the warning
//! with bounded memory (only ~threshold lines are ever buffered) while preserving
//! streaming for everything past the threshold. Replaces the count-then-render
//! double directory scan on the piped path.
const std = @import("std");

pub const ThresholdStreamWriter = struct {
	writer: std.Io.Writer,
	real: *std.Io.Writer, // the true sink (stdout)
	side: *std.Io.Writer, // where the warning goes (stderr)
	warning: []const u8, // precomputed warning bytes (incl. ANSI + newlines)
	threshold: usize, // emit the warning once buffered newline count exceeds this
	gpa: std.mem.Allocator,
	lines: usize = 0,
	streaming: bool = false, // true once the threshold was crossed (or never buffering)
	pending: std.ArrayListUnmanaged(u8) = .empty,
	warned: bool = false,

	pub fn init(
		gpa: std.mem.Allocator,
		buffer: []u8,
		real: *std.Io.Writer,
		side: *std.Io.Writer,
		warning: []const u8,
		threshold: usize,
	) ThresholdStreamWriter {
		return .{
			.writer = .{ .vtable = &.{ .drain = drain }, .buffer = buffer },
			.real = real,
			.side = side,
			.warning = warning,
			.threshold = threshold,
			.gpa = gpa,
		};
	}

	/// Route bytes: stream straight through once crossed, otherwise accumulate and
	/// count newlines; on crossing, warn → flush buffered → switch to streaming.
	fn feed(self: *ThresholdStreamWriter, bytes: []const u8) std.Io.Writer.Error!void {
		if (self.streaming) {
			try self.real.writeAll(bytes);
			return;
		}
		self.pending.appendSlice(self.gpa, bytes) catch return error.WriteFailed;
		for (bytes) |b| {
			if (b == '\n') self.lines += 1;
		}
		if (self.lines > self.threshold) {
			try self.side.writeAll(self.warning);
			self.warned = true;
			try self.real.writeAll(self.pending.items);
			self.pending.clearAndFree(self.gpa);
			self.streaming = true;
		}
	}

	fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
		const self: *ThresholdStreamWriter = @alignCast(@fieldParentPtr("writer", w));
		if (w.end > 0) {
			try self.feed(w.buffer[0..w.end]);
			w.end = 0;
		}
		const slices = data[0 .. data.len - 1];
		const pattern = data[data.len - 1];
		var consumed: usize = 0;
		for (slices) |s| {
			try self.feed(s);
			consumed += s.len;
		}
		var k: usize = 0;
		while (k < splat) : (k += 1) try self.feed(pattern);
		consumed += pattern.len * splat;
		return consumed;
	}

	/// Flush the interface buffer, then (if we never crossed the threshold) write
	/// the buffered-but-unflushed output, and finally flush the real sink.
	pub fn finish(self: *ThresholdStreamWriter) std.Io.Writer.Error!void {
		try self.writer.flush();
		if (!self.streaming) {
			try self.real.writeAll(self.pending.items);
			self.pending.clearAndFree(self.gpa);
		}
		try self.real.flush();
	}

	pub fn deinit(self: *ThresholdStreamWriter) void {
		self.pending.deinit(self.gpa);
	}
};

test "ThresholdStreamWriter: under threshold buffers, no warning, flushes on finish" {
	const A = std.testing.allocator;
	var out: std.Io.Writer.Allocating = .init(A);
	defer out.deinit();
	var sidebuf: [64]u8 = undefined;
	var side: std.Io.Writer.Allocating = .init(A);
	defer side.deinit();
	_ = &sidebuf;

	var buf: [8]u8 = undefined;
	var tw = ThresholdStreamWriter.init(A, &buf, &out.writer, &side.writer, "WARN\n", 5);
	defer tw.deinit();

	// 3 lines, threshold 5 => no warning.
	try tw.writer.writeAll("a\nb\nc\n");
	try tw.finish();

	try std.testing.expectEqualStrings("a\nb\nc\n", out.written());
	try std.testing.expectEqualStrings("", side.written());
	try std.testing.expect(!tw.warned);
}

test "ThresholdStreamWriter: over threshold warns once then streams" {
	const A = std.testing.allocator;
	var out: std.Io.Writer.Allocating = .init(A);
	defer out.deinit();
	var side: std.Io.Writer.Allocating = .init(A);
	defer side.deinit();

	var buf: [4]u8 = undefined;
	var tw = ThresholdStreamWriter.init(A, &buf, &out.writer, &side.writer, "WARN\n", 3);
	defer tw.deinit();

	// 6 lines, threshold 3 => warning fires once; all content still reaches stdout.
	try tw.writer.writeAll("1\n2\n3\n4\n5\n6\n");
	try tw.finish();

	try std.testing.expectEqualStrings("1\n2\n3\n4\n5\n6\n", out.written());
	try std.testing.expectEqualStrings("WARN\n", side.written());
	try std.testing.expect(tw.warned);
}
