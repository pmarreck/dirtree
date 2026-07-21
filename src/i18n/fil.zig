const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── Teksto ng tulong ───────────────────────────────────────
    .help_title = "dirtree - Stateful na directory tree para sa mga tao at LLM",
    .help_usage = "Paggamit: dirtree [MGA OPSYON] [PATH]",
    .help_options_header = "Mga opsyon:",
    .help_opt_help = "  -h, --help         Ipakita ang mensaheng ito ng tulong",
    .help_opt_about = "  -a, --about        Ipakita ang detalyadong paglalarawan",
    .help_opt_depth = "  -d, --depth N      Itakda ang maximum na lalim (default: 4)",
    .help_opt_temp = "  -t, --temp         Ilapat ang mga pagbabago para sa pagtakbong ito lang (hindi nai-save)",
    .help_opt_path = "  -p, --path PATH    I-render ang PATH kahit mukha itong flag o subcommand",
    .help_opt_simple = "  --simple           Maglabas ng simple, LLM-friendly na stateful tree",
    .help_opt_decorated = "  --decorated        Pilitin ang dekoradong output (kahit naka-pipe)",
    .help_opt_no_icons = "  --no-icons         Huwag paganahin ang mga icon (simple mode + dekoradong header)",
    .help_opt_no_color = "  --no-color        I-enable/i-disable ang mga kulay ANSI (naka-save)",
    .help_opt_no_orphan_warning = "  --no-orphan-warning Pigilan ang babala tungkol sa orphaned na mga nota",
    .help_opt_notes = "  --no-notes/--show-notes Itago o ipakita ang mga inline na nota (DIRTREE_HIDE_NOTES=1 para itago bilang default)",
    .help_opt_notes_mode = "  --notes MODE       Layout ng nota: aligned (default) o inline",
    .help_opt_notes_leader = "  --notes-leader     Gumuhit ng malabong tuldok mula sa pangalan papunta sa nakahanay na nota",
    .warn_orphaned_prefix = "Paalala: ",
    .warn_orphaned_suffix = " na anotasyon ay tumuturo sa mga path na wala na. Patakbuhin ang 'orphaned-notes' upang tingnan o 'purge-orphaned-notes' upang alisin.",
    .warn_negation_intro = "paalala: ang isang negated na regex dito ay maaaring baligtarin ang ibig mong sabihin — ang !/PAT/ ay tumutugma sa KABALIGTARAN, at ang nangungunang (?!...) lookahead ay negasyon din, kaya kapag pinagsama ay dobleng negasyon:",
    .warn_negation_advice = "Upang magpokus sa isang path, mas mainam ang {s} PATH; para sa positibong filter gamitin ang {s} /PAT/ (ang mga show na patakaran ay nangunguna sa hide). Ang mga patakarang ito ay nananatili sa .dirtree-state, isang plain text na maaari mong i-edit nang manu-mano kapag naging kumplikado o nag-overlap ang mga ito.",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   I-enable/i-disable ang mga OSC8 hyperlink (naka-save)",
    .help_opt_default = "  --default X        I-save ang default na estado: opened|closed",
    .help_opt_open = "  -o, --open DIR...  Buksan ang isa o higit pang subdir (ulitin ang flag para magdagdag)",
    .help_opt_close = "  -c, --close DIR... Isara ang isa o higit pang subdir (ulitin ang flag para magdagdag)",
    .help_opt_show = "  --show PATH...     Piliting ipakita ang mga relative na path; balutin ang regex bilang /pattern/ o !/pattern/",
    .help_opt_hide = "  --hide PATH...     Itago ang mga relative na path; balutin ang regex bilang /pattern/ o !/pattern/ (maaaring ulitin) (ilang path lang ang panatilihin? gamitin ang --only)",
    .help_opt_sort = "  --sort MODE        Mode ng pag-uri: modified|alpha (default: modified)",
    .help_opt_asc = "  --asc              Pataas na pag-uri",
    .help_opt_desc = "  --desc             Pababang pag-uri (default)",
    .help_opt_show_hidden = "  --show-hidden      Pansamantalang ipakita ang mga path na nakatago sa pamamagitan ng config",
    .help_opt_rewrite_settings = "  --rewrite-settings Muling isulat ang state file gamit ang kasalukuyang mga setting",
    .help_opt_config = "  --config           Ipakita ang kinalkulang epektibong configuration",
    .help_opt_test = "  --test             Patakbuhin ang mga kaugnay na test",
    .help_opt_lang = "  --lang CODE        Itakda ang wika ng display (hal. en, de, fr, ja)",
    .help_lang_available_label = "Mga available na code ng wika:",
    .help_regex_note = "Gamitin ang /pattern/ o !/pattern/ kasama ang --open/--close/--show/--hide upang magdagdag ng mga regex na patakaran; ang ibang argumento ay itinuturing na literal.",
    .help_relative_note = "Ang mga path na ibinibigay sa --show/--hide ay dapat relative (walang nangungunang '/').",
    .help_behavior_header = "Pag-uugali:",
    .help_behavior_text = "Bilang default, kapag ang stdout ay hindi TTY (naka-pipe), ang mga kulay/icon/hyperlink ay hindi pinagana maliban kung ibinigay ang --decorated.",
    .help_examples_header = "Mga halimbawa:",
    .help_example_1 = "  dirtree                       # Ipakita ang tree ng kasalukuyang directory",
    .help_example_2 = "  dirtree -d 3                  # Itakda ang lalim sa 3 antas",
    .help_example_3 = "  dirtree --sort alpha --asc    # Inuri ayon sa alpabeto nang pataas",
    .help_example_close_comment = "Tiklupin ang isang directory (nananatili)",
    .help_example_hide_comment = "Itago ang mga file na tumutugma sa regex",
    .help_example_only_comment = "Magpokus sa isang subtree, itago ang mga kapatid",
    .help_example_localized_comment = "Gumagana rin ang mga localized na pangalan ng switch",

    // ── Teksto ng tungkol ──────────────────────────────────────
    .about_text = "Stateful na directory tree (mga icon/kulay/link); --simple para sa mga LLM; nananatili sa .dirtree-state (default/open/close/show/hide); regex sa pamamagitan ng /pattern/ o !/pattern/; ang mga literal ay dapat relative; env: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── Mga bahagi ng bilang ng nakatago ───────────────────────
    .hidden_dir_singular = "directory",
    .hidden_dir_plural = "mga directory",
    .hidden_file_singular = "file",
    .hidden_file_plural = "mga file",
    .hidden_and = " at ",
    .hidden_is_hidden = " ay nakatago.",
    .hidden_are_hidden = " ay nakatago.",
    .stats_shown = " ipinakita",
    .stats_hidden = " nakatago.",
    .stats_line_singular = "linya",
    .stats_line_plural = "mga linya",
    .stats_separator = "; ",

    .stats_scm_kept = " hindi itinago dahil kasama sa kasalukuyang git/jj na changeset",
    // ── Teksto ng tulong (mga bagong flag) ─────────────────────
    .help_opt_max_lines = "  --max-lines N      Itakda ang threshold ng babala para sa malaking output (default: 500)",
    .help_opt_override_warning = "  --override-warning Pigilan ang babala para sa malaking output",
    .help_opt_only = "  --only PATH        Magpokus sa isang subtree, tinitiklop ang mga kapatid na directory (maaaring ulitin)",
    .help_opt_html = "  --html [FILE]      Isulat ang standalone na HTML tree sa FILE (- = stdout; laktawan = buksan sa browser)",
    .help_opt_no_targets = "  --no-symlink-targets/--no-targets  Itago ang mga target ng symlink; --no-targets nag-aalis din ng hyperlink (portable na output)",


    // ── Mga mensahe ng babala (malaking output) ────────────────
    .warn_large_output_prefix = "Babala: ang output ay humigit-kumulang ~",
    .warn_large_output_mid = " na linya (threshold: ",
    .warn_large_output_suffix = "). Isaalang-alang: --depth N o --hide na mga pattern.",

    // ── Mga mensahe ng error ───────────────────────────────────
    .err_max_lines_requires_number = "Error: ang --max-lines ay nangangailangan ng numerong argumento (en: Error: --max-lines requires a numeric argument)",
    .err_only_requires_path = "Error: ang --only ay nangangailangan ng argumentong path (en: Error: --only requires a path argument)",
    .err_depth_requires_number = "Error: ang --depth ay nangangailangan ng numerong argumento (en: Error: --depth requires a numeric argument)",
    .err_path_requires_arg = "Error: ang --path ay nangangailangan ng argumentong directory (en: Error: --path requires a directory argument)",
    .err_notes_requires_mode = "Error: ang --notes ay nangangailangan ng 'aligned' o 'inline' (en: Error: --notes requires 'aligned' or 'inline')",
    .err_sort_requires_mode = "Error: ang --sort ay nangangailangan ng 'modified' o 'alpha' (en: Error: --sort requires 'modified' or 'alpha')",
    .err_default_requires_value = "Error: ang --default ay nangangailangan ng kahit isang halaga (en: Error: --default requires at least one value)",
    .err_default_state_conflict = "Error: salungatan sa estado ng --default (en: Error: --default state conflict)",
    .err_default_accepts = "Error: ang --default ay tumatanggap ng opened/closed (en: Error: --default accepts opened/closed)",
    .err_open_requires_dir = "Error: ang --open ay nangangailangan ng kahit isang directory (en: Error: --open requires at least one directory)",
    .err_close_requires_dir = "Error: ang --close ay nangangailangan ng kahit isang directory (en: Error: --close requires at least one directory)",
    .err_show_requires_path = "Error: ang --show ay nangangailangan ng kahit isang path (en: Error: --show requires at least one path)",
    .err_hide_requires_path = "Error: ang --hide ay nangangailangan ng kahit isang path (en: Error: --hide requires at least one path)",
    .err_unknown_option = "Hindi kilalang opsyon (en: Unknown option)",
    .err_not_a_directory = "Error: ang '{s}' ay hindi isang directory (en: Error: '{s}' is not a directory)",
    .err_regex_empty = "Error: ang regex pattern ay hindi dapat walang laman (en: Error: regex pattern must not be empty)",
    .err_paths_must_be_relative = "Error: ang mga {s} na path ay dapat relative (walang nangungunang '/'): {s} (en: Error: {s} paths must be relative (no leading '/'): {s})",
    .err_out_of_memory = "Naubusan ng memorya (en: Out of memory)",
    .err_regex_conflict_path = "Error: ang path na '{s}' ay tumutugma sa parehong open at close na pattern (en: Error: path '{s}' matches both open and close patterns)",
    .err_regex_conflict_open = "  open na pattern: {s} (en:   open pattern: {s})",
    .err_regex_conflict_close = "  close na pattern: {s} (en:   close pattern: {s})",
    .err_regex_invalid = "Error: hindi wastong regex pattern: {s} (en: Error: invalid regex pattern: {s})",
    .err_unknown_lang = "Error: hindi kilalang code ng wika '{s}'. Available: {s} (en: Error: unknown language code '{s}'. Available: {s})",
    .err_annotate_requires_path = "Error: ang annotate ay nangangailangan ng path (en: Error: annotate requires a path)",
    .err_annotate_requires_description = "Error: ang annotate ay nangangailangan ng paglalarawan (gamitin ang \"\" upang i-clear) (en: Error: annotate requires a description (use \"\" to clear))",
    .err_annotate_multiline = "Error: ang paglalarawan ng anotasyon ay dapat isang linya lamang (en: Error: annotation description must be a single line)",
    .err_annotate_too_many_args = "Error: ang annotate ay tumatanggap ng eksaktong dalawang positional na argumento: <path> <description> (en: Error: annotate accepts exactly two positional arguments: <path> <description>)",
    .help_opt_annotate = "  annotate PATH DESC Mag-save ng isang-linyang nota tungkol sa file o directory (alias: note; ang walang-laman na DESC ay nagke-clear)",
    .help_opt_orphaned_notes = "  orphaned-notes [DIR] Ilista ang mga nota na ang target na path ay wala na",
    .help_opt_purge_orphaned_notes = "  purge-orphaned-notes [DIR] Alisin ang mga nota na ang target na path ay wala na",
    .help_subcommands =
    \\<annotate>
    \\Paggamit: dirtree annotate PATH DESC
    \\          dirtree note PATH DESC          (alias)
    \\
    \\Mag-save ng isang-linyang nota tungkol sa isang file o directory. Ang nota ay iniimbak sa
    \\.dirtree-state at ipinapakita katabi ng PATH sa susunod na beses na i-render ang tree.
    \\
    \\Mga argumento:
    \\  PATH   file o directory, relative sa kasalukuyang directory
    \\  DESC   ang teksto ng nota; magpasa ng walang-lamang string "" upang i-clear ang umiiral na nota
    \\
    \\Mga halimbawa:
    \\  dirtree annotate src/main.zig "entry point ng CLI"
    \\  dirtree note docs "narito ang mga design note"
    \\  dirtree annotate README.md ""        # i-clear ang nota sa README.md
    \\</annotate>
    \\<orphaned_notes>
    \\Paggamit: dirtree orphaned-notes [DIR]
    \\
    \\Ilista ang mga nota na ang target na path ay wala na — halimbawa matapos na ang isang
    \\file ay pinalitan ng pangalan, inilipat, o tinanggal. Ang DIR ay default sa kasalukuyang directory.
    \\Ito ay read-only: walang binabago. Gamitin ang purge-orphaned-notes upang alisin ang mga ito.
    \\
    \\Mga halimbawa:
    \\  dirtree orphaned-notes
    \\  dirtree orphaned-notes src
    \\</orphaned_notes>
    \\<purge_orphaned_notes>
    \\Paggamit: dirtree purge-orphaned-notes [DIR]
    \\
    \\Alisin ang mga nota na ang target na path ay wala na. Ang DIR ay default sa
    \\kasalukuyang directory. Patakbuhin muna ang orphaned-notes upang i-preview nang eksakto kung ano ang
    \\aalisin.
    \\
    \\Mga halimbawa:
    \\  dirtree purge-orphaned-notes
    \\  dirtree purge-orphaned-notes src
    \\</purge_orphaned_notes>
    ,
    .orphaned_header = "Mga orphaned na nota (mga path na wala na):",
    .orphaned_none = "Walang orphaned na nota.",
    .purge_header = "Mga orphaned na nota na inalis:",
    .purge_none = "Walang orphaned na nota na aalisin.",
    .help_opt_version = "  --version          Ipakita ang bersyon (offline; binabasa ang naka-cache na abiso ng update-available)",
    .help_opt_version_check = "  --version-check    Pilitin ang sariwang online na pagsusuri laban sa GitHub releases API",

    // ── Mga mensahe ng babala ──────────────────────────────────
    .warn_persist_state = "Babala: hindi ma-save ang estado: {} (en: Warning: could not persist state: {})",

    // ── Test mode ──────────────────────────────────────────────
    .test_mode_msg = "Test mode: ang pagpapatakbo ng mga zig unit test ay ginagawa sa pamamagitan ng 'zig build test'",

    // ── Iba pa ─────────────────────────────────────────────────
    .err_test_bin_run = "Error: hindi mapatakbo ang DIRTREE_TEST_BIN: {s} (en: Error: could not run DIRTREE_TEST_BIN: {s})",
    .err_test_bin_wait = "Error: hindi makapaghintay para sa DIRTREE_TEST_BIN (en: Error: could not wait for DIRTREE_TEST_BIN)",
    .err_render_tree = "Error sa pag-render ng tree: {} (en: Error rendering tree: {})",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--tulong", .arg = .help },
        .{ .name = "--tungkol", .arg = .about },
        .{ .name = "--lalim", .arg = .depth },
        .{ .name = "--landas", .arg = .path },
        .{ .name = "--simple-na", .arg = .simple },
        .{ .name = "--dekorado", .arg = .decorated },
        .{ .name = "--walang-icon", .arg = .no_icons },
        .{ .name = "--walang-kulay", .arg = .no_color },
        .{ .name = "--kulay", .arg = .color },
        .{ .name = "--walang-babala-orphan", .arg = .no_orphan_warning },
        .{ .name = "--walang-nota", .arg = .no_notes },
        .{ .name = "--ipakita-nota", .arg = .show_notes },
        .{ .name = "--ayos-nota", .arg = .notes },
        .{ .name = "--gabay-nota", .arg = .note_leader },
        .{ .name = "--walang-hyperlink", .arg = .no_hyperlinks },
        .{ .name = "--link", .arg = .hyperlinks },
        .{ .name = "--likas", .arg = .default },
        .{ .name = "--buksan", .arg = .open },
        .{ .name = "--isara", .arg = .close },
        .{ .name = "--ipakita", .arg = .show },
        .{ .name = "--itago", .arg = .hide },
        .{ .name = "--uri", .arg = .sort },
        .{ .name = "--pataas", .arg = .asc },
        .{ .name = "--pababa", .arg = .desc },
        .{ .name = "--ipakita-nakatago", .arg = .show_hidden },
        .{ .name = "--isulat-muli-setting", .arg = .rewrite_settings },
        .{ .name = "--kumpigurasyon", .arg = .config },
        .{ .name = "--subukan", .arg = .@"test" },
        .{ .name = "--wika", .arg = .lang },
        .{ .name = "--pansamantala", .arg = .temporary },
        .{ .name = "--isang", .arg = .only },
        .{ .name = "tala", .arg = .annotate },
        .{ .name = "nota-na-ulila", .arg = .orphaned_notes },
        .{ .name = "linisin-nota-na-ulila", .arg = .purge_orphaned_notes },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "DIRTREE_SIMPLE", .var_id = .dirtree_simple },
        .{ .name = "DIRTREE_DEKORADO", .var_id = .dirtree_decorated },
        .{ .name = "DIRTREE_AWTO_SIMPLE", .var_id = .dirtree_auto_simple },
        .{ .name = "NAKA_PIPE_STDOUT", .var_id = .piped_stdout },
        .{ .name = "DIRTREE_ITAGO_NOTA", .var_id = .dirtree_hide_notes },
        .{ .name = "DIRTREE_SCM_PAGBABAGO_MANATILING_NAKATAGO_O_SARADO", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
