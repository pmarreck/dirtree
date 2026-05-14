//! Process-wide runtime context for Zig 0.16 migration.
//!
//! Zig 0.16 threaded `std.Io` and the environment map as explicit parameters
//! through most filesystem/process APIs. Rather than refactor every function
//! signature in dirtree, we capture the values once in `main` and expose them
//! as process-globals that other modules read directly.
//!
//! Initialised by `main()`; safe to read for the lifetime of the process.
//! During tests (where `main` does not run), `io()` lazily falls back to
//! `std.testing.io` and `getEnv` returns null.

const std = @import("std");
const builtin = @import("builtin");

var g_io: std.Io = undefined;
var g_env: ?*const std.process.Environ.Map = null;
var g_initialised: bool = false;

pub fn init(io_val: std.Io, env_val: *const std.process.Environ.Map) void {
    g_io = io_val;
    g_env = env_val;
    g_initialised = true;
}

pub fn io() std.Io {
    if (!g_initialised) {
        if (builtin.is_test) {
            return std.testing.io;
        }
        std.debug.panic("runtime.io() called before runtime.init()", .{});
    }
    return g_io;
}

pub fn env() *const std.process.Environ.Map {
    std.debug.assert(g_initialised);
    return g_env.?;
}

/// Convenience: look up an env var (returns null if not present or unset).
pub fn getEnv(name: []const u8) ?[]const u8 {
    if (!g_initialised) return null;
    if (g_env) |m| return m.get(name);
    return null;
}
