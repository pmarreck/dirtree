/// Canonical CLI argument identifiers.
/// Each long flag maps to one of these.
pub const CliArg = enum {
    help,
    about,
    depth,
    simple,
    decorated,
    no_icons,
    no_color,
    no_hyperlinks,
    default,
    open,
    close,
    show,
    hide,
    sort,
    asc,
    desc,
    show_hidden,
    rewrite_settings,
    config,
    @"test",
    lang,
    max_lines,
    override_warning,
    head,
    tail,
    only,
    annotate,
};

/// Per-locale CLI aliases: array of (string, CliArg) pairs.
pub const CliAliasEntry = struct {
    name: [:0]const u8,
    arg: CliArg,
};

/// Canonical environment variable identifiers.
pub const EnvVar = enum {
    dirtree_simple,
    dirtree_decorated,
    dirtree_auto_simple,
    piped_stdout,
    dirtree_scm_changes_stay_hidden_or_closed,
};

/// Per-locale environment variable alias: (string, EnvVar) pair.
pub const EnvAliasEntry = struct {
    name: [:0]const u8,
    var_id: EnvVar,
};

/// A locale provides arrays of CLI and env aliases.
pub const LocaleAliases = struct {
    cli: []const CliAliasEntry,
    env: []const EnvAliasEntry,
};
