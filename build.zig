const std = @import("std");

pub fn build(b: *std.Build) void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.option(std.builtin.OptimizeMode, "optimize", "Optimization mode (default: ReleaseFast)") orelse .ReleaseFast;

	// Parse version out of build.zig.zon so the binary can report it
	const version = blk: {
		const zon = @embedFile("build.zig.zon");
		const marker = ".version = \"";
		const start = std.mem.indexOf(u8, zon, marker) orelse @panic("missing .version in build.zig.zon");
		const after = start + marker.len;
		const end = std.mem.indexOfScalarPos(u8, zon, after, '"') orelse @panic("malformed .version in build.zig.zon");
		break :blk zon[after..end];
	};

	const build_options = b.addOptions();
	build_options.addOption([]const u8, "version", version);

	// Get the PCRE2 dependency (C library, statically linked)
	const pcre2_dep = b.dependency("pcre2", .{
		.target = target,
		.optimize = optimize,
		.linkage = .static,
		.@"code-unit-width" = .@"8",
	});
	const pcre2_lib = pcre2_dep.artifact("pcre2-8");

	// Main executable
	const exe = b.addExecutable(.{
		.name = "dirtree",
		.root_module = b.createModule(.{
			.root_source_file = b.path("src/main.zig"),
			.target = target,
			.optimize = optimize,
		}),
	});
	exe.root_module.addIncludePath(pcre2_lib.getEmittedIncludeTree());
	exe.root_module.linkLibrary(pcre2_lib);
	exe.root_module.link_libc = true;
	exe.root_module.addOptions("build_options", build_options);

	b.installArtifact(exe);

	// Run step
	const run_cmd = b.addRunArtifact(exe);
	run_cmd.step.dependOn(b.getInstallStep());
	if (b.args) |args| {
		run_cmd.addArgs(args);
	}
	const run_step = b.step("run", "Run dirtree");
	run_step.dependOn(&run_cmd.step);

	// Unit tests
	const unit_tests = b.addTest(.{
		.root_module = b.createModule(.{
			.root_source_file = b.path("src/main.zig"),
			.target = target,
			.optimize = optimize,
		}),
	});
	unit_tests.root_module.addIncludePath(pcre2_lib.getEmittedIncludeTree());
	unit_tests.root_module.linkLibrary(pcre2_lib);
	unit_tests.root_module.link_libc = true;
	unit_tests.root_module.addOptions("build_options", build_options);
	const run_unit_tests = b.addRunArtifact(unit_tests);
	const test_step = b.step("test", "Run unit tests");
	test_step.dependOn(&run_unit_tests.step);
}
