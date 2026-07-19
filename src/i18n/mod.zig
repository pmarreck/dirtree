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
const bn = @import("bn.zig");
const hi = @import("hi.zig");
const pa = @import("pa.zig");
const ps = @import("ps.zig");
const sw = @import("sw.zig");
const ta = @import("ta.zig");
const th = @import("th.zig");
const ur = @import("ur.zig");
const sq = @import("sq.zig");
const sr = @import("sr.zig");
const hr = @import("hr.zig");
const bs = @import("bs.zig");
const bg = @import("bg.zig");
const mk = @import("mk.zig");
const sl = @import("sl.zig");
const nl = @import("nl.zig");
const sv = @import("sv.zig");
const nb = @import("nb.zig");
const da = @import("da.zig");
const fi = @import("fi.zig");
const is = @import("is.zig");
const zh_hant = @import("zh_hant.zig");
const id = @import("id.zig");
const ha = @import("ha.zig");
const am = @import("am.zig");
const yo = @import("yo.zig");
const ig = @import("ig.zig");
const fil = @import("fil.zig");

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
    bn,
    hi,
    pa,
    ps,
    sw,
    ta,
    th,
    ur,
    sq,
    sr,
    hr,
    bs,
    bg,
    mk,
    sl,
    nl,
    sv,
    nb,
    da,
    fi,
    is,
    zh_hant,
    id,
    ha,
    am,
    yo,
    ig,
    fil,

    pub fn code(self: Locale) [:0]const u8 {
        // Enum field names ARE the locale codes (de, pt_br, zh_hans, ...), so
        // @tagName is the single source of truth — no hand-maintained switch.
        return @tagName(self);
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
    .bn,
    .hi,
    .pa,
    .ps,
    .sw,
    .ta,
    .th,
    .ur,
    .sq,
    .sr,
    .hr,
    .bs,
    .bg,
    .mk,
    .sl,
    .nl,
    .sv,
    .nb,
    .da,
    .fi,
    .is,
    .zh_hant,
    .id,
    .ha,
    .am,
    .yo,
    .ig,
    .fil,
};

/// Comma-separated list of all locale codes (for error messages).
/// NOTE: Update this when adding locales (Zig comptime can't build
/// runtime-referencing slices from var buffers for global consts).
pub const available_codes: []const u8 = blk: {
    @setEvalBranchQuota(100000);
    // Single source of truth: derive the code list from all_locales and sort it
    // alphabetically at comptime, so it can never drift from the registry or fall
    // out of order as locales are added.
    var codes: [all_locales.len][]const u8 = undefined;
    for (all_locales, 0..) |loc, i| codes[i] = loc.code();
    std.mem.sort([]const u8, codes[0..], {}, struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lt);
    var total: usize = 0;
    for (codes) |c| total += c.len;
    total += (codes.len - 1) * 2; // ", " separators
    var buf: [total]u8 = undefined;
    var pos: usize = 0;
    for (codes, 0..) |c, i| {
        if (i > 0) {
            buf[pos] = ',';
            buf[pos + 1] = ' ';
            pos += 2;
        }
        @memcpy(buf[pos .. pos + c.len], c);
        pos += c.len;
    }
    const final = buf;
    break :blk &final;
};

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
/// The CLI alias array for a locale (mirrors stringsFor).
const locale_cli_alias_table = blk: {
    // Registry: derive Locale -> CLI aliases from all_locales at comptime (see above).
    var arr: [all_locales.len][]const CliAliasEntry = undefined;
    for (all_locales) |loc| {
        const name = if (loc == .tr) "tr_locale" else @tagName(loc);
        arr[@intFromEnum(loc)] = @field(@This(), name).aliases.cli;
    }
    break :blk arr;
};

pub fn localeCliAliases(loc: Locale) []const CliAliasEntry {
    return locale_cli_alias_table[@intFromEnum(loc)];
}

/// The current locale's preferred (first-listed) alias for a flag, falling back
/// to the canonical English name. Lets diagnostics reference switches in the
/// user's language when a localized alias exists.
pub fn localizedFlagName(arg: CliArg) [:0]const u8 {
    for (localeCliAliases(current_locale)) |entry| {
        if (entry.arg == arg) return entry.name;
    }
    for (en.aliases.cli) |entry| {
        if (entry.arg == arg) return entry.name;
    }
    return "?";
}

const locale_strings_table = blk: {
    // Registry: derive Locale -> *Strings from all_locales at comptime instead of a
    // hand-maintained 50-arm switch. tr's import is `tr_locale` (avoids pub fn tr()).
    var arr: [all_locales.len]*const Strings = undefined;
    for (all_locales) |loc| {
        const name = if (loc == .tr) "tr_locale" else @tagName(loc);
        arr[@intFromEnum(loc)] = &@field(@This(), name).strings;
    }
    break :blk arr;
};

fn stringsFor(loc: Locale) *const Strings {
    return locale_strings_table[@intFromEnum(loc)];
}

// ── Locale detection ──────────────────────────────────────────────

/// Parse a locale code string (e.g. "de", "de_DE", "de_DE.UTF-8") into a Locale.
/// Returns null if unrecognized.
pub fn parseLocaleCode(code_str: []const u8) ?Locale {
    // Match the input against every known locale code (any length: 2/3/4/5/6/7),
    // case-insensitively. The match must end at the full code — either the input
    // ends there, or the next byte is a separator (`_`, `-`, `.`) — so a region
    // or script suffix like "de_DE", "en-GB", "es_419", "en_US.UTF-8" resolves to
    // its base locale. The separator boundary also prevents a longer code from
    // false-matching a shorter one that happens to be a prefix (e.g. "fix" must
    // NOT resolve to Finnish "fi", and a 3-char code like "fil" is matched in
    // full rather than collapsing to "fi"). When several codes match, the
    // longest wins.
    if (code_str.len < 2) return null;
    var best: ?Locale = null;
    var best_len: usize = 0;
    inline for (all_locales) |loc| {
        const lc = comptime loc.code();
        if (code_str.len >= lc.len and std.ascii.eqlIgnoreCase(code_str[0..lc.len], lc)) {
            const at_boundary = code_str.len == lc.len or switch (code_str[lc.len]) {
                '_', '-', '.' => true,
                else => false,
            };
            if (at_boundary and lc.len > best_len) {
                best = loc;
                best_len = lc.len;
            }
        }
    }
    // Generic Chinese with no explicit script code (zh, zh_CN, zh_TW, zh-Hant…)
    // isn't one of the defined codes above; fold it: default to Simplified,
    // except Traditional script (Hant) or Traditional-script regions (TW/HK/MO).
    if (best == null and code_str.len >= 2 and std.ascii.eqlIgnoreCase(code_str[0..2], "zh")) {
        const at_boundary = code_str.len == 2 or switch (code_str[2]) {
            '_', '-', '.' => true,
            else => false,
        };
        if (at_boundary) {
            const traditional = (std.ascii.indexOfIgnoreCase(code_str, "hant") != null) or
                (std.ascii.indexOfIgnoreCase(code_str, "tw") != null) or
                (std.ascii.indexOfIgnoreCase(code_str, "hk") != null) or
                (std.ascii.indexOfIgnoreCase(code_str, "mo") != null);
            return if (traditional) .zh_hant else .zh_hans;
        }
    }
    return best;
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

/// Infer a locale from a localized CLI alias present in `args` (e.g. "--hilfe"
/// implies German). Only non-English locales' aliases trigger inference — the
/// canonical English flags live only in the English alias table, so a plain
/// "--help"/"--depth" never changes the locale. Returns the first match in
/// argument order; null if no localized alias is present.
pub fn detectLocaleFromAliases(args: []const [:0]const u8) ?Locale {
    for (args) |arg| {
        inline for (all_locales) |loc| {
            if (loc != .en) {
                for (localeCliAliases(loc)) |entry| {
                    if (std.mem.eql(u8, arg, entry.name)) return loc;
                }
            }
        }
    }
    return null;
}

// ── CLI flag matching ─────────────────────────────────────────────

/// Comptime-built map from all locale CLI aliases to CliArg.
const cli_alias_map = blk: {
    @setEvalBranchQuota(20000000);
    // Collect all entries from all locales

    // Count total entries
    var total: usize = 0;
    for (all_locales) |loc| {
        total += localeCliAliases(loc).len;
    }

    // Build flat array of kvs
    var kvs: [total]struct { [:0]const u8, CliArg } = undefined;
    var idx: usize = 0;
    for (all_locales) |loc| {
        for (localeCliAliases(loc)) |entry| {
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
        bn.aliases.env,
        hi.aliases.env,
        pa.aliases.env,
        ps.aliases.env,
        sw.aliases.env,
        ta.aliases.env,
        th.aliases.env,
        ur.aliases.env,
        sq.aliases.env,
        sr.aliases.env,
        hr.aliases.env,
        bs.aliases.env,
        bg.aliases.env,
        mk.aliases.env,
        sl.aliases.env,
        nl.aliases.env,
        sv.aliases.env,
        nb.aliases.env,
        da.aliases.env,
        fi.aliases.env,
        is.aliases.env,
        zh_hant.aliases.env,
        id.aliases.env,
        ha.aliases.env,
        am.aliases.env,
        yo.aliases.env,
        ig.aliases.env,
        fil.aliases.env,
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
            // Cycle through args: a template may repeat the same placeholders
            // (e.g. a bilingual "<localized> (en: <english>)" error reuses the
            // same substitution in both halves), so wrap past the end.
            if (args.len > 0) {
                const arg = args[arg_idx % args.len];
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
    // Region/script suffixes resolve to the base locale (incl. 6-char inputs).
    try std.testing.expectEqual(Locale.en, parseLocaleCode("en-GB").?);
    try std.testing.expectEqual(Locale.es, parseLocaleCode("es_419").?);
    try std.testing.expectEqual(Locale.pt_br, parseLocaleCode("PT_BR").?);
    // A longer code that merely shares a 2-char prefix must NOT false-match the
    // 2-char locale (regression: the old prefix-only matcher returned Finnish
    // for "fix"). Without a separator boundary it is not that locale.
    try std.testing.expect(parseLocaleCode("fix") == null);
    try std.testing.expect(parseLocaleCode("deu") == null);
    // Longest defined code wins when one code is a prefix of another at a
    // separator boundary.
    try std.testing.expectEqual(Locale.pt_br, parseLocaleCode("pt_br_x").?);
    // Generic Chinese folds by region/script: default Simplified, Traditional
    // only for Hant / TW / HK / MO. Explicit zh_hans/zh_hant still resolve.
    try std.testing.expectEqual(Locale.zh_hans, parseLocaleCode("zh").?);
    try std.testing.expectEqual(Locale.zh_hans, parseLocaleCode("zh_CN").?);
    try std.testing.expectEqual(Locale.zh_hans, parseLocaleCode("zh_SG").?);
    try std.testing.expectEqual(Locale.zh_hans, parseLocaleCode("zh-Hans").?);
    try std.testing.expectEqual(Locale.zh_hant, parseLocaleCode("zh_TW").?);
    try std.testing.expectEqual(Locale.zh_hant, parseLocaleCode("zh_HK").?);
    try std.testing.expectEqual(Locale.zh_hant, parseLocaleCode("zh_MO").?);
    try std.testing.expectEqual(Locale.zh_hant, parseLocaleCode("zh-Hant-TW").?);
    try std.testing.expectEqual(Locale.zh_hant, parseLocaleCode("zh_hant").?);
    try std.testing.expectEqual(Locale.zh_hans, parseLocaleCode("zh_hans").?);
}

test "available_codes is alphabetically sorted and complete" {
    var iter = std.mem.splitSequence(u8, available_codes, ", ");
    var prev: []const u8 = "";
    var count: usize = 0;
    while (iter.next()) |code| {
        if (count > 0) {
            try std.testing.expect(std.mem.lessThan(u8, prev, code));
        }
        prev = code;
        count += 1;
    }
    // Every locale appears exactly once.
    try std.testing.expectEqual(all_locales.len, count);
    // Exact-token membership (not substring): each code must equal a full
    // comma-separated token, so e.g. "en" can't pass by matching inside another code.
    inline for (all_locales) |loc| {
        var code_it = std.mem.splitSequence(u8, available_codes, ", ");
        var present = false;
        while (code_it.next()) |tok| {
            if (std.mem.eql(u8, tok, loc.code())) present = true;
        }
        try std.testing.expect(present);
    }
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
    _ = @import("bn.zig");
    _ = @import("hi.zig");
    _ = @import("pa.zig");
    _ = @import("ps.zig");
    _ = @import("sw.zig");
    _ = @import("ta.zig");
    _ = @import("th.zig");
    _ = @import("ur.zig");
    _ = @import("sq.zig");
    _ = @import("sr.zig");
    _ = @import("hr.zig");
    _ = @import("bs.zig");
    _ = @import("bg.zig");
    _ = @import("mk.zig");
    _ = @import("sl.zig");
    _ = @import("nl.zig");
    _ = @import("sv.zig");
    _ = @import("nb.zig");
    _ = @import("da.zig");
    _ = @import("fi.zig");
    _ = @import("is.zig");
    _ = @import("zh_hant.zig");
    _ = @import("id.zig");
    _ = @import("ha.zig");
    _ = @import("am.zig");
    _ = @import("yo.zig");
    _ = @import("ig.zig");
    _ = @import("fil.zig");
}

test "every locale resolves and has all Strings fields populated" {
    @setEvalBranchQuota(100000);
    // Strings fields carry English defaults, so a locale that omits a field
    // silently inherits English rather than failing to compile. This loop
    // forces every locale's dispatch arm to resolve and asserts no field was
    // blanked out, catching a missing/empty translation in any of the locales.
    inline for (all_locales) |loc| {
        const s = stringsFor(loc);
        inline for (std.meta.fields(Strings)) |field| {
            const value = @field(s, field.name);
            if (value.len == 0) {
                std.debug.print("locale '{s}' has empty field '{s}'\n", .{ loc.code(), field.name });
                return error.EmptyLocaleField;
            }
        }
        // The new invalid-regex error string must be present and carry the {s}
        // placeholder for the offending pattern in every locale.
        try std.testing.expect(std.mem.indexOf(u8, s.err_regex_invalid, "{s}") != null);
    }
}

test "all_locales covers every Locale enum value" {
    try std.testing.expectEqual(@typeInfo(Locale).@"enum".fields.len, all_locales.len);
}

// ── Exhaustive i18n classifier tests (over the full locale set) ────

/// Per-locale env aliases (mirrors localeCliAliases). Kept local to the test
/// scope; product code resolves env vars by EnvVar, not by locale.
fn localeEnvAliases(loc: Locale) []const EnvAliasEntry {
    return switch (loc) {
        .ar => ar.aliases.env,
        .az => az.aliases.env,
        .de => de.aliases.env,
        .el => el.aliases.env,
        .en => en.aliases.env,
        .es => es.aliases.env,
        .fa => fa.aliases.env,
        .fr => fr.aliases.env,
        .he => he.aliases.env,
        .hu => hu.aliases.env,
        .it => it.aliases.env,
        .ja => ja.aliases.env,
        .km => km.aliases.env,
        .ko => ko.aliases.env,
        .pl => pl.aliases.env,
        .pt_br => pt_br.aliases.env,
        .ro => ro.aliases.env,
        .ru => ru.aliases.env,
        .tr => tr_locale.aliases.env,
        .uk => uk.aliases.env,
        .vi => vi.aliases.env,
        .zh_hans => zh_hans.aliases.env,
        .bn => bn.aliases.env,
        .hi => hi.aliases.env,
        .pa => pa.aliases.env,
        .ps => ps.aliases.env,
        .sw => sw.aliases.env,
        .ta => ta.aliases.env,
        .th => th.aliases.env,
        .ur => ur.aliases.env,
        .sq => sq.aliases.env,
        .sr => sr.aliases.env,
        .hr => hr.aliases.env,
        .bs => bs.aliases.env,
        .bg => bg.aliases.env,
        .mk => mk.aliases.env,
        .sl => sl.aliases.env,
        .nl => nl.aliases.env,
        .sv => sv.aliases.env,
        .nb => nb.aliases.env,
        .da => da.aliases.env,
        .fi => fi.aliases.env,
        .is => is.aliases.env,
        .zh_hant => zh_hant.aliases.env,
        .id => id.aliases.env,
        .ha => ha.aliases.env,
        .am => am.aliases.env,
        .yo => yo.aliases.env,
        .ig => ig.aliases.env,
        .fil => fil.aliases.env,
    };
}

test "Test A: every CLI/env alias resolves to its declared arg/var (all locales)" {
    @setEvalBranchQuota(2000000);
    // CLI: every (name -> arg) declared by every locale must round-trip through
    // the public matchLongFlag map back to that exact arg. Catches a locale that
    // maps a word to the wrong CliArg by copy-paste.
    inline for (all_locales) |loc| {
        for (localeCliAliases(loc)) |entry| {
            const got = matchLongFlag(entry.name) orelse {
                std.debug.print("locale '{s}': CLI alias '{s}' did not resolve at all\n", .{ loc.code(), entry.name });
                return error.CliAliasUnresolved;
            };
            if (got != entry.arg) {
                std.debug.print("locale '{s}': CLI alias '{s}' resolves to .{s}, declared .{s}\n", .{ loc.code(), entry.name, @tagName(got), @tagName(entry.arg) });
                return error.CliAliasWrongArg;
            }
        }
    }
    // Env: every (name -> var_id) declared by every locale must appear in the
    // comptime alias list for that EnvVar (i.e. resolve to its declared var),
    // and must NOT appear in any other EnvVar's alias list (unique resolution).
    inline for (all_locales) |loc| {
        for (localeEnvAliases(loc)) |entry| {
            var found_in_declared = false;
            inline for (std.meta.fields(EnvVar)) |evf| {
                const ev = @field(EnvVar, evf.name);
                const names = comptime envAliasesFor(ev);
                var present = false;
                for (names) |n| {
                    if (std.mem.eql(u8, n, entry.name)) {
                        present = true;
                        break;
                    }
                }
                if (ev == entry.var_id) {
                    if (present) found_in_declared = true;
                } else if (present) {
                    std.debug.print("locale '{s}': env alias '{s}' (declared .{s}) also resolves to .{s}\n", .{ loc.code(), entry.name, @tagName(entry.var_id), @tagName(ev) });
                    return error.EnvAliasWrongVar;
                }
            }
            if (!found_in_declared) {
                std.debug.print("locale '{s}': env alias '{s}' does not resolve to its declared .{s}\n", .{ loc.code(), entry.name, @tagName(entry.var_id) });
                return error.EnvAliasUnresolved;
            }
        }
    }
}

test "Test B: non-Latin-script locales are genuinely translated (not English)" {
    // Guards against a translation being reverted to the English value. Only
    // non-Latin-script locales are checked: Latin/Germanic locales can legally
    // share strings with English via loanwords and would false-fail.
    const en_strings = stringsFor(.en);
    const sentinel = [_]Locale{ .ja, .ar, .ru, .zh_hans, .ko, .el, .he, .th };
    inline for (sentinel) |loc| {
        const s = stringsFor(loc);
        if (std.mem.eql(u8, s.help_title, en_strings.help_title)) {
            std.debug.print("locale '{s}': help_title is byte-equal to English (untranslated)\n", .{loc.code()});
            return error.LocaleNotTranslated;
        }
    }
}

test "Test C: parseLocaleCode round-trips over the full locale set" {
    inline for (all_locales) |loc| {
        try std.testing.expectEqual(loc, parseLocaleCode(loc.code()).?);
        // Region/encoding suffixes must still fold back to the base locale.
        var buf: [32]u8 = undefined;
        const code = comptime loc.code();
        const with_region = std.fmt.bufPrint(&buf, "{s}_XX", .{code}) catch unreachable;
        try std.testing.expectEqual(loc, parseLocaleCode(with_region).?);
        var buf2: [32]u8 = undefined;
        const with_enc = std.fmt.bufPrint(&buf2, "{s}.UTF-8", .{code}) catch unreachable;
        try std.testing.expectEqual(loc, parseLocaleCode(with_enc).?);
    }
}

test "Test D: no non-English locale reuses an English canonical CLI token (locale-inference safety)" {
    // MFIC set-classifier over ALL locales. detectLocaleFromAliases skips English
    // and returns the first non-English locale whose alias matches an argument, so
    // a non-English table that copies an English canonical token (e.g. a stray
    // "note" left over from seeding a locale file off en.zig) would hijack locale
    // inference: typing that plain English word switches the whole UI into that
    // language. The contract is that English canonical flags live ONLY in the
    // English table, so each non-English alias-name set must be DISJOINT from
    // English's. Tested as a classifier over the full cross-product, not a spot check.
    @setEvalBranchQuota(2000000);
    const en_aliases = localeCliAliases(.en);
    inline for (all_locales) |loc| {
        if (loc != .en) {
            for (localeCliAliases(loc)) |entry| {
                for (en_aliases) |en_entry| {
                    if (std.mem.eql(u8, entry.name, en_entry.name)) {
                        std.debug.print("locale '{s}': CLI alias '{s}' duplicates an English canonical token — would hijack locale inference\n", .{ loc.code(), entry.name });
                        return error.EnglishTokenReusedByLocale;
                    }
                }
            }
        }
    }
}

test "Test E: English canonical CLI tokens never infer a non-English locale" {
    // Behavioral regression for the Urdu-under-English repro: `dirtree note ...`
    // must NOT select a non-English locale. Every English canonical CLI token,
    // passed alone as an argument, must leave locale inference undecided (null) so
    // the environment/--lang/default wins instead.
    @setEvalBranchQuota(2000000);
    for (localeCliAliases(.en)) |en_entry| {
        const args = [_][:0]const u8{en_entry.name};
        if (detectLocaleFromAliases(&args)) |loc| {
            std.debug.print("English token '{s}' wrongly inferred locale '{s}'\n", .{ en_entry.name, loc.code() });
            return error.EnglishTokenInferredLocale;
        }
    }
}
