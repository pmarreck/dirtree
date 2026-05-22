const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── S\xc3\xbag\xc3\xb3 sz\xc3\xb6veg ──────────────────────────────────────────────
    .help_title = "dirtree - \xc3\x81llapottart\xc3\xb3 k\xc3\xb6nyvt\xc3\xa1rf\xc3\xa1k emberek \xc3\xa9s LLM-ek sz\xc3\xa1m\xc3\xa1ra",
    .help_usage = "Haszn\xc3\xa1lat: dirtree [OPCI\xc3\x93K] [\xc3\x9aTVONAL]",
    .help_options_header = "Opci\xc3\xb3k:",
    .help_opt_help = "  -h, --help         S\xc3\xbag\xc3\xb3\xc3\xbczenet megjelen\xc3\xadt\xc3\xa9se",
    .help_opt_about = "  -a, --about        R\xc3\xa9szletes le\xc3\xadr\xc3\xa1s megjelen\xc3\xadt\xc3\xa9se",
    .help_opt_depth = "  -d, --depth N      Maxim\xc3\xa1lis m\xc3\xa9lys\xc3\xa9g be\xc3\xa1ll\xc3\xadt\xc3\xa1sa (alap\xc3\xa9rtelmezett: 4)",
    .help_opt_simple = "  --simple           Egyszer\xc5\xb1, LLM-bar\xc3\xa1t \xc3\xa1llapottart\xc3\xb3 fa kimenet",
    .help_opt_decorated = "  --decorated        D\xc3\xadsz\xc3\xadtett kimenet k\xc3\xa9nyszer\xc3\xadt\xc3\xa9se (cs\xc5\x91vez\xc3\xa9s eset\xc3\xa9n is)",
    .help_opt_no_icons = "  --no-icons         Ikonok letilt\xc3\xa1sa (egyszer\xc5\xb1 m\xc3\xb3d + d\xc3\xadsz\xc3\xadtett fejl\xc3\xa9c)",
    .help_opt_no_color = "  --no-color        ANSI sz\xc3\xadnek letilt\xc3\xa1sa \xc3\xa9s be\xc3\xa1ll\xc3\xadt\xc3\xa1s ment\xc3\xa9se",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   OSC8 hivatkoz\xc3\xa1sok letilt\xc3\xa1sa \xc3\xa9s be\xc3\xa1ll\xc3\xadt\xc3\xa1s ment\xc3\xa9se",
    .help_opt_default = "  --default X        Alap\xc3\xa9rtelmezett \xc3\xa1llapot ment\xc3\xa9se: opened|closed",
    .help_opt_open = "  -o, --open K\xc3\x96NYVT.. Egy vagy t\xc3\xb6bb alk\xc3\xb6nyvt\xc3\xa1r megnyit\xc3\xa1sa (ism\xc3\xa9telhet\xc5\x91)",
    .help_opt_close = "  -c, --close K\xc3\x96NYVT. Egy vagy t\xc3\xb6bb alk\xc3\xb6nyvt\xc3\xa1r bez\xc3\xa1r\xc3\xa1sa (ism\xc3\xa9telhet\xc5\x91)",
    .help_opt_show = "  --show \xc3\x9aTV...      Relat\xc3\xadv \xc3\xbatvonalak megjelen\xc3\xadt\xc3\xa9se; regex /minta/ vagy !/minta/",
    .help_opt_hide = "  --hide \xc3\x9aTV...      Relat\xc3\xadv \xc3\xbatvonalak elrejt\xc3\xa9se; regex /minta/ vagy !/minta/ (ism\xc3\xa9telhet\xc5\x91)",
    .help_opt_sort = "  --sort M\xc3\x93D         Rendez\xc3\xa9si m\xc3\xb3d: modified|alpha (alap\xc3\xa9rtelmezett: modified)",
    .help_opt_asc = "  --asc              N\xc3\xb6vekv\xc5\x91 rendez\xc3\xa9s",
    .help_opt_desc = "  --desc             Cs\xc3\xb6kken\xc5\x91 rendez\xc3\xa9s (alap\xc3\xa9rtelmezett)",
    .help_opt_show_hidden = "  --show-hidden      Konfigur\xc3\xa1ci\xc3\xb3val rejtett \xc3\xbatvonalak \xc3\xa1tmeneti megjelen\xc3\xadt\xc3\xa9se",
    .help_opt_rewrite_settings = "  --rewrite-settings \xc3\x81llapotf\xc3\xa1jl \xc3\xbajra\xc3\xadr\xc3\xa1sa az aktu\xc3\xa1lis be\xc3\xa1ll\xc3\xadt\xc3\xa1sokkal",
    .help_opt_config = "  --config           Sz\xc3\xa1m\xc3\xadtott \xc3\xa9rv\xc3\xa9nyes konfigur\xc3\xa1ci\xc3\xb3 megjelen\xc3\xadt\xc3\xa9se",
        .help_opt_test = "  --test             Kapcsol\xc3\xb3d\xc3\xb3 tesztek futtat\xc3\xa1sa",
    .help_opt_lang = "  --lang K\xc3\x93D         Megjelen\xc3\xadt\xc3\xa9si nyelv be\xc3\xa1ll\xc3\xadt\xc3\xa1sa (pl. en, de, fr, ja)",
    .help_regex_note = "Haszn\xc3\xa1lja a /minta/ vagy !/minta/ form\xc3\xa1t --open/--close/--show/--hide-dal regex szab\xc3\xa1lyokhoz; egy\xc3\xa9b argumentumok liter\xc3\xa1lk\xc3\xa9nt \xc3\xa9rtelmez\xc5\x91dnek.",
    .help_relative_note = "A --show/--hide \xc3\xbatvonalaknak relat\xc3\xadvnak kell lenni\xc3\xbck (nincs bevezet\xc5\x91 '/').",
    .help_behavior_header = "Viselked\xc3\xa9s:",
    .help_behavior_text = "Alap\xc3\xa9rtelmez\xc3\xa9s szerint, ha az stdout nem TTY (cs\xc5\x91vez\xc3\xa9s), a sz\xc3\xadnek/ikonok/hivatkoz\xc3\xa1sok letilt\xc3\xa1sra ker\xc3\xbclnek, kiv\xc3\xa9ve ha --decorated meg van adva.",
    .help_examples_header = "P\xc3\xa9ld\xc3\xa1k:",
    .help_example_1 = "  dirtree                       # Az aktu\xc3\xa1lis k\xc3\xb6nyvt\xc3\xa1r f\xc3\xa1j\xc3\xa1nak megjelen\xc3\xadt\xc3\xa9se",
    .help_example_2 = "  dirtree -d 3                  # M\xc3\xa9lys\xc3\xa9g be\xc3\xa1ll\xc3\xadt\xc3\xa1sa 3 szintre",
    .help_example_3 = "  dirtree --sort alpha --asc    # \xc3\x81b\xc3\xa9c\xc3\xa9 sorrend n\xc3\xb6vekv\xc5\x91en",

    // ── N\xc3\xa9vjegy sz\xc3\xb6veg ─────────────────────────────────────────────
    .about_text = "\xc3\x81llapottart\xc3\xb3 k\xc3\xb6nyvt\xc3\xa1rfa (ikonok/sz\xc3\xadnek/linkek); --simple LLM-ekhez; .dirtree-state-be ment (default/open/close/show/hide); regex /minta/ vagy !/minta/ \xc3\xbaton; liter\xc3\xa1loknak relat\xc3\xadvnak kell lenni\xc3\xbck; k\xc3\xb6rnyezet: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── Rejtett sz\xc3\xa1ml\xc3\xa1l\xc3\xb3 t\xc3\xb6red\xc3\xa9kek ────────────────────────────────
    .hidden_dir_singular = "k\xc3\xb6nyvt\xc3\xa1r",
    .hidden_dir_plural = "k\xc3\xb6nyvt\xc3\xa1r",
    .hidden_file_singular = "f\xc3\xa1jl",
    .hidden_file_plural = "f\xc3\xa1jl",
    .hidden_and = " \xc3\xa9s ",
    .hidden_is_hidden = " rejtett.",
    .hidden_are_hidden = " rejtettek.",
    .stats_shown = " megjelenítve",
    .stats_hidden = " rejtve.",
    .stats_line_singular = "sor",
    .stats_line_plural = "sor",
    .stats_separator = "; ",

    // ── Hiba\xc3\xbczenetek ──────────────────────────────────────────────
    .err_depth_requires_number = "Hiba: --depth sz\xc3\xa1mszer\xc5\xb1 argumentumot ig\xc3\xa9nyel",
    .err_sort_requires_mode = "Hiba: --sort 'modified' vagy 'alpha' sz\xc3\xbcks\xc3\xa9ges",
    .err_default_requires_value = "Hiba: --default legal\xc3\xa1bb egy \xc3\xa9rt\xc3\xa9ket ig\xc3\xa9nyel",
    .err_default_state_conflict = "Hiba: --default \xc3\xa1llapot\xc3\xbctk\xc3\xb6z\xc3\xa9s",
    .err_default_accepts = "Hiba: --default elfogadja: opened/closed",
    .err_open_requires_dir = "Hiba: --open legal\xc3\xa1bb egy k\xc3\xb6nyvt\xc3\xa1rat ig\xc3\xa9nyel",
    .err_close_requires_dir = "Hiba: --close legal\xc3\xa1bb egy k\xc3\xb6nyvt\xc3\xa1rat ig\xc3\xa9nyel",
    .err_show_requires_path = "Hiba: --show legal\xc3\xa1bb egy \xc3\xbatvonalat ig\xc3\xa9nyel",
    .err_hide_requires_path = "Hiba: --hide legal\xc3\xa1bb egy \xc3\xbatvonalat ig\xc3\xa9nyel",
    .err_unknown_option = "Ismeretlen opci\xc3\xb3",
    .err_not_a_directory = "Hiba: '{s}' nem k\xc3\xb6nyvt\xc3\xa1r",
    .err_regex_empty = "Hiba: a regex minta nem lehet \xc3\xbcres",
    .err_paths_must_be_relative = "Hiba: {s} \xc3\xbatvonalaknak relat\xc3\xadvnak kell lenni\xc3\xbck (nincs bevezet\xc5\x91 '/'): {s}",
    .err_out_of_memory = "Elfogyott a mem\xc3\xb3ria",
    .err_regex_conflict_path = "Hiba: a '{s}' \xc3\xbatvonal mind a megnyit\xc3\xa1si, mind a bez\xc3\xa1r\xc3\xa1si mint\xc3\xa1ra illeszkedik",
    .err_regex_conflict_open = "  megnyit\xc3\xa1si minta: {s}",
    .err_regex_conflict_close = "  bez\xc3\xa1r\xc3\xa1si minta: {s}",
    .err_unknown_lang = "Hiba: ismeretlen nyelvk\xc3\xb3d '{s}'. El\xc3\xa9rhet\xc5\x91: {s}",
    .err_annotate_requires_path = "Error: annotate requires a path",
    .err_annotate_requires_description = "Error: annotate requires a description (use \"\" to clear)",
    .err_annotate_multiline = "Error: annotation description must be a single line",
    .err_annotate_too_many_args = "Error: annotate accepts exactly two positional arguments: <path> <description>",
    .help_opt_annotate = "  annotate PATH DESC Persist a one-line note about a file or directory (alias: note; empty DESC clears)",

    // ── Figyelmeztet\xc3\xa9sek ─────────────────────────────────────────
    .warn_persist_state = "Figyelmeztet\xc3\xa9s: az \xc3\xa1llapot nem menthet\xc5\x91: {}",

    // ── Teszt m\xc3\xb3d ──────────────────────────────────────────────────
    .test_mode_msg = "Teszt m\xc3\xb3d: a Zig egys\xc3\xa9gtesztek a 'zig build test' paranccsal futtathat\xc3\xb3k",

    // ── Egy\xc3\xa9b ──────────────────────────────────────────────────────
    .err_test_bin_run = "Hiba: a DIRTREE_TEST_BIN nem futtathat\xc3\xb3: {s}",
    .err_test_bin_wait = "Hiba: a DIRTREE_TEST_BIN-re nem siker\xc3\xbclt v\xc3\xa1rakozni",
    .err_render_tree = "Fa megjelen\xc3\xadt\xc3\xa9si hiba: {}",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--sugo", .arg = .help },
        .{ .name = "--rolunk", .arg = .about },
        .{ .name = "--melyseg", .arg = .depth },
        .{ .name = "--egyszeruu", .arg = .simple },
        .{ .name = "--diszitett", .arg = .decorated },
        .{ .name = "--ikonok-nelkul", .arg = .no_icons },
        .{ .name = "--szin-nelkul", .arg = .no_color },
        .{ .name = "--hivatkozasok-nelkul", .arg = .no_hyperlinks },
        .{ .name = "--alapertelmezett", .arg = .default },
        .{ .name = "--megnyitas", .arg = .open },
        .{ .name = "--bezaras", .arg = .close },
        .{ .name = "--megjelenit", .arg = .show },
        .{ .name = "--elrejt", .arg = .hide },
        .{ .name = "--rendezes", .arg = .sort },
        .{ .name = "--novekvo", .arg = .asc },
        .{ .name = "--csokkeno", .arg = .desc },
        .{ .name = "--rejtett-mutat", .arg = .show_hidden },
        .{ .name = "--beallitasok-ujrairasa", .arg = .rewrite_settings },
        .{ .name = "--beallitas", .arg = .config },
                .{ .name = "--tesztel", .arg = .@"test" },
        .{ .name = "--nyelv", .arg = .lang },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "KONYVTAR_FA_EGYSZERU", .var_id = .dirtree_simple },
        .{ .name = "KONYVTAR_FA_DISZITETT", .var_id = .dirtree_decorated },
        .{ .name = "KONYVTAR_FA_AUTO_EGYSZERU", .var_id = .dirtree_auto_simple },
        .{ .name = "PIPED_STDOUT", .var_id = .piped_stdout },
        .{ .name = "KONYVTAR_FA_SCM_VALTOZASOK_REJTETT_VAGY_ZART", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
