const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── Ederede enyemaka ───────────────────────────────────────
    .help_title = "dirtree - Osisi ndekọ nwere ọnọdụ maka mmadụ na LLMs",
    .help_usage = "Ojiji: dirtree [NHỌRỌ] [ỤZỌ]",
    .help_options_header = "Nhọrọ:",
    .help_opt_help = "  -h, --help         Gosi ozi enyemaka a",
    .help_opt_about = "  -a, --about        Gosi nkọwa zuru ezu",
    .help_opt_depth = "  -d, --depth N      Tọọ omimi kachasị (ndabara: 4)",
    .help_opt_temp = "  -t, --temp         Tinye mgbanwe maka ọsọ a naanị (echekwabeghị)",
    .help_opt_persist = "  --persist, --save  Chekwaa ntọala ndị a (na-ewepụ non-TTY na DIRTREE_TEMP)",
    .help_opt_path = "  -p, --path PATH    Gosi PATH ọ bụrụgodị na ọ dị ka ọkọlọtọ ma ọ bụ iwu obere",
    .help_opt_simple = "  --simple           Wepụta osisi dị mfe nke LLMs na-aghọta",
    .help_opt_decorated = "  --decorated        Manye mmepụta achọrọ mma (ọbụnadị mgbe ọ bụ pipe)",
    .help_opt_no_icons = "  --no-icons         Gbanyụọ akara (ụzọ dị mfe + isi achọrọ mma)",
    .help_opt_no_color = "  --no-color        Gbanye/gbanyụọ agba ANSI (echekwara)",
    .help_opt_no_orphan_warning = "  --no-orphan-warning Kwụsị ịdọ aka na ntị maka ndetu na-enweghị nne",
    .help_opt_notes = "  --no-notes/--show-notes Zoo ma ọ bụ gosi ndetu n'ime ahịrị (DIRTREE_HIDE_NOTES=1 iji zoo site na ndabara)",
    .help_opt_notes_mode = "  --notes MODE       Nhazi ndetu: aligned (ndabara) ma ọ bụ inline",
    .help_opt_notes_leader = "  --notes-leader     See ntụpọ ndu site na aha gaa na ndetu ahaziri ahazi",
    .warn_orphaned_prefix = "Ndetu: ",
    .warn_orphaned_suffix = " nkọwa na-ezo aka n'ụzọ ndị na-adịghị adị ọzọ. Gbaa 'orphaned-notes' iji lelee ma ọ bụ 'purge-orphaned-notes' iji wepụ.",
    .warn_negation_intro = "ndetu: regex emegidere ebe a nwere ike ịtụgharị ihe ị na-ekwu — !/PAT/ na-edaba na MMEGIDE, na (?!...) lookahead nke bu ụzọ bụkwa mmegide, yabụ ijikọta ha na-emepụta mmegide ugboro abụọ:",
    .warn_negation_advice = "Iji lekwasị anya n'otu ụzọ, họrọ {s} PATH; maka nyochaa ọma jiri {s} /PAT/ (iwu show nwere mkpa karịa hide). Iwu ndị a na-anọgide na .dirtree-state, nke bụ ederede doro anya ị nwere ike dezie aka mgbe ha mgbagwoju anya ma ọ bụ na-emekọrịta.",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   Gbanye/gbanyụọ njikọ OSC8 (echekwara)",
    .help_opt_default = "  --default X        Chekwaa ọnọdụ ndabara: opened|closed",
    .help_opt_open = "  -o, --open DIR...  Meghee otu ma ọ bụ karịa subdir (kwughachi ọkọlọtọ iji tinye ọzọ)",
    .help_opt_close = "  -c, --close DIR... Mechie otu ma ọ bụ karịa subdir (kwughachi ọkọlọtọ iji tinye ọzọ)",
    .help_opt_show = "  --show PATH...     Manye igosi ụzọ metụtara; kechie regex dị ka /pattern/ ma ọ bụ !/pattern/",
    .help_opt_hide = "  --hide PATH...     Zoo ụzọ metụtara; kechie regex dị ka /pattern/ ma ọ bụ !/pattern/ (a ga-emegharị ya) (ịchọrọ naanị ụfọdụ ụzọ? jiri --only)",
    .help_opt_sort = "  --sort MODE        Ụdị nhazi: modified|alpha (ndabara: modified)",
    .help_opt_asc = "  --asc              Hazie site n'ala gaa n'elu",
    .help_opt_desc = "  --desc             Hazie site n'elu gaa n'ala (ndabara)",
    .help_opt_show_hidden = "  --show-hidden      Gosi ụzọ ezoro ezo nwa oge site na nhazi",
    .help_opt_rewrite_settings = "  --rewrite-settings Degharịa faịlụ ọnọdụ site na nhazi ugbu a",
    .help_opt_config = "  --config           Gosi nhazi dị irè agbakọrọ",
    .help_opt_test = "  --test             Gbaa nnwale ndị metụtara",
    .help_opt_lang = "  --lang CODE        Tọọ asụsụ ngosi (dịka en, de, fr, ja)",
    .help_lang_available_label = "Koodu asụsụ ndị dị:",
    .help_regex_note = "Jiri /pattern/ ma ọ bụ !/pattern/ na --open/--close/--show/--hide iji tinye iwu regex; a na-emeso arụmụka ndị ọzọ dị ka mkpụrụokwu.",
    .help_relative_note = "Ụzọ enyere --show/--hide ga-abụrịrị nke metụtara (na-enweghị '/' n'ihu).",
    .help_behavior_header = "Omume:",
    .help_behavior_text = "A na-echekwa ntọala ngosi mgbe stdout bụ ọnụ; ma ọ bụghị ya, ha na-emetụta naanị maka oku ugbu a. Site na ndabara, a na-echekwa mgbanwe --open/--close/--show/--hide mgbe niile. Agba agbanyere na ndabara maka mmepụta ọnụ yana gbanyụọ maka mmepụta ọzọ. --temp ma ọ bụ --persist/--save na-emebi iwu nchekwa ndị a n'ụzọ doro anya.",
    .persistence_note_tty = "Ozi: {s}: echekwara n'ihi na stdout bụ ọnụ; jiri --temp tinye ya naanị na oku a.",
    .persistence_note_non_tty = "Ozi: {s}: echekwaghị ya n'ihi na stdout abụghị ọnụ; jiri --persist/--save kagbuo.",
    .persistence_note_semantic = "Ozi: {s}: echekwara n'ihi na a na-echekwa mgbanwe na nleba anya oru ngo na ndabara; jiri --temp tinye ha naanị na oku a.",
    .persistence_note_env = "Ozi: {s}: echekwaghị ya n'ihi na DIRTREE_TEMP=1; jiri --persist/--save kagbuo.",
    .persistence_note_mute = "Tọọ DIRTREE_MUTE_PERSISTENCE_REASON=1 ka ọ kwụsị ozi ozi a.",
    .help_examples_header = "Ihe atụ:",
    .help_example_1 = "  dirtree                       # Gosi osisi nke ndaka ugbu a",
    .help_example_2 = "  dirtree -d 3                  # Tọọ omimi na ọkwa 3",
    .help_example_3 = "  dirtree --sort alpha --asc    # Ahaziri n'usoro abịdịị site n'ala gaa n'elu",
    .help_example_close_comment = "Mechie ndaka (echekwara)",
    .help_example_hide_comment = "Zoo faịlụ dabara na regex",
    .help_example_only_comment = "Lekwasị anya n'otu subtree, zoo ụmụnne",
    .help_example_localized_comment = "Aha switch asụsụ obodo na-arụkwa ọrụ",

    // ── Ederede gbasara ────────────────────────────────────────
    .about_text = "Osisi ndaka nwere ọnọdụ (akara/agba/njikọ); --simple maka LLMs; na-echekwa .dirtree-state (default/open/close/show/hide); regex site na /pattern/ ma ọ bụ !/pattern/; ihe obere ga-abụrịrị nke metụtara; env: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── Mpempe ọnụọgụ ezoro ezo ────────────────────────────────
    .hidden_dir_singular = "ndaka",
    .hidden_dir_plural = "ndaka",
    .hidden_file_singular = "faịlụ",
    .hidden_file_plural = "faịlụ",
    .hidden_and = " na ",
    .hidden_is_hidden = " ezoro ezo.",
    .hidden_are_hidden = " ezoro ezo.",
    .stats_shown = " egosiri",
    .stats_hidden = " ezoro ezo.",
    .stats_line_singular = "ahịrị",
    .stats_line_plural = "ahịrị",
    .stats_separator = "; ",

    .stats_scm_kept = " ezoghị ezo n'ihi itinye ya na changeset git/jj ugbu a",
    // ── Ederede enyemaka (ọkọlọtọ ọhụrụ) ───────────────────────
    .help_opt_max_lines = "  --max-lines N      Tọọ oke ịdọ aka na ntị maka nnukwu mmepụta (ndabara: 500)",
    .help_opt_override_warning = "  --override-warning Kwụsị ịdọ aka na ntị maka nnukwu mmepụta",
    .help_opt_only = "  --only PATH        Lekwasị anya n'otu subtree, na-emechi ndaka ụmụnne (a ga-emegharị ya)",
    .help_opt_html = "  --html [FILE]      Dee osisi HTML kwụ onwe ya na FILE (- = stdout; hapụ = mepee na ihe nchọgharị)",
    .help_opt_no_targets = "  --no-symlink-targets/--no-targets  Zoo ebumnuche symlink; --no-targets na-ewepụkwa njikọ (mmepụta enwere ike ibu)",

    // ── Ozi ịdọ aka na ntị (nnukwu mmepụta) ────────────────────
    .warn_large_output_prefix = "Ịdọ aka na ntị: mmepụta dị ihe dịka ~",
    .warn_large_output_mid = " ahịrị (oke: ",
    .warn_large_output_suffix = "). Tụlee: --depth N ma ọ bụ ụkpụrụ --hide.",

    // ── Ozi njehie ─────────────────────────────────────────────
    .err_max_lines_requires_number = "Njehie: --max-lines chọrọ arụmụka ọnụọgụgụ (en: Error: --max-lines requires a numeric argument)",
    .err_only_requires_path = "Njehie: --only chọrọ arụmụka ụzọ (en: Error: --only requires a path argument)",
    .err_depth_requires_number = "Njehie: --depth chọrọ arụmụka ọnụọgụgụ (en: Error: --depth requires a numeric argument)",
    .err_path_requires_arg = "Njehie: --path chọrọ arụmụka ndaka (en: Error: --path requires a directory argument)",
    .err_notes_requires_mode = "Njehie: --notes chọrọ 'aligned' ma ọ bụ 'inline' (en: Error: --notes requires 'aligned' or 'inline')",
    .err_sort_requires_mode = "Njehie: --sort chọrọ 'modified' ma ọ bụ 'alpha' (en: Error: --sort requires 'modified' or 'alpha')",
    .err_default_requires_value = "Njehie: --default chọrọ opekata mpe otu uru (en: Error: --default requires at least one value)",
    .err_default_state_conflict = "Njehie: esemokwu ọnọdụ --default (en: Error: --default state conflict)",
    .err_default_accepts = "Njehie: --default na-anabata opened/closed (en: Error: --default accepts opened/closed)",
    .err_open_requires_dir = "Njehie: --open chọrọ opekata mpe otu ndaka (en: Error: --open requires at least one directory)",
    .err_close_requires_dir = "Njehie: --close chọrọ opekata mpe otu ndaka (en: Error: --close requires at least one directory)",
    .err_show_requires_path = "Njehie: --show chọrọ opekata mpe otu ụzọ (en: Error: --show requires at least one path)",
    .err_hide_requires_path = "Njehie: --hide chọrọ opekata mpe otu ụzọ (en: Error: --hide requires at least one path)",
    .err_unknown_option = "Nhọrọ amaghị (en: Unknown option)",
    .err_not_a_directory = "Njehie: '{s}' abụghị ndaka (en: Error: '{s}' is not a directory)",
    .err_regex_empty = "Njehie: ụkpụrụ regex agaghị abụ ihe efu (en: Error: regex pattern must not be empty)",
    .err_paths_must_be_relative = "Njehie: ụzọ {s} ga-abụrịrị nke metụtara (na-enweghị '/' n'ihu): {s} (en: Error: {s} paths must be relative (no leading '/'): {s})",
    .err_out_of_memory = "Ebe nchekwa agwụla (en: Out of memory)",
    .err_regex_conflict_path = "Njehie: ụzọ '{s}' dabara n'ụkpụrụ open na close abụọ (en: Error: path '{s}' matches both open and close patterns)",
    .err_regex_conflict_open = "  ụkpụrụ open: {s} (en:   open pattern: {s})",
    .err_regex_conflict_close = "  ụkpụrụ close: {s} (en:   close pattern: {s})",
    .err_regex_invalid = "Njehie: ụkpụrụ regex ezighị ezi: {s} (en: Error: invalid regex pattern: {s})",
    .err_unknown_lang = "Njehie: koodu asụsụ amaghị '{s}'. Ndị dị: {s} (en: Error: unknown language code '{s}'. Available: {s})",
    .err_annotate_requires_path = "Njehie: annotate chọrọ ụzọ (en: Error: annotate requires a path)",
    .err_annotate_requires_description = "Njehie: annotate chọrọ nkọwa (jiri \"\" iji hichapụ) (en: Error: annotate requires a description (use \"\" to clear))",
    .err_annotate_multiline = "Njehie: nkọwa annotate ga-abụrịrị otu ahịrị (en: Error: annotation description must be a single line)",
    .err_annotate_too_many_args = "Njehie: annotate na-anabata kpọmkwem arụmụka abụọ: <path> <description> (en: Error: annotate accepts exactly two positional arguments: <path> <description>)",
    .help_opt_annotate = "  annotate PATH DESC Chekwaa ndetu otu ahịrị gbasara faịlụ ma ọ bụ ndaka (aha ọzọ: note; DESC efu na-ehichapụ)",
    .help_opt_orphaned_notes = "  orphaned-notes [DIR] Depụta ndetu ndị ụzọ ebumnuche ha na-adịghị adị ọzọ",
    .help_opt_purge_orphaned_notes = "  purge-orphaned-notes [DIR] Wepụ ndetu ndị ụzọ ebumnuche ha na-adịghị adị ọzọ",
    .help_subcommands =
    \\<annotate>
    \\Ojiji: dirtree annotate PATH DESC
    \\       dirtree note PATH DESC          (aha ọzọ)
    \\
    \\Chekwaa ndetu otu ahịrị gbasara faịlụ ma ọ bụ ndaka. A na-echekwa ndetu ahụ na
    \\.dirtree-state, a ga-egosikwa ya n'akụkụ PATH oge ọzọ a ga-egosi osisi ahụ.
    \\
    \\Arụmụka:
    \\  PATH   faịlụ ma ọ bụ ndaka, nke metụtara ndaka ugbu a
    \\  DESC   ederede ndetu ahụ; nyefee eriri efu "" iji hichapụ ndetu dị adị
    \\
    \\Ihe atụ:
    \\  dirtree annotate src/main.zig "ọnụ ụzọ mbata CLI"
    \\  dirtree note docs "ndetu imewe dị ebe a"
    \\  dirtree annotate README.md ""        # hichapụ ndetu dị na README.md
    \\</annotate>
    \\<orphaned_notes>
    \\Ojiji: dirtree orphaned-notes [DIR]
    \\
    \\Depụta ndetu ndị ụzọ ebumnuche ha na-adịghị adị ọzọ — dịka mgbe a gbanwere aha
    \\faịlụ, bugharịa ya, ma ọ bụ hichapụ ya. DIR na-abụ ndaka ugbu a site na ndabara.
    \\Nke a bụ ọgụgụ naanị: ọ dịghị ihe a na-agbanwe. Jiri purge-orphaned-notes iji wepụ ha.
    \\
    \\Ihe atụ:
    \\  dirtree orphaned-notes
    \\  dirtree orphaned-notes src
    \\</orphaned_notes>
    \\<purge_orphaned_notes>
    \\Ojiji: dirtree purge-orphaned-notes [DIR]
    \\
    \\Wepụ ndetu ndị ụzọ ebumnuche ha na-adịghị adị ọzọ. DIR na-abụ ndaka ugbu a site na
    \\ndabara. Buru ụzọ gbaa orphaned-notes iji hụ kpọmkwem ihe a ga-ewepụ.
    \\
    \\Ihe atụ:
    \\  dirtree purge-orphaned-notes
    \\  dirtree purge-orphaned-notes src
    \\</purge_orphaned_notes>
    ,
    .orphaned_header = "Ndetu na-enweghị nne (ụzọ ndị na-adịghị adị ọzọ):",
    .orphaned_none = "Enweghị ndetu na-enweghị nne.",
    .purge_header = "Ehichapụrụ ndetu na-enweghị nne:",
    .purge_none = "Enweghị ndetu na-enweghị nne iji hichapụ.",
    .help_opt_version = "  --version          Gosi ụdị (na-anọghị n'ịntanetị; na-agụ ọkwa nkwado ọhụrụ echekwara)",
    .help_opt_version_check = "  --version-check    Manye nlele ọhụrụ n'ịntanetị megide API mwepụta GitHub",

    // ── Ozi ịdọ aka na ntị ─────────────────────────────────────
    .warn_persist_state = "Ịdọ aka na ntị: enweghị ike chekwaa ọnọdụ: {}",

    // ── Ọnọdụ nnwale ───────────────────────────────────────────
    .test_mode_msg = "Ọnọdụ nnwale: ịgba nnwale unit zig na-eme site na 'zig build test'",

    // ── Ihe ndị ọzọ ────────────────────────────────────────────
    .err_test_bin_run = "Njehie: enweghị ike ịgba DIRTREE_TEST_BIN: {s} (en: Error: could not run DIRTREE_TEST_BIN: {s})",
    .err_test_bin_wait = "Njehie: enweghị ike ichere DIRTREE_TEST_BIN (en: Error: could not wait for DIRTREE_TEST_BIN)",
    .err_render_tree = "Njehie n'ịwepụta osisi: {} (en: Error rendering tree: {})",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--enyemaka", .arg = .help },
        .{ .name = "--gbasara", .arg = .about },
        .{ .name = "--omimi", .arg = .depth },
        .{ .name = "--uzo", .arg = .path },
        .{ .name = "--di-mfe", .arg = .simple },
        .{ .name = "--achoro-mma", .arg = .decorated },
        .{ .name = "--enweghi-akara", .arg = .no_icons },
        .{ .name = "--enweghi-agba", .arg = .no_color },
        .{ .name = "--agba", .arg = .color },
        .{ .name = "--enweghi-ido-aka-na-nti", .arg = .no_orphan_warning },
        .{ .name = "--enweghi-ndetu", .arg = .no_notes },
        .{ .name = "--gosi-ndetu", .arg = .show_notes },
        .{ .name = "--ndetu", .arg = .notes },
        .{ .name = "--ndetu-ndu", .arg = .note_leader },
        .{ .name = "--enweghi-njiko", .arg = .no_hyperlinks },
        .{ .name = "--njiko", .arg = .hyperlinks },
        .{ .name = "--ndabara", .arg = .default },
        .{ .name = "--meghee", .arg = .open },
        .{ .name = "--mechie", .arg = .close },
        .{ .name = "--gosi", .arg = .show },
        .{ .name = "--zoo", .arg = .hide },
        .{ .name = "--hazie", .arg = .sort },
        .{ .name = "--rigoro", .arg = .asc },
        .{ .name = "--ridata", .arg = .desc },
        .{ .name = "--gosi-ezoro-ezo", .arg = .show_hidden },
        .{ .name = "--degharia-nhazi", .arg = .rewrite_settings },
        .{ .name = "--nhazi", .arg = .config },
        .{ .name = "--nnwale", .arg = .@"test" },
        .{ .name = "--asusu", .arg = .lang },
        .{ .name = "--nwa-oge", .arg = .temporary },
        .{ .name = "ndetu", .arg = .annotate },
        .{ .name = "ndetu-na-enweghi-nne", .arg = .orphaned_notes },
        .{ .name = "hichapu-ndetu-na-enweghi-nne", .arg = .purge_orphaned_notes },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "DIRTREE_DI_MFE", .var_id = .dirtree_simple },
        .{ .name = "DIRTREE_ACHORO_MMA", .var_id = .dirtree_decorated },
        .{ .name = "DIRTREE_AKPAAKA_DI_MFE", .var_id = .dirtree_auto_simple },
        .{ .name = "PIPE_STDOUT", .var_id = .piped_stdout },
        .{ .name = "DIRTREE_ZOO_NDETU", .var_id = .dirtree_hide_notes },
        .{ .name = "DIRTREE_MGBANWE_SCM_NA_EZO_MA_OBU_MECHIE", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
