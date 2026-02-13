const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── Text de ajutor ──────────────────────────────────────────
    .help_title = "dirtree - Arbori de directoare cu stare pentru oameni \xc8\x99i LLM-uri",
    .help_usage = "Utilizare: dirtree [OP\xc8\x9aIUNI] [CALE]",
    .help_options_header = "Op\xc8\x9biuni:",
    .help_opt_help = "  -h, --help         Afi\xc8\x99eaz\xc4\x83 acest mesaj de ajutor",
    .help_opt_about = "  -a, --about        Afi\xc8\x99eaz\xc4\x83 descrierea detaliat\xc4\x83",
    .help_opt_depth = "  -d, --depth N      Seteaz\xc4\x83 ad\xc3\xa2ncimea maxim\xc4\x83 (implicit: 4)",
    .help_opt_simple = "  --simple           Ie\xc8\x99ire simpl\xc4\x83, prietenoas\xc4\x83 pentru LLM-uri",
    .help_opt_decorated = "  --decorated        For\xc8\x9beaz\xc4\x83 ie\xc8\x99irea decorat\xc4\x83 (chiar \xc8\x99i \xc3\xaen pipe)",
    .help_opt_no_icons = "  --no-icons         Dezactiveaz\xc4\x83 pictogramele (mod simplu + antet decorat)",
    .help_opt_no_color = "  --no-color        Dezactiveaz\xc4\x83 culorile ANSI \xc8\x99i persist\xc4\x83 preferin\xc8\x9ba",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   Dezactiveaz\xc4\x83 hiperleg\xc4\x83turile OSC8 \xc8\x99i persist\xc4\x83 preferin\xc8\x9ba",
    .help_opt_default = "  --default X        Persist\xc4\x83 starea implicit\xc4\x83: opened|closed",
    .help_opt_open = "  -o, --open DIR...  Deschide unul sau mai multe subdirectoare",
    .help_opt_close = "  -c, --close DIR... \xc3\x8enchide unul sau mai multe subdirectoare",
    .help_opt_show = "  --show CALE...     For\xc8\x9beaz\xc4\x83 afi\xc8\x99area c\xc4\x83ilor relative; regex ca /pattern/ sau !/pattern/",
    .help_opt_hide = "  --hide CALE...     Ascunde c\xc4\x83i relative; regex ca /pattern/ sau !/pattern/",
    .help_opt_sort = "  --sort MOD         Mod de sortare: modified|alpha (implicit: modified)",
    .help_opt_asc = "  --asc              Sortare cresc\xc4\x83toare",
    .help_opt_desc = "  --desc             Sortare descresc\xc4\x83toare (implicit)",
    .help_opt_show_hidden = "  --show-hidden      Afi\xc8\x99eaz\xc4\x83 temporar c\xc4\x83ile ascunse prin configura\xc8\x9bie",
    .help_opt_rewrite_settings = "  --rewrite-settings Rescrie fi\xc8\x99ierul de stare cu set\xc4\x83rile curente",
    .help_opt_config = "  --config           Afi\xc8\x99eaz\xc4\x83 configura\xc8\x9bia efectiv\xc4\x83 calculat\xc4\x83",
        .help_opt_test = "  --test             Ruleaz\xc4\x83 testele asociate",
    .help_opt_lang = "  --lang COD         Seteaz\xc4\x83 limba de afi\xc8\x99are (ex. en, de, fr, ja)",
    .help_regex_note = "Folosi\xc8\x9bi /pattern/ sau !/pattern/ cu --open/--close/--show/--hide pentru reguli regex; celelalte argumente sunt tratate ca literale.",
    .help_relative_note = "C\xc4\x83ile furnizate la --show/--hide trebuie s\xc4\x83 fie relative (f\xc4\x83r\xc4\x83 '/' ini\xc8\x9bial).",
    .help_behavior_header = "Comportament:",
    .help_behavior_text = "Implicit, c\xc3\xa2nd stdout nu este un TTY (pipe), culorile/pictogramele/hiperleg\xc4\x83turile sunt dezactivate, cu excep\xc8\x9bia cazului \xc3\xaen care se specific\xc4\x83 --decorated.",
    .help_examples_header = "Exemple:",
    .help_example_1 = "  dirtree                       # Afi\xc8\x99eaz\xc4\x83 arborele directorului curent",
    .help_example_2 = "  dirtree -d 3                  # Ad\xc3\xa2ncime limitat\xc4\x83 la 3 niveluri",
    .help_example_3 = "  dirtree --sort alpha --asc    # Sortat alfabetic cresc\xc4\x83tor",

    // ── Text despre ──────────────────────────────────────────────
    .about_text = "Arbore de directoare cu stare (pictograme/culori/leg\xc4\x83turi); --simple pentru LLM-uri; persist\xc4\x83 .dirtree-state (default/open/close/show/hide); regex prin /pattern/ sau !/pattern/; literalele trebuie s\xc4\x83 fie relative; env: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── Fragmente num\xc4\x83rare ascunse ────────────────────────────
    .hidden_dir_singular = "director",
    .hidden_dir_plural = "directoare",
    .hidden_file_singular = "fi\xc8\x99ier",
    .hidden_file_plural = "fi\xc8\x99iere",
    .hidden_and = " \xc8\x99i ",
    .hidden_is_hidden = " este ascuns.",
    .hidden_are_hidden = " sunt ascunse.",
    .stats_shown = " afișate",
    .stats_hidden = " ascunse.",
    .stats_line_singular = "linie",
    .stats_line_plural = "linii",
    .stats_separator = "; ",

    // ── Mesaje de eroare ──────────────────────────────────────
    .err_depth_requires_number = "Eroare: --depth necesit\xc4\x83 un argument numeric",
    .err_sort_requires_mode = "Eroare: --sort necesit\xc4\x83 'modified' sau 'alpha'",
    .err_default_requires_value = "Eroare: --default necesit\xc4\x83 cel pu\xc8\x9bin o valoare",
    .err_default_state_conflict = "Eroare: conflict de stare \xc3\xaen --default",
    .err_default_visibility_conflict = "Eroare: conflict de vizibilitate \xc3\xaen --default",
    .err_default_accepts = "Eroare: --default accept\xc4\x83 opened/closed/shown/hidden",
    .err_open_requires_dir = "Eroare: --open necesit\xc4\x83 cel pu\xc8\x9bin un director",
    .err_close_requires_dir = "Eroare: --close necesit\xc4\x83 cel pu\xc8\x9bin un director",
    .err_show_requires_path = "Eroare: --show necesit\xc4\x83 cel pu\xc8\x9bin o cale",
    .err_hide_requires_path = "Eroare: --hide necesit\xc4\x83 cel pu\xc8\x9bin o cale",
    .err_unknown_option = "Op\xc8\x9biune necunoscut\xc4\x83",
    .err_not_a_directory = "Eroare: '{s}' nu este un director",
    .err_regex_empty = "Eroare: pattern-ul regex nu trebuie s\xc4\x83 fie gol",
    .err_paths_must_be_relative = "Eroare: c\xc4\x83ile {s} trebuie s\xc4\x83 fie relative (f\xc4\x83r\xc4\x83 '/' ini\xc8\x9bial): {s}",
    .err_out_of_memory = "Memorie insuficient\xc4\x83",
    .err_regex_conflict_path = "Eroare: calea '{s}' corespunde at\xc3\xa2t pattern-ului open c\xc3\xa2t \xc8\x99i close",
    .err_regex_conflict_open = "  pattern open: {s}",
    .err_regex_conflict_close = "  pattern close: {s}",
    .err_unknown_lang = "Eroare: cod de limb\xc4\x83 necunoscut '{s}'. Disponibile: {s}",

    // ── Avertismente ──────────────────────────────────────────
    .warn_persist_state = "Avertisment: nu s-a putut persista starea: {}",

    // ── Mod test ──────────────────────────────────────────────
    .test_mode_msg = "Mod test: testele unitare Zig se ruleaz\xc4\x83 cu 'zig build test'",

    // ── Diverse ──────────────────────────────────────────────────
    .err_test_bin_run = "Eroare: nu s-a putut rula DIRTREE_TEST_BIN: {s}",
    .err_test_bin_wait = "Eroare: nu s-a putut a\xc8\x99tepta DIRTREE_TEST_BIN",
    .err_render_tree = "Eroare la renderizarea arborelui: {}",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--ajutor", .arg = .help },
        .{ .name = "--despre", .arg = .about },
        .{ .name = "--adancime", .arg = .depth },
        .{ .name = "--simplu", .arg = .simple },
        .{ .name = "--decorat", .arg = .decorated },
        .{ .name = "--fara-pictograme", .arg = .no_icons },
        .{ .name = "--fara-culoare", .arg = .no_color },
        .{ .name = "--fara-hiperlegaturi", .arg = .no_hyperlinks },
        .{ .name = "--implicit", .arg = .default },
        .{ .name = "--deschide", .arg = .open },
        .{ .name = "--inchide", .arg = .close },
        .{ .name = "--arata", .arg = .show },
        .{ .name = "--ascunde", .arg = .hide },
        .{ .name = "--sorteaza", .arg = .sort },
        .{ .name = "--crescator", .arg = .asc },
        .{ .name = "--descrescator", .arg = .desc },
        .{ .name = "--arata-ascunse", .arg = .show_hidden },
        .{ .name = "--rescrie-setari", .arg = .rewrite_settings },
        .{ .name = "--configuratie", .arg = .config },
                .{ .name = "--testeaza", .arg = .@"test" },
        .{ .name = "--limba", .arg = .lang },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "ARBORE_SIMPLU", .var_id = .dirtree_simple },
        .{ .name = "ARBORE_DECORAT", .var_id = .dirtree_decorated },
        .{ .name = "ARBORE_AUTO_SIMPLU", .var_id = .dirtree_auto_simple },
        .{ .name = "PIPED_STDOUT", .var_id = .piped_stdout },
        .{ .name = "ARBORE_SCM_MODIFICARI_ASCUNSE_SAU_INCHISE", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
