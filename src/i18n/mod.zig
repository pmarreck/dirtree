const std = @import("std");
pub const Strings = @import("strings.zig").Strings;
pub const CliArg = @import("cli_aliases.zig").CliArg;
pub const EnvVar = @import("cli_aliases.zig").EnvVar;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

// ── Locale imports ────────────────────────────────────────────────
const ar = @import("ar.zig");
const az = @import("az.zig");
const de = @import("de.zig");
const el = @import("el.zig");
const en = @import("en.zig");
const es = @import("es.zig");
const fa = @import("fa.zig");
const fr = @import("fr.zig");
const he = @import("he.zig");
const hu = @import("hu.zig");
const it = @import("it.zig");
const ja = @import("ja.zig");
const km = @import("km.zig");
const ko = @import("ko.zig");
const pl = @import("pl.zig");
const pt_br = @import("pt_br.zig");
const ro = @import("ro.zig");
const ru = @import("ru.zig");
const tr_locale = @import("tr.zig");
const uk = @import("uk.zig");
const vi = @import("vi.zig");
const zh_hans = @import("zh_hans.zig");

// ── Locale enum ───────────────────────────────────────────────────
pub const Locale = enum {
    ar,
    az,
    de,
    el,
    en,
    es,
    fa,
    fr,
    he,
    hu,
    it,
    ja,
    km,
    ko,
    pl,
    pt_br,
    ro,
    ru,
    tr,
    uk,
    vi,
    zh_hans,

    pub fn code(self: Locale) [:0]const u8 {
        return switch (self) {
            .ar => "ar",
            .az => "az",
            .de => "de",
            .el => "el",
            .en => "en",
            .es => "es",
            .fa => "fa",
            .fr => "fr",
            .he => "he",
            .hu => "hu",
            .it => "it",
            .ja => "ja",
            .km => "km",
            .ko => "ko",
            .pl => "pl",
            .pt_br => "pt_br",
            .ro => "ro",
            .ru => "ru",
            .tr => "tr",
            .uk => "uk",
            .vi => "vi",
            .zh_hans => "zh_hans",
        };
    }
};

const all_locales = [_]Locale{
    .ar,
    .az,
    .de,
    .el,
    .en,
    .es,
    .fa,
    .fr,
    .he,
    .hu,
    .it,
    .ja,
    .km,
    .ko,
    .pl,
    .pt_br,
    .ro,
    .ru,
    .tr,
    .uk,
    .vi,
    .zh_hans,
};

/// Comma-separated list of all locale codes (for error messages).
/// NOTE: Update this when adding locales (Zig comptime can't build
/// runtime-referencing slices from var buffers for global consts).
pub const available_codes: [:0]const u8 = "ar, az, de, el, en, es, fa, fr, he, hu, it, ja, km, ko, pl, pt_br, ro, ru, tr, uk, vi, zh_hans";

// ── Global state ──────────────────────────────────────────────────
var current_locale: Locale = .en;

pub fn setLocale(loc: Locale) void {
    current_locale = loc;
}

pub fn getLocale() Locale {
    return current_locale;
}

/// Get the Strings for the current locale.
pub fn tr() *const Strings {
    return stringsFor(current_locale);
}

/// Get the Strings for a specific locale.
fn stringsFor(loc: Locale) *const Strings {
    return switch (loc) {
        .ar => &ar.strings,
        .az => &az.strings,
        .de => &de.strings,
        .el => &el.strings,
        .en => &en.strings,
        .es => &es.strings,
        .fa => &fa.strings,
        .fr => &fr.strings,
        .he => &he.strings,
        .hu => &hu.strings,
        .it => &it.strings,
        .ja => &ja.strings,
        .km => &km.strings,
        .ko => &ko.strings,
        .pl => &pl.strings,
        .pt_br => &pt_br.strings,
        .ro => &ro.strings,
        .ru => &ru.strings,
        .tr => &tr_locale.strings,
        .uk => &uk.strings,
        .vi => &vi.strings,
        .zh_hans => &zh_hans.strings,
    };
}

// ── Locale detection ──────────────────────────────────────────────

/// Parse a locale code string (e.g. "de", "de_DE", "de_DE.UTF-8") into a Locale.
/// Returns null if unrecognized.
pub fn parseLocaleCode(code_str: []const u8) ?Locale {
    // Extract the 2-char language prefix
    if (code_str.len < 2) return null;
    const prefix = code_str[0..2];

    inline for (all_locales) |loc| {
        const loc_code = comptime loc.code();
        if (loc_code.len == 2) {
            if (std.mem.eql(u8, prefix, loc_code)) return loc;
        }
    }

    // Check longer codes (e.g. "pt_br" -> "pt_BR", "zh_hans" -> "zh_Hans")
    if (code_str.len >= 7) {
        const full7 = code_str[0..7];
        inline for (all_locales) |loc| {
            const loc_code = comptime loc.code();
            if (loc_code.len == 7) {
                if (std.ascii.eqlIgnoreCase(full7, loc_code)) return loc;
            }
        }
    }
    if (code_str.len >= 5) {
        const full = code_str[0..5];
        inline for (all_locales) |loc| {
            const loc_code = comptime loc.code();
            if (loc_code.len == 5) {
                if (std.ascii.eqlIgnoreCase(full, loc_code)) return loc;
            }
        }
    }

    return null;
}

/// Detect locale from environment variables.
/// Priority: LC_MESSAGES > LANG > fallback to English.
pub fn detectLocaleFromEnv() Locale {
    const runtime = @import("../runtime.zig");
    if (runtime.getEnv("LC_MESSAGES")) |val| {
        if (parseLocaleCode(val)) |loc| return loc;
    }
    if (runtime.getEnv("LANG")) |val| {
        if (parseLocaleCode(val)) |loc| return loc;
    }
    return .en;
}

// ── CLI flag matching ─────────────────────────────────────────────

/// Comptime-built map from all locale CLI aliases to CliArg.
const cli_alias_map = blk: {
    @setEvalBranchQuota(500000);
    // Collect all entries from all locales
    const locale_aliases = [_][]const CliAliasEntry{
        ar.aliases.cli,
        az.aliases.cli,
        de.aliases.cli,
        el.aliases.cli,
        en.aliases.cli,
        es.aliases.cli,
        fa.aliases.cli,
        fr.aliases.cli,
        he.aliases.cli,
        hu.aliases.cli,
        it.aliases.cli,
        ja.aliases.cli,
        km.aliases.cli,
        ko.aliases.cli,
        pl.aliases.cli,
        pt_br.aliases.cli,
        ro.aliases.cli,
        ru.aliases.cli,
        tr_locale.aliases.cli,
        uk.aliases.cli,
        vi.aliases.cli,
        zh_hans.aliases.cli,
    };

    // Count total entries
    var total: usize = 0;
    for (locale_aliases) |entries| {
        total += entries.len;
    }

    // Build flat array of kvs
    var kvs: [total]struct { [:0]const u8, CliArg } = undefined;
    var idx: usize = 0;
    for (locale_aliases) |entries| {
        for (entries) |entry| {
            // Check for collisions with different CliArg values
            for (kvs[0..idx]) |existing| {
                if (std.mem.eql(u8, existing[0], entry.name)) {
                    if (existing[1] != entry.arg) {
                        @compileError("CLI alias collision: '" ++ entry.name ++ "' maps to different CliArgs in different locales");
                    }
                    // Same mapping already exists, skip duplicate
                    break;
                }
            } else {
                kvs[idx] = .{ entry.name, entry.arg };
                idx += 1;
            }
        }
    }

    break :blk std.StaticStringMap(CliArg).initComptime(kvs[0..idx]);
};

/// Match a long flag string against all known CLI aliases.
/// Returns the CliArg if found, null otherwise.
pub fn matchLongFlag(arg: []const u8) ?CliArg {
    return cli_alias_map.get(arg);
}

/// Check if `arg` matches the given CliArg (via the alias map).
pub fn isFlag(arg: []const u8, expected: CliArg) bool {
    const found = cli_alias_map.get(arg) orelse return false;
    return found == expected;
}

// ── Environment variable matching ─────────────────────────────────

/// Comptime-built: for each EnvVar, the list of all alias names across locales.
fn envAliasesFor(comptime env_var: EnvVar) []const [:0]const u8 {
    const locale_aliases = [_][]const EnvAliasEntry{
        ar.aliases.env,
        az.aliases.env,
        de.aliases.env,
        el.aliases.env,
        en.aliases.env,
        es.aliases.env,
        fa.aliases.env,
        fr.aliases.env,
        he.aliases.env,
        hu.aliases.env,
        it.aliases.env,
        ja.aliases.env,
        km.aliases.env,
        ko.aliases.env,
        pl.aliases.env,
        pt_br.aliases.env,
        ro.aliases.env,
        ru.aliases.env,
        tr_locale.aliases.env,
        uk.aliases.env,
        vi.aliases.env,
        zh_hans.aliases.env,
    };

    // Count matching entries
    comptime var count: usize = 0;
    inline for (locale_aliases) |entries| {
        inline for (entries) |entry| {
            if (entry.var_id == env_var) count += 1;
        }
    }

    // Build array as comptime constant so its address remains valid after return.
    const result = comptime blk: {
        var arr: [count][:0]const u8 = undefined;
        var idx: usize = 0;
        for (locale_aliases) |entries| {
            for (entries) |entry| {
                if (entry.var_id == env_var) {
                    arr[idx] = entry.name;
                    idx += 1;
                }
            }
        }
        const final = arr;
        break :blk final;
    };

    return &result;
}

/// Look up an environment variable by its canonical EnvVar id,
/// checking all locale aliases. Returns the first match.
pub fn getEnvLocalized(comptime env_var: EnvVar) ?[]const u8 {
    const runtime = @import("../runtime.zig");
    const names = comptime envAliasesFor(env_var);
    inline for (names) |name| {
        if (runtime.getEnv(name)) |val| return val;
    }
    return null;
}

// ── Runtime format helpers ────────────────────────────────────────

/// Runtime substitute of `{s}` placeholders in a translated template.
/// Zig's std.fmt requires comptime format strings, so this provides
/// a simple runtime alternative for i18n strings with parameters.
pub fn fmtRuntime(buf: []u8, template: []const u8, args: []const []const u8) []const u8 {
    var pos: usize = 0;
    var arg_idx: usize = 0;
    var i: usize = 0;
    while (i < template.len and pos < buf.len) {
        if (i + 3 <= template.len and template[i] == '{' and template[i + 1] == 's' and template[i + 2] == '}') {
            if (arg_idx < args.len) {
                const arg = args[arg_idx];
                const copy_len = @min(arg.len, buf.len - pos);
                @memcpy(buf[pos..][0..copy_len], arg[0..copy_len]);
                pos += copy_len;
                arg_idx += 1;
            }
            i += 3;
        } else {
            buf[pos] = template[i];
            pos += 1;
            i += 1;
        }
    }
    return buf[0..pos];
}

// ── Tests ─────────────────────────────────────────────────────────

test "English strings are populated" {
    const s = stringsFor(.en);
    try std.testing.expect(s.help_title.len > 0);
    try std.testing.expect(s.about_text.len > 0);
    try std.testing.expect(s.hidden_dir_singular.len > 0);
    try std.testing.expect(s.err_depth_requires_number.len > 0);
}

test "matchLongFlag: known flags" {
    try std.testing.expectEqual(CliArg.help, matchLongFlag("--help").?);
    try std.testing.expectEqual(CliArg.about, matchLongFlag("--about").?);
    try std.testing.expectEqual(CliArg.depth, matchLongFlag("--depth").?);
    try std.testing.expectEqual(CliArg.simple, matchLongFlag("--simple").?);
    try std.testing.expectEqual(CliArg.lang, matchLongFlag("--lang").?);
    try std.testing.expectEqual(CliArg.config, matchLongFlag("--config").?);
}

test "matchLongFlag: unknown flag" {
    try std.testing.expect(matchLongFlag("--nonexistent") == null);
}

test "isFlag works" {
    try std.testing.expect(isFlag("--help", .help));
    try std.testing.expect(!isFlag("--help", .about));
    try std.testing.expect(!isFlag("--bogus", .help));
}

test "parseLocaleCode" {
    try std.testing.expectEqual(Locale.en, parseLocaleCode("en").?);
    try std.testing.expectEqual(Locale.en, parseLocaleCode("en_US").?);
    try std.testing.expectEqual(Locale.en, parseLocaleCode("en_US.UTF-8").?);
    try std.testing.expectEqual(Locale.pt_br, parseLocaleCode("pt_br").?);
    try std.testing.expectEqual(Locale.pt_br, parseLocaleCode("pt_BR").?);
    try std.testing.expectEqual(Locale.zh_hans, parseLocaleCode("zh_hans").?);
    try std.testing.expectEqual(Locale.zh_hans, parseLocaleCode("zh_Hans").?);
    try std.testing.expect(parseLocaleCode("xx") == null);
    try std.testing.expect(parseLocaleCode("") == null);
    try std.testing.expect(parseLocaleCode("e") == null);
}

test "available_codes contains en" {
    try std.testing.expect(std.mem.indexOf(u8, available_codes, "en") != null);
}

test "fmtRuntime: single substitution" {
    var buf: [256]u8 = undefined;
    const result = fmtRuntime(&buf, "Error: '{s}' is not a directory", &.{"mydir"});
    try std.testing.expectEqualStrings("Error: 'mydir' is not a directory", result);
}

test "fmtRuntime: two substitutions" {
    var buf: [256]u8 = undefined;
    const result = fmtRuntime(&buf, "Error: {s} paths must be relative: {s}", &.{ "--show", "/abs/path" });
    try std.testing.expectEqualStrings("Error: --show paths must be relative: /abs/path", result);
}

test "fmtRuntime: no substitutions" {
    var buf: [256]u8 = undefined;
    const result = fmtRuntime(&buf, "plain message", &.{});
    try std.testing.expectEqualStrings("plain message", result);
}

test "matchLongFlag: annotate and note aliases" {
    try std.testing.expectEqual(CliArg.annotate, matchLongFlag("annotate").?);
    try std.testing.expectEqual(CliArg.annotate, matchLongFlag("note").?);
}

test "matchLongFlag: localized annotate aliases" {
    try std.testing.expectEqual(CliArg.annotate, matchLongFlag("nota").?);    // es/it/pt_br
    try std.testing.expectEqual(CliArg.annotate, matchLongFlag("notiz").?);   // de
    try std.testing.expectEqual(CliArg.annotate, matchLongFlag("notatka").?); // pl/uk
    try std.testing.expectEqual(CliArg.annotate, matchLongFlag("memo").?);    // ja
}

test {
    _ = @import("strings.zig");
    _ = @import("cli_aliases.zig");
    _ = @import("ar.zig");
    _ = @import("az.zig");
    _ = @import("de.zig");
    _ = @import("el.zig");
    _ = @import("en.zig");
    _ = @import("es.zig");
    _ = @import("fa.zig");
    _ = @import("fr.zig");
    _ = @import("he.zig");
    _ = @import("hu.zig");
    _ = @import("it.zig");
    _ = @import("ja.zig");
    _ = @import("km.zig");
    _ = @import("ko.zig");
    _ = @import("pl.zig");
    _ = @import("pt_br.zig");
    _ = @import("ro.zig");
    _ = @import("ru.zig");
    _ = @import("tr.zig");
    _ = @import("uk.zig");
    _ = @import("vi.zig");
    _ = @import("zh_hans.zig");
}
