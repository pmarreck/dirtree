const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── Maandishi ya msaada ────────────────────────────────────
    .help_title = "dirtree - Miti ya saraka yenye hali kwa binadamu na LLM",
    .help_usage = "Matumizi: dirtree [CHAGUO] [NJIA]",
    .help_options_header = "Chaguo:",
    .help_opt_help = "  -h, --help         Onyesha ujumbe huu wa msaada",
    .help_opt_about = "  -a, --about        Onyesha maelezo ya kina",
    .help_opt_depth = "  -d, --depth N      Weka kina cha juu zaidi (chaguo-msingi: 4)",
    .help_opt_temp = "  -t, --temp         Tumia mabadiliko kwa mhutuko huu pekee (haihifadhiwi)",
    .help_opt_persist = "  --persist, --save  Hifadhi mipangilio hii pia (inabatilisha non-TTY na DIRTREE_TEMP)",
    .help_opt_path = "  -p, --path PATH    Onyesha PATH hata kama inaonekana kama bendera au amri ndogo",
    .help_opt_simple = "  --simple           Toa mti rahisi wenye hali unaofaa kwa LLM",
    .help_opt_decorated = "  --decorated        Lazimisha matokeo yaliyopambwa (hata yanapopitishwa)",
    .help_opt_no_icons = "  --no-icons         Zima ikoni (hali rahisi + kichwa kilichopambwa)",
    .help_opt_no_color = "  --no-color        Washa/zima rangi za ANSI (huhifadhiwa)",
    .help_opt_no_orphan_warning = "  --no-orphan-warning Zuia onyo la orphaned-notes",
    .help_opt_notes = "  --no-notes/--show-notes Ficha au onyesha madokezo ya ndani (DIRTREE_HIDE_NOTES=1 kuficha kwa chaguo-msingi)",
    .help_opt_notes_mode = "  --notes MODE       Mpangilio wa dokezo: aligned (chaguo-msingi) au inline",
    .help_opt_notes_leader = "  --notes-leader     Chora nukta hafifu za uongozi kutoka majina hadi madokezo yaliyolingana",
    .warn_orphaned_prefix = "Kumbuka: ",
    .warn_orphaned_suffix = " maelezo yanaelekeza kwenye njia ambazo hazipo tena. Endesha 'orphaned-notes' kuyaona au 'purge-orphaned-notes' kuyaondoa.",
    .warn_negation_intro = "kumbuka: regex iliyokanushwa hapa inaweza kupindua maana yako — !/PAT/ inalingana na KINYUME, na lookahead inayoanza na (?!...) pia ni ukanushaji, kwa hivyo kuziunganisha kunakanusha mara mbili:",
    .warn_negation_advice = "Ili kuzingatia njia moja, tumia {s} PATH; kwa kichujio chanya tumia {s} /PAT/ (kanuni za show zina kipaumbele juu ya hide). Kanuni hizi huhifadhiwa kwenye .dirtree-state, ambayo ni maandishi sahili unayoweza kuhariri kwa mkono yanapokuwa changamano au yanayoingiliana.",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   Washa/zima viungo vya OSC8 (huhifadhiwa)",
    .help_opt_default = "  --default X        Hifadhi hali chaguo-msingi: opened|closed",
    .help_opt_open = "  -o, --open DIR...  Fungua saraka ndogo moja au zaidi (rudia bendera kuongeza zaidi)",
    .help_opt_close = "  -c, --close DIR... Funga saraka ndogo moja au zaidi (rudia bendera kuongeza zaidi)",
    .help_opt_show = "  --show PATH...     Lazimisha kuonyesha njia za jamaa; funga regex kama /pattern/ au !/pattern/",
    .help_opt_hide = "  --hide PATH...     Ficha njia za jamaa; funga regex kama /pattern/ au !/pattern/ (inarudiwa) (unataka kubaki na njia chache tu? tumia --only)",
    .help_opt_sort = "  --sort MODE        Hali ya kupanga: modified|alpha (chaguo-msingi: modified)",
    .help_opt_asc = "  --asc              Panga kupanda",
    .help_opt_desc = "  --desc             Panga kushuka (chaguo-msingi)",
    .help_opt_show_hidden = "  --show-hidden      Onyesha kwa muda njia zilizofichwa kupitia usanidi",
    .help_opt_rewrite_settings = "  --rewrite-settings Andika upya faili la hali kwa kutumia mipangilio ya sasa",
    .help_opt_config = "  --config           Onyesha usanidi halisi uliokokotolewa",
    .help_opt_test = "  --test             Endesha majaribio yanayohusiana",
    .help_opt_lang = "  --lang CODE        Weka lugha ya kuonyesha (k.m. en, de, fr, ja)",
    .help_lang_available_label = "Misimbo ya lugha inayopatikana:",
    .help_regex_note = "Tumia /pattern/ au !/pattern/ pamoja na --open/--close/--show/--hide kuongeza kanuni za regex; hoja nyingine huchukuliwa kama herufi halisi.",
    .help_relative_note = "Njia zinazotolewa kwa --show/--hide lazima ziwe za jamaa (bila '/' ya kuanzia).",
    .help_behavior_header = "Tabia:",
    .help_behavior_text = "Mipangilio ya wasilisho huhifadhiwa wakati stdout ni terminal; vinginevyo yanatumika tu kwa ombi la sasa. Kwa chaguo-msingi, mabadiliko ya --open/--close/--show/--hide huhifadhiwa kila wakati. Rangi huwashwa kwa chaguo-msingi kwa pato la mwisho na kuzima kwa pato lingine. --temp au --persist/--save inabatilisha kwa uwazi sheria hizi za kuokoa.",
    .persistence_note_tty = "Ujumbe: {s}: imehifadhiwa kwa sababu stdout ni terminal; tumia --temp kuitumia kwa ombi hili pekee.",
    .persistence_note_non_tty = "Ujumbe: {s}: haijahifadhiwa kwa sababu stdout sio terminal; tumia --persist/--save kubatilisha.",
    .persistence_note_semantic = "Ujumbe: {s}: imehifadhiwa kwa sababu mabadiliko kwenye mwonekano wa mradi ulioshirikiwa yanahifadhiwa kwa chaguo-msingi; tumia --temp kuzitumia kwa ombi hili pekee.",
    .persistence_note_env = "Ujumbe: {s}: haijahifadhiwa kwa sababu DIRTREE_TEMP=1; tumia --persist/--save kubatilisha.",
    .persistence_note_mute = "Weka DIRTREE_MUTE_PERSISTENCE_REASON=1 ili kukandamiza ujumbe huu wa habari.",
    .help_examples_header = "Mifano:",
    .help_example_1 = "  dirtree                       # Onyesha mti wa saraka ya sasa",
    .help_example_2 = "  dirtree -d 3                  # Weka kina kuwa viwango 3",
    .help_example_3 = "  dirtree --sort alpha --asc    # Imepangwa kialfabeti kupanda",
    .help_example_close_comment = "Kunja saraka (huhifadhiwa)",
    .help_example_hide_comment = "Ficha faili zinazolingana na regex",
    .help_example_only_comment = "Lenga mti-mdogo mmoja, ficha ndugu",
    .help_example_localized_comment = "Majina ya swichi yaliyotafsiriwa pia hufanya kazi",

    // ── Maandishi ya kuhusu ────────────────────────────────────
    .about_text = "Mti wa saraka wenye hali (ikoni/rangi/viungo); --simple kwa LLM; huhifadhi .dirtree-state (default/open/close/show/hide); regex kupitia /pattern/ au !/pattern/; herufi halisi lazima ziwe za jamaa; env: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── Vipande vya kuhesabu vilivyofichwa ─────────────────────
    .hidden_dir_singular = "saraka",
    .hidden_dir_plural = "saraka",
    .hidden_file_singular = "faili",
    .hidden_file_plural = "mafaili",
    .hidden_and = " na ",
    .hidden_is_hidden = " imefichwa.",
    .hidden_are_hidden = " zimefichwa.",
    .stats_shown = " zimeonyeshwa",
    .stats_hidden = " zimefichwa.",
    .stats_line_singular = "mstari",
    .stats_line_plural = "mistari",
    .stats_separator = "; ",

    .stats_scm_kept = " hayajafichwa kwa sababu yamo katika seti ya mabadiliko ya sasa ya git/jj",
    // ── Maandishi ya msaada (bendera mpya) ─────────────────────
    .help_opt_max_lines = "  --max-lines N      Weka kizingiti cha onyo la matokeo makubwa (chaguo-msingi: 500)",
    .help_opt_override_warning = "  --override-warning Zuia onyo la matokeo makubwa",
    .help_opt_only = "  --only PATH        Zingatia mti mdogo, ukikunja saraka za ndugu (inarudiwa)",
    .help_opt_html = "  --html [FILE]      Andika mti wa HTML unaojitegemea kwenye FILE (- = stdout; acha = fungua kwenye kivinjari)",
    .help_opt_no_targets = "  --no-symlink-targets/--no-targets  Ficha shabaha za symlink; --no-targets huondoa pia viungo (matokeo yanayobebeka)",

    // ── Ujumbe wa onyo (matokeo makubwa) ───────────────────────
    .warn_large_output_prefix = "Onyo: matokeo ni takriban ",
    .warn_large_output_mid = " mistari (kizingiti: ",
    .warn_large_output_suffix = "). Zingatia: --depth N au mifumo ya --hide.",

    // ── Ujumbe wa hitilafu ─────────────────────────────────────
    .err_max_lines_requires_number = "Hitilafu: --max-lines inahitaji hoja ya kinambari (en: Error: --max-lines requires a numeric argument)",
    .err_only_requires_path = "Hitilafu: --only inahitaji hoja ya njia (en: Error: --only requires a path argument)",
    .err_depth_requires_number = "Hitilafu: --depth inahitaji hoja ya kinambari (en: Error: --depth requires a numeric argument)",
    .err_path_requires_arg = "Hitilafu: --path inahitaji hoja ya saraka (en: Error: --path requires a directory argument)",
    .err_notes_requires_mode = "Hitilafu: --notes inahitaji 'aligned' au 'inline' (en: Error: --notes requires 'aligned' or 'inline')",
    .err_sort_requires_mode = "Hitilafu: --sort inahitaji 'modified' au 'alpha' (en: Error: --sort requires 'modified' or 'alpha')",
    .err_default_requires_value = "Hitilafu: --default inahitaji angalau thamani moja (en: Error: --default requires at least one value)",
    .err_default_state_conflict = "Hitilafu: mgongano wa hali ya --default (en: Error: --default state conflict)",
    .err_default_accepts = "Hitilafu: --default inakubali opened/closed (en: Error: --default accepts opened/closed)",
    .err_open_requires_dir = "Hitilafu: --open inahitaji angalau saraka moja (en: Error: --open requires at least one directory)",
    .err_close_requires_dir = "Hitilafu: --close inahitaji angalau saraka moja (en: Error: --close requires at least one directory)",
    .err_show_requires_path = "Hitilafu: --show inahitaji angalau njia moja (en: Error: --show requires at least one path)",
    .err_hide_requires_path = "Hitilafu: --hide inahitaji angalau njia moja (en: Error: --hide requires at least one path)",
    .err_unknown_option = "Chaguo lisilojulikana (en: Unknown option)",
    .err_not_a_directory = "Hitilafu: '{s}' si saraka (en: Error: '{s}' is not a directory)",
    .err_regex_empty = "Hitilafu: mfumo wa regex hauwezi kuwa tupu (en: Error: regex pattern must not be empty)",
    .err_paths_must_be_relative = "Hitilafu: njia za {s} lazima ziwe za jamaa (bila '/' ya kuanzia): {s} (en: Error: {s} paths must be relative (no leading '/'): {s})",
    .err_out_of_memory = "Kumbukumbu imeisha (en: Out of memory)",
    .err_regex_conflict_path = "Hitilafu: njia '{s}' inalingana na mifumo ya open na close (en: Error: path '{s}' matches both open and close patterns)",
    .err_regex_conflict_open = "  mfumo wa open: {s} (en:   open pattern: {s})",
    .err_regex_conflict_close = "  mfumo wa close: {s} (en:   close pattern: {s})",
    .err_regex_invalid = "Hitilafu: mfumo wa regex batili: {s} (en: Error: invalid regex pattern: {s})",
    .err_unknown_lang = "Hitilafu: msimbo wa lugha usiojulikana '{s}'. Zinazopatikana: {s} (en: Error: unknown language code '{s}'. Available: {s})",
    .err_annotate_requires_path = "Hitilafu: annotate inahitaji njia (en: Error: annotate requires a path)",
    .err_annotate_requires_description = "Hitilafu: annotate inahitaji maelezo (tumia \"\" kufuta) (en: Error: annotate requires a description (use \"\" to clear))",
    .err_annotate_multiline = "Hitilafu: maelezo ya annotate lazima yawe mstari mmoja (en: Error: annotation description must be a single line)",
    .err_annotate_too_many_args = "Hitilafu: annotate inakubali hoja mbili za nafasi pekee: <path> <description> (en: Error: annotate accepts exactly two positional arguments: <path> <description>)",
    .help_opt_annotate = "  annotate PATH DESC Hifadhi dokezo la mstari mmoja kuhusu faili au saraka (jina jingine: note; DESC tupu hufuta)",
    .help_opt_orphaned_notes = "  orphaned-notes [DIR] Orodhesha madokezo ambayo njia zake lengwa hazipo tena",
    .help_opt_purge_orphaned_notes = "  purge-orphaned-notes [DIR] Ondoa madokezo ambayo njia zake lengwa hazipo tena",
    .help_subcommands =
    \\<annotate>
    \\Matumizi: dirtree annotate PATH DESC
    \\          dirtree note PATH DESC          (jina jingine)
    \\
    \\Hifadhi dokezo la mstari mmoja kuhusu faili au saraka. Dokezo huhifadhiwa katika
    \\.dirtree-state na huonyeshwa kando ya PATH mara ijayo mti utakapoonyeshwa.
    \\
    \\Hoja:
    \\  PATH   faili au saraka, kwa uhusiano na saraka ya sasa
    \\  DESC   maandishi ya dokezo; pitisha mfuatano tupu "" kufuta dokezo lililopo
    \\
    \\Mifano:
    \\  dirtree annotate src/main.zig "Njia ya kuingia ya CLI"
    \\  dirtree note docs "madokezo ya muundo yapo hapa"
    \\  dirtree annotate README.md ""        # futa dokezo kwenye README.md
    \\</annotate>
    \\<orphaned_notes>
    \\Matumizi: dirtree orphaned-notes [DIR]
    \\
    \\Orodhesha madokezo ambayo njia zake lengwa hazipo tena — kwa mfano baada ya faili
    \\kubadilishwa jina, kuhamishwa, au kufutwa. DIR ni saraka ya sasa kwa chaguo-msingi.
    \\Hii ni ya kusoma tu: hakuna kinachobadilishwa. Tumia purge-orphaned-notes kuyaondoa.
    \\
    \\Mifano:
    \\  dirtree orphaned-notes
    \\  dirtree orphaned-notes src
    \\</orphaned_notes>
    \\<purge_orphaned_notes>
    \\Matumizi: dirtree purge-orphaned-notes [DIR]
    \\
    \\Ondoa madokezo ambayo njia zake lengwa hazipo tena. DIR ni saraka ya sasa kwa
    \\chaguo-msingi. Endesha orphaned-notes kwanza ili kuona hasa kitakachoondolewa.
    \\
    \\Mifano:
    \\  dirtree purge-orphaned-notes
    \\  dirtree purge-orphaned-notes src
    \\</purge_orphaned_notes>
    ,
    .orphaned_header = "Madokezo yaliyoachwa (njia ambazo hazipo tena):",
    .orphaned_none = "Hakuna madokezo yaliyoachwa.",
    .purge_header = "Madokezo yaliyoachwa yameondolewa:",
    .purge_none = "Hakuna madokezo yaliyoachwa ya kuondoa.",
    .help_opt_version = "  --version          Onyesha toleo (nje ya mtandao; husoma taarifa ya sasisho iliyohifadhiwa)",
    .help_opt_version_check = "  --version-check    Lazimisha ukaguzi mpya mtandaoni dhidi ya API ya matoleo ya GitHub",

    // ── Ujumbe wa onyo ─────────────────────────────────────────
    .warn_persist_state = "Onyo: haikuweza kuhifadhi hali: {}",

    // ── Hali ya jaribio ────────────────────────────────────────
    .test_mode_msg = "Hali ya jaribio: kuendesha majaribio ya zig hufanywa kupitia 'zig build test'",

    // ── Mengineyo ──────────────────────────────────────────────
    .err_test_bin_run = "Hitilafu: haikuweza kuendesha DIRTREE_TEST_BIN: {s} (en: Error: could not run DIRTREE_TEST_BIN: {s})",
    .err_test_bin_wait = "Hitilafu: haikuweza kusubiri DIRTREE_TEST_BIN (en: Error: could not wait for DIRTREE_TEST_BIN)",
    .err_render_tree = "Hitilafu katika kuonyesha mti: {} (en: Error rendering tree: {})",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--msaada", .arg = .help },
        .{ .name = "--kuhusu", .arg = .about },
        .{ .name = "--kina", .arg = .depth },
        .{ .name = "--njia", .arg = .path },
        .{ .name = "--rahisi", .arg = .simple },
        .{ .name = "--iliyopambwa", .arg = .decorated },
        .{ .name = "--hakuna-ikoni", .arg = .no_icons },
        .{ .name = "--hakuna-rangi", .arg = .no_color },
        .{ .name = "--rangi", .arg = .color },
        .{ .name = "--hakuna-onyo-yatima", .arg = .no_orphan_warning },
        .{ .name = "--hakuna-madokezo", .arg = .no_notes },
        .{ .name = "--onyesha-madokezo", .arg = .show_notes },
        .{ .name = "--madokezo", .arg = .notes },
        .{ .name = "--uongozi-madokezo", .arg = .note_leader },
        .{ .name = "--hakuna-viungo", .arg = .no_hyperlinks },
        .{ .name = "--viungo", .arg = .hyperlinks },
        .{ .name = "--chaguo-msingi", .arg = .default },
        .{ .name = "--fungua", .arg = .open },
        .{ .name = "--funga", .arg = .close },
        .{ .name = "--onyesha", .arg = .show },
        .{ .name = "--ficha", .arg = .hide },
        .{ .name = "--panga", .arg = .sort },
        .{ .name = "--kupanda", .arg = .asc },
        .{ .name = "--kushuka", .arg = .desc },
        .{ .name = "--onyesha-zilizofichwa", .arg = .show_hidden },
        .{ .name = "--andika-upya-mipangilio", .arg = .rewrite_settings },
        .{ .name = "--usanidi", .arg = .config },
        .{ .name = "--jaribu", .arg = .@"test" },
        .{ .name = "--lugha", .arg = .lang },
        .{ .name = "--muda", .arg = .temporary },
        .{ .name = "--mistari-juu", .arg = .max_lines },
        .{ .name = "--puuza-onyo", .arg = .override_warning },
        .{ .name = "--pekee", .arg = .only },
        .{ .name = "dokeza", .arg = .annotate },
        .{ .name = "madokezo-yatima", .arg = .orphaned_notes },
        .{ .name = "ondoa-madokezo-yatima", .arg = .purge_orphaned_notes },
        .{ .name = "dokezo", .arg = .annotate },
        .{ .name = "--toleo", .arg = .version },
        .{ .name = "--kagua-toleo", .arg = .version_check },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "DIRTREE_RAHISI", .var_id = .dirtree_simple },
        .{ .name = "DIRTREE_ILIYOPAMBWA", .var_id = .dirtree_decorated },
        .{ .name = "DIRTREE_RAHISI_OTOMATIKI", .var_id = .dirtree_auto_simple },
        .{ .name = "STDOUT_ILIYOPITISHWA", .var_id = .piped_stdout },
        .{ .name = "DIRTREE_FICHA_MADOKEZO", .var_id = .dirtree_hide_notes },
        .{ .name = "DIRTREE_MABADILIKO_SCM_YABAKI_YAMEFICHWA_AU_YAMEFUNGWA", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
