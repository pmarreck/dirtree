const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── د مرستې متن ─────────────────────────────────────────────
    .help_title = "dirtree - د انسانانو او LLMs لپاره د حالت لرونکي د لارښود ونې",
    .help_usage = "کارونه: dirtree [انتخابونه] [لاره]",
    .help_options_header = "انتخابونه:",
    .help_opt_help = "  -h, --help         دا د مرستې پیغام وښایه",
    .help_opt_about = "  -a, --about        تفصيلي تشریح وښایه",
    .help_opt_depth = "  -d, --depth N      اعظمي ژوروالی وټاکه (تلواله: 4)",
    .help_opt_temp = "  -t, --temp         بدلونونه یوازې د دې ځل لپاره پلي کړئ (نه خوندي کیږي)",
    .help_opt_persist = "  --persist, --save  دا تنظیمات هم خوندي کړئ (non-TTY او DIRTREE_TEMP بیرته راګرځوي)",
    .help_opt_path = "  -p, --path PATH    PATH رنډر کړه که څه هم لکه بیرغ یا فرعي کمانډ ښکاري",
    .help_opt_simple = "  --simple           یوه ساده، د LLM ملګرې حالت لرونکې ونه وباسه",
    .help_opt_decorated = "  --decorated        سینګار شوې وتلون اړ کړه (حتی کله چې پایپ شوی وي)",
    .help_opt_no_icons = "  --no-icons         آیکونونه غیر فعال کړه (ساده حالت + سینګار شوې سرلیک)",
    .help_opt_no_color = "  --no-color        ANSI رنګونه چالان/بند کړئ (خوندي)",
    .help_opt_no_orphan_warning = "  --no-orphan-warning د orphaned-notes خبرتیا بنده کړه",
    .help_opt_notes = "  --no-notes/--show-notes داخلي یادښتونه پټ یا وښایه (DIRTREE_HIDE_NOTES=1 د تلوالې له مخې پټوي)",
    .help_opt_notes_mode = "  --notes MODE       د یادښت ترتیب: aligned (تلواله) یا inline",
    .help_opt_notes_leader = "  --notes-leader     له نومونو څخه تر سمو شویو یادښتونو پورې کمزوري مشري ټکي راکاږه",
    .warn_orphaned_prefix = "یادونه: ",
    .warn_orphaned_suffix = " تشریح(ونه) داسې لارو ته اشاره کوي چې نور شتون نلري. د کتلو لپاره 'orphaned-notes' یا د لرې کولو لپاره 'purge-orphaned-notes' وچلوه.",
    .warn_negation_intro = "یادونه: دلته نفي شوی regex کولی شي ستاسو مطلب بدل کړي — !/PAT/ برعکس سره سمون خوري، او مخکښ (?!...) لیدنه هم یوه نفي ده، نو د دواړو یوځای کول دوه ګونی نفي کوي:",
    .warn_negation_advice = "په یوه لاره تمرکز کولو لپاره، {s} PATH غوره کړه؛ د مثبت فلټر لپاره {s} /PAT/ وکاروه (show قواعد د hide پر وړاندې لومړیتوب لري). دا قواعد .dirtree-state ته ساتل کیږي، چې ساده متن دی او کله چې پیچلي یا یو بل سره پوښښ کوي نو لاسي یې سمولی شې.",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   OSC8 لینکونه چالان/بند کړئ (خوندي)",
    .help_opt_default = "  --default X        تلواله حالت وساته: opened|closed",
    .help_opt_open = "  -o, --open DIR...  یوه یا څو فرعي لارښودونه پرانیزه (بیرغ تکرار کړه ترڅو نور ورزیات کړې)",
    .help_opt_close = "  -c, --close DIR... یوه یا څو فرعي لارښودونه وتړه (بیرغ تکرار کړه ترڅو نور ورزیات کړې)",
    .help_opt_show = "  --show PATH...     نسبي لارې په زور وښایه؛ regex د /pattern/ یا !/pattern/ په توګه ولیکه",
    .help_opt_hide = "  --hide PATH...     نسبي لارې پټ کړه؛ regex د /pattern/ یا !/pattern/ په توګه ولیکه (تکراریدونکی) (یوازې ځینې لارې وساتل غواړې؟ --only وکاروه)",
    .help_opt_sort = "  --sort MODE        د ترتیب حالت: modified|alpha (تلواله: modified)",
    .help_opt_asc = "  --asc              صعودي ترتیب",
    .help_opt_desc = "  --desc             نزولي ترتیب (تلواله)",
    .help_opt_show_hidden = "  --show-hidden      هغه لارې چې د تنظیماتو له مخې پټې دي په لنډمهاله توګه وښایه",
    .help_opt_rewrite_settings = "  --rewrite-settings د اوسنیو تنظیماتو په کارولو سره د حالت فایل بیا ولیکه",
    .help_opt_config = "  --config           حساب شوي اغیزمن تنظیمات وښایه",
    .help_opt_test = "  --test             اړوند ازموینې وچلوه",
    .help_opt_lang = "  --lang CODE        د ښودنې ژبه وټاکه (لکه en، de، fr، ja)",
    .help_lang_available_label = "د موجودو ژبو کوډونه:",
    .help_regex_note = "د regex قواعدو ورزیاتولو لپاره د --open/--close/--show/--hide سره /pattern/ یا !/pattern/ وکاروه؛ نور دلیلونه د لفظي ګڼل کیږي.",
    .help_relative_note = "هغه لارې چې --show/--hide ته ورکول کیږي باید نسبي وي (مخکښ '/' نه لري).",
    .help_behavior_header = "چلند:",
    .help_behavior_text = "د پریزنټشن ترتیبات خوندي کیږي کله چې stdout یو ټرمینل وي؛ که نه نو دوی یوازې په اوسني غوښتنه کې پلي کیږي. په ډیفالټ، --open/--close/--show/--hide بدلونونه تل خوندي کیږي. رنګ په ډیفالټ ډول د ترمینل محصول لپاره او د نورو محصول لپاره بند دی. --temp یا --persist/--save په واضح ډول د دې سپمولو مقررات له پامه غورځوي.",
    .persistence_note_tty = "پیغام: {s}: خوندي شوی ځکه چې stdout یو ټرمینل دی؛ --temp وکاروئ یوازې دې غوښتنې ته یې پلي کړئ.",
    .persistence_note_non_tty = "پیغام: {s}: خوندي شوی نه دی ځکه چې stdout ټرمینل ندی؛ د پورته کولو لپاره --persist/--save وکاروئ.",
    .persistence_note_semantic = "پیغام: {s}: خوندي شوی ځکه چې د شریکې پروژې لید کې بدلونونه د ډیفالټ لخوا خوندي شوي؛ --temp وکاروئ یوازې دې غوښتنې ته یې پلي کړئ.",
    .persistence_note_env = "پیغام: {s}: خوندي شوی نه دی ځکه چې DIRTREE_TEMP=1؛ د پورته کولو لپاره --persist/--save وکاروئ.",
    .persistence_note_mute = "DIRTREE_MUTE_PERSISTENCE_REASON=1 ترتیب کړئ ترڅو دا معلوماتي پیغام ودروي.",
    .help_examples_header = "بیلګې:",
    .help_example_1 = "  dirtree                       # د اوسني لارښود ونه وښایه",
    .help_example_2 = "  dirtree -d 3                  # ژوروالی په 3 کچو وټاکه",
    .help_example_3 = "  dirtree --sort alpha --asc    # د الفبا له مخې صعودي ترتیب",
    .help_example_close_comment = "یوه پوښه ټوله کړئ (خوندي)",
    .help_example_hide_comment = "د ریجیکس سره سمون لرونکي فایلونه پټ کړئ",
    .help_example_only_comment = "په یوه فرعي ونه تمرکز وکړئ، خویندې او وروڼه پټ کړئ",
    .help_example_localized_comment = "ځایي شوي سویچ نومونه هم کار کوي",

    // ── د پروژې په اړه متن ──────────────────────────────────────
    .about_text = "حالت لرونکې د لارښود ونه (آیکونونه/رنګونه/لینکونه)؛ د LLMs لپاره --simple؛ .dirtree-state ساتي (default/open/close/show/hide)؛ regex د /pattern/ یا !/pattern/ له لارې؛ لفظي باید نسبي وي؛ env: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── د شمیرنې ټوټې ───────────────────────────────────────────
    .hidden_dir_singular = "لارښود",
    .hidden_dir_plural = "لارښودونه",
    .hidden_file_singular = "فایل",
    .hidden_file_plural = "فایلونه",
    .hidden_and = " او ",
    .hidden_is_hidden = " پټ دی.",
    .hidden_are_hidden = " پټ دي.",
    .stats_shown = " ښودل شوي",
    .stats_hidden = " پټ.",
    .stats_line_singular = "کرښه",
    .stats_line_plural = "کرښې",
    .stats_separator = "؛ ",

    .stats_scm_kept = " د اوسني git/jj د بدلونونو په ټولګه کې شتون له امله پټ نشو",
    // ── د مرستې متن (نوي بیرغونه) ──────────────────────────────
    .help_opt_max_lines = "  --max-lines N      د لوی وتلون خبرتیا حد وټاکه (تلواله: 500)",
    .help_opt_override_warning = "  --override-warning د لوی وتلون خبرتیا بنده کړه",
    .help_opt_only = "  --only PATH        په یوه فرعي ونه تمرکز وکړه، خویندوسره لارښودونه راجمع کړه (تکراریدونکی)",
    .help_opt_html = "  --html [FILE]      خپلواک HTML ونه FILE ته ولیکئ (- = stdout؛ پرېښودل = په براوزر کې پرانیستل)",
    .help_opt_no_targets = "  --no-symlink-targets/--no-targets  د symlink موخې پټ کړئ؛ ‏--no-targets هایپرلینکونه هم لرې کوي (د لیږد وړ محصول)",

    // ── د خبرتیا پیغامونه (لوی وتلون) ──────────────────────────
    .warn_large_output_prefix = "خبرتیا: وتلون نږدې ~",
    .warn_large_output_mid = " کرښې دي (حد: ",
    .warn_large_output_suffix = "). فکر وکړه: --depth N یا --hide نمونې.",

    // ── د تېروتنې پیغامونه ──────────────────────────────────────
    .err_max_lines_requires_number = "تېروتنه: --max-lines یوه شمیریزه دلیل ته اړتیا لري (en: Error: --max-lines requires a numeric argument)",
    .err_only_requires_path = "تېروتنه: --only یوه لارې دلیل ته اړتیا لري (en: Error: --only requires a path argument)",
    .err_depth_requires_number = "تېروتنه: --depth یوه شمیریزه دلیل ته اړتیا لري (en: Error: --depth requires a numeric argument)",
    .err_path_requires_arg = "تېروتنه: --path یوه لارښود دلیل ته اړتیا لري (en: Error: --path requires a directory argument)",
    .err_notes_requires_mode = "تېروتنه: --notes د 'aligned' یا 'inline' ته اړتیا لري (en: Error: --notes requires 'aligned' or 'inline')",
    .err_sort_requires_mode = "تېروتنه: --sort د 'modified' یا 'alpha' ته اړتیا لري (en: Error: --sort requires 'modified' or 'alpha')",
    .err_default_requires_value = "تېروتنه: --default لږ تر لږه یوه ارزښت ته اړتیا لري (en: Error: --default requires at least one value)",
    .err_default_state_conflict = "تېروتنه: --default د حالت ټکر (en: Error: --default state conflict)",
    .err_default_accepts = "تېروتنه: --default د opened/closed منلی دی (en: Error: --default accepts opened/closed)",
    .err_open_requires_dir = "تېروتنه: --open لږ تر لږه یوه لارښود ته اړتیا لري (en: Error: --open requires at least one directory)",
    .err_close_requires_dir = "تېروتنه: --close لږ تر لږه یوه لارښود ته اړتیا لري (en: Error: --close requires at least one directory)",
    .err_show_requires_path = "تېروتنه: --show لږ تر لږه یوه لارې ته اړتیا لري (en: Error: --show requires at least one path)",
    .err_hide_requires_path = "تېروتنه: --hide لږ تر لږه یوه لارې ته اړتیا لري (en: Error: --hide requires at least one path)",
    .err_unknown_option = "ناپیژندل شوی انتخاب (en: Unknown option)",
    .err_not_a_directory = "تېروتنه: '{s}' لارښود نه دی (en: Error: '{s}' is not a directory)",
    .err_regex_empty = "تېروتنه: د regex نمونه باید تشه نه وي (en: Error: regex pattern must not be empty)",
    .err_paths_must_be_relative = "تېروتنه: د {s} لارې باید نسبي وي (مخکښ '/' نه لري): {s} (en: Error: {s} paths must be relative (no leading '/'): {s})",
    .err_out_of_memory = "حافظه پای ته ورسیده (en: Out of memory)",
    .err_regex_conflict_path = "تېروتنه: لاره '{s}' د open او close دواړو نمونو سره سمون خوري (en: Error: path '{s}' matches both open and close patterns)",
    .err_regex_conflict_open = "  د open نمونه: {s} (en:   open pattern: {s})",
    .err_regex_conflict_close = "  د close نمونه: {s} (en:   close pattern: {s})",
    .err_regex_invalid = "تېروتنه: ناسمه د regex نمونه: {s} (en: Error: invalid regex pattern: {s})",
    .err_unknown_lang = "تېروتنه: ناپیژندل شوی د ژبې کوډ '{s}'. شته: {s} (en: Error: unknown language code '{s}'. Available: {s})",
    .err_annotate_requires_path = "تېروتنه: annotate یوه لارې ته اړتیا لري (en: Error: annotate requires a path)",
    .err_annotate_requires_description = "تېروتنه: annotate یوه تشریح ته اړتیا لري (د پاکولو لپاره \"\" وکاروه) (en: Error: annotate requires a description (use \"\" to clear))",
    .err_annotate_multiline = "تېروتنه: د تشریح بیان باید یوازې یوه کرښه وي (en: Error: annotation description must be a single line)",
    .err_annotate_too_many_args = "تېروتنه: annotate سمدستي دوه موقعیتي دلیلونه منلی دي: <path> <description> (en: Error: annotate accepts exactly two positional arguments: <path> <description>)",
    .help_opt_annotate = "  annotate PATH DESC د یوه فایل یا لارښود په اړه یوه یوه کرښه یادښت وساته (نوم بل: note؛ تشه DESC پاکوي)",
    .help_opt_orphaned_notes = "  orphaned-notes [DIR] هغه یادښتونه ولیکه چې د هدف لارې یې نور شتون نلري",
    .help_opt_purge_orphaned_notes = "  purge-orphaned-notes [DIR] هغه یادښتونه لرې کړه چې د هدف لارې یې نور شتون نلري",
    .help_subcommands =
    \\<annotate>
    \\کارونه: dirtree annotate PATH DESC
    \\        dirtree note PATH DESC          (نوم بل)
    \\
    \\د یوه فایل یا لارښود په اړه یوه یوه کرښه یادښت وساته. یادښت په
    \\.dirtree-state کې خوندي کیږي او بل ځل چې ونه رنډر شي د PATH ترڅنګ ښکاري.
    \\
    \\دلیلونه:
    \\  PATH   فایل یا لارښود، د اوسني لارښود په نسبت
    \\  DESC   د یادښت متن؛ د یوه موجود یادښت د پاکولو لپاره تشه "" ورکړه
    \\
    \\بیلګې:
    \\  dirtree annotate src/main.zig "د کمانډ لاین د ننوتلو ټکی"
    \\  dirtree note docs "د ډیزاین یادښتونه دلته دي"
    \\  dirtree annotate README.md ""        # د README.md یادښت پاکول
    \\</annotate>
    \\<orphaned_notes>
    \\کارونه: dirtree orphaned-notes [DIR]
    \\
    \\هغه یادښتونه ولیکه چې د هدف لاره یې نور شتون نلري — د بیلګې په توګه وروسته له دې
    \\چې یو فایل بیا نومول شوی، لیږدول شوی، یا ړنګ شوی وي. DIR تلواله اوسنی لارښود دی.
    \\دا یوازې د لوستلو لپاره ده: هیڅ شی نه بدلیږي. د دوی د لرې کولو لپاره purge-orphaned-notes وکاروه.
    \\
    \\بیلګې:
    \\  dirtree orphaned-notes
    \\  dirtree orphaned-notes src
    \\</orphaned_notes>
    \\<purge_orphaned_notes>
    \\کارونه: dirtree purge-orphaned-notes [DIR]
    \\
    \\هغه یادښتونه لرې کړه چې د هدف لاره یې نور شتون نلري. DIR تلواله اوسنی
    \\لارښود دی. لومړی orphaned-notes وچلوه ترڅو په دقیق ډول وګورې چې څه به لرې شي.
    \\
    \\بیلګې:
    \\  dirtree purge-orphaned-notes
    \\  dirtree purge-orphaned-notes src
    \\</purge_orphaned_notes>
    ,
    .orphaned_header = "بې سرپرسته یادښتونه (هغه لارې چې نور شتون نلري):",
    .orphaned_none = "هیڅ بې سرپرسته یادښتونه نشته.",
    .purge_header = "بې سرپرسته یادښتونه پاک شول:",
    .purge_none = "د پاکولو لپاره هیڅ بې سرپرسته یادښتونه نشته.",
    .help_opt_version = "  --version          نسخه وښایه (آفلاین؛ کیش شوې د تازه شتون خبرتیا لولي)",
    .help_opt_version_check = "  --version-check    د GitHub releases API په وړاندې یوه نوې آنلاین کتنه اړ کړه",

    // ── د خبرتیا پیغامونه ───────────────────────────────────────
    .warn_persist_state = "خبرتیا: حالت نه شو ساتل کیدی: {}",

    // ── د ازموینې حالت ──────────────────────────────────────────
    .test_mode_msg = "د ازموینې حالت: د zig واحد ازموینو چلول د 'zig build test' له لارې کیږي",

    // ── متفرقه ──────────────────────────────────────────────────
    .err_test_bin_run = "تېروتنه: DIRTREE_TEST_BIN نه شو چلیدی: {s} (en: Error: could not run DIRTREE_TEST_BIN: {s})",
    .err_test_bin_wait = "تېروتنه: د DIRTREE_TEST_BIN لپاره انتظار نه شو کیدی (en: Error: could not wait for DIRTREE_TEST_BIN)",
    .err_render_tree = "د ونې په رنډرولو کې تېروتنه: {} (en: Error rendering tree: {})",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--mrasta", .arg = .help },
        .{ .name = "--peraz", .arg = .about },
        .{ .name = "--jarwaaley", .arg = .depth },
        .{ .name = "--laar", .arg = .path },
        .{ .name = "--saada", .arg = .simple },
        .{ .name = "--singaar", .arg = .decorated },
        .{ .name = "--be-aikonona", .arg = .no_icons },
        .{ .name = "--be-rang", .arg = .no_color },
        .{ .name = "--rang", .arg = .color },
        .{ .name = "--be-besarparasta-khabartiya", .arg = .no_orphan_warning },
        .{ .name = "--be-yadashtona", .arg = .no_notes },
        .{ .name = "--yadashtona-wakhaya", .arg = .show_notes },
        .{ .name = "--yadasht-tartib", .arg = .notes },
        .{ .name = "--yadasht-mashri", .arg = .note_leader },
        .{ .name = "--be-hyperlinkona", .arg = .no_hyperlinks },
        .{ .name = "--taronona", .arg = .hyperlinks },
        .{ .name = "--tlwala", .arg = .default },
        .{ .name = "--pranize", .arg = .open },
        .{ .name = "--watra", .arg = .close },
        .{ .name = "--wakhaya", .arg = .show },
        .{ .name = "--pat-kra", .arg = .hide },
        .{ .name = "--tartib", .arg = .sort },
        .{ .name = "--saudi", .arg = .asc },
        .{ .name = "--nazuli", .arg = .desc },
        .{ .name = "--pat-wakhaya", .arg = .show_hidden },
        .{ .name = "--tanzimat-bia-olika", .arg = .rewrite_settings },
        .{ .name = "--tanzimat", .arg = .config },
        .{ .name = "--azmaya", .arg = .@"test" },
        .{ .name = "--jaba", .arg = .lang },
        .{ .name = "--lanmahala", .arg = .temporary },
        .{ .name = "--aezami-krshay", .arg = .max_lines },
        .{ .name = "--khabartiya-band", .arg = .override_warning },
        .{ .name = "--yawazey", .arg = .only },
        .{ .name = "yadasht-wakra", .arg = .annotate },
        .{ .name = "besarparasta-yadashtona", .arg = .orphaned_notes },
        .{ .name = "besarparasta-yadashtona-pak-kra", .arg = .purge_orphaned_notes },
        .{ .name = "yadasht", .arg = .annotate },
        .{ .name = "--nuskha", .arg = .version },
        .{ .name = "--nuskha-katana", .arg = .version_check },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "DIRTREE_SAADA", .var_id = .dirtree_simple },
        .{ .name = "DIRTREE_SINGAAR", .var_id = .dirtree_decorated },
        .{ .name = "DIRTREE_KHODKAR_SAADA", .var_id = .dirtree_auto_simple },
        .{ .name = "PAYP_STDOUT", .var_id = .piped_stdout },
        .{ .name = "DIRTREE_SCM_BADLUNONA_PAT_YA_WATRAL_SHWI", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
