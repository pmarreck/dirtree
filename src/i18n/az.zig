const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── K\xc3\xb6m\xc9\x99k m\xc9\x99tni ──────────────────────────────────────────
    .help_title = "dirtree - \xc4\xb0nsanlar v\xc9\x99 LLM-l\xc9\x99r \xc3\xbc\xc3\xa7\xc3\xbcn v\xc9\x99ziyy\xc9\x99tli qovluq a\xc4\x9faclar\xc4\xb1",
    .help_usage = "\xc4\xb0stifad\xc9\x99: dirtree [SE\xc3\x87\xc4\xb0ML\xc6\x8fR] [YOLA]",
    .help_options_header = "Se\xc3\xa7iml\xc9\x99r:",
    .help_opt_help = "  -h, --help         Bu k\xc3\xb6m\xc9\x99k mesaj\xc4\xb1n\xc4\xb1 g\xc3\xb6st\xc9\x99r",
    .help_opt_about = "  -a, --about        \xc6\x8ftrafl\xc4\xb1 t\xc9\x99sviri g\xc3\xb6st\xc9\x99r",
    .help_opt_depth = "  -d, --depth N      Maksimum d\xc9\x99rinliyi t\xc9\x99yin et (varsay\xc4\xb1lan: 4)",
    .help_opt_simple = "  --simple           Sad\xc9\x99, LLM-\xc3\xbc\xc3\xa7\xc3\xbcn uy\xc4\x9fun v\xc9\x99ziyy\xc9\x99tli a\xc4\x9fac \xc3\xa7\xc4\xb1x\xc4\xb1\xc5\x9f\xc4\xb1",
    .help_opt_decorated = "  --decorated        B\xc9\x99z\xc9\x99kli \xc3\xa7\xc4\xb1x\xc4\xb1\xc5\x9f\xc4\xb1 m\xc9\x99cbur et (h\xc9\x99tta pipe zaman\xc4\xb1)",
    .help_opt_no_icons = "  --no-icons         \xc4\xb0konlar\xc4\xb1 s\xc3\xb6nd\xc3\xbcr (sad\xc9\x99 rejim + b\xc9\x99z\xc9\x99kli ba\xc5\x9fl\xc4\xb1q)",
    .help_opt_no_color = "  --no-color        ANSI r\xc9\x99ngl\xc9\x99ri s\xc3\xb6nd\xc3\xbcr v\xc9\x99 se\xc3\xa7imi saxla",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   OSC8 hiperlinkl\xc9\x99ri s\xc3\xb6nd\xc3\xbcr v\xc9\x99 se\xc3\xa7imi saxla",
    .help_opt_default = "  --default X        Varsay\xc4\xb1lan v\xc9\x99ziyy\xc9\x99ti saxla: opened|closed",
    .help_opt_open = "  -o, --open QOVL... Bir v\xc9\x99 ya daha \xc3\xa7ox alt qovlu\xc4\x9fu a\xc3\xa7 (t\xc9\x99krarlanabilir)",
    .help_opt_close = "  -c, --close QOVL.. Bir v\xc9\x99 ya daha \xc3\xa7ox alt qovlu\xc4\x9fu ba\xc4\x9fla (t\xc9\x99krarlanabilir)",
    .help_opt_show = "  --show YOLA...     Nisbi yollar\xc4\xb1 g\xc3\xb6st\xc9\x99r; regex /\xc5\x9fablon/ v\xc9\x99 ya !/\xc5\x9fablon/",
    .help_opt_hide = "  --hide YOLA...     Nisbi yollar\xc4\xb1 gizl\xc9\x99; regex /\xc5\x9fablon/ v\xc9\x99 ya !/\xc5\x9fablon/ (t\xc9\x99krarlanabilir)",
    .help_opt_sort = "  --sort REJ\xc4\xb0M      S\xc4\xb1ralama rejimi: modified|alpha (varsay\xc4\xb1lan: modified)",
    .help_opt_asc = "  --asc              Artan s\xc4\xb1ralama",
    .help_opt_desc = "  --desc             Azalan s\xc4\xb1ralama (varsay\xc4\xb1lan)",
    .help_opt_show_hidden = "  --show-hidden      Konfiqurasiya il\xc9\x99 gizl\xc9\x99nmi\xc5\x9f yollar\xc4\xb1 m\xc3\xbc\xc9\x99qq\xc9\x99ti g\xc3\xb6st\xc9\x99r",
    .help_opt_rewrite_settings = "  --rewrite-settings V\xc9\x99ziyy\xc9\x99t fayllar\xc4\xb1n\xc4\xb1 cari parametrl\xc9\x99rl\xc9\x99 yenid\xc9\x99n yaz",
    .help_opt_config = "  --config           Hesablanm\xc4\xb1\xc5\x9f effektiv konfiqurasiyany g\xc3\xb6st\xc9\x99r",
        .help_opt_test = "  --test             \xc6\x8flaq\xc9\x99li testl\xc9\x99ri i\xc5\x9f\xc9\x99 sal",
    .help_opt_lang = "  --lang KOD         G\xc3\xb6st\xc9\x99ri\xc5\x9f dilini t\xc9\x99yin et (m\xc9\x99s. en, de, fr, ja)",
    .help_regex_note = "--open/--close/--show/--hide il\xc9\x99 /\xc5\x9fablon/ v\xc9\x99 ya !/\xc5\x9fablon/ istifad\xc9\x99 edin; dig\xc9\x99r arqumentl\xc9\x99r literal kimi i\xc5\x9fl\xc9\x99nilir.",
    .help_relative_note = "--show/--hide \xc3\xbc\xc3\xa7\xc3\xbcn veril\xc9\x99n yollar nisbi olmal\xc4\xb1d\xc4\xb1r (\xc9\x99vv\xc9\x99lind\xc9\x99 '/' olmadan).",
    .help_behavior_header = "Davran\xc4\xb1\xc5\x9f:",
    .help_behavior_text = "Varsay\xc4\xb1lan olaraq, stdout TTY olmad\xc4\xb1qda (pipe), --decorated verilm\xc9\x99dikc\xc9\x99 r\xc9\x99ngl\xc9\x99r/ikonlar/hiperlinkl\xc9\x99r s\xc3\xb6nd\xc3\xbcr\xc3\xbcl\xc3\xbcr.",
    .help_examples_header = "N\xc3\xbcmun\xc9\x99l\xc9\x99r:",
    .help_example_1 = "  dirtree                       # Cari qovlu\xc4\x9fun a\xc4\x9fac\xc4\xb1n\xc4\xb1 g\xc3\xb6st\xc9\x99r",
    .help_example_2 = "  dirtree -d 3                  # D\xc9\x99rinliyi 3 s\xc9\x99viyy\xc9\x99y\xc9\x99 t\xc9\x99yin et",
    .help_example_3 = "  dirtree --sort alpha --asc    # \xc6\x8flifba s\xc4\xb1ras\xc4\xb1 il\xc9\x99 artan s\xc4\xb1ralama",

    // ── Haqqında mətni ──────────────────────────────────────────
    .about_text = "V\xc9\x99ziyy\xc9\x99tli qovluq a\xc4\x9fac\xc4\xb1 (ikonlar/r\xc9\x99ngl\xc9\x99r/linkl\xc9\x99r); --simple LLM-l\xc9\x99r \xc3\xbc\xc3\xa7\xc3\xbcn; .dirtree-state saxlay\xc4\xb1r (default/open/close/show/hide); regex /\xc5\x9fablon/ v\xc9\x99 ya !/\xc5\x9fablon/ vasit\xc9\x99sil\xc9\x99; literallar nisbi olmal\xc4\xb1d\xc4\xb1r; m\xc3\xbchit: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── Gizli say fragm\xc9\x99ntl\xc9\x99ri ──────────────────────────────────
    .hidden_dir_singular = "qovluq",
    .hidden_dir_plural = "qovluq",
    .hidden_file_singular = "fayl",
    .hidden_file_plural = "fayl",
    .hidden_and = " v\xc9\x99 ",
    .hidden_is_hidden = " gizlidir.",
    .hidden_are_hidden = " gizlidir.",
    .stats_shown = " göstərilir",
    .stats_hidden = " gizlidir.",
    .stats_line_singular = "sətir",
    .stats_line_plural = "sətir",
    .stats_separator = "; ",

    // ── X\xc9\x99ta mesajlar\xc4\xb1 ──────────────────────────────────────────
    .err_depth_requires_number = "X\xc9\x99ta: --depth r\xc9\x99q\xc9\x99mli arqument t\xc9\x99l\xc9\x99b edir",
    .err_sort_requires_mode = "X\xc9\x99ta: --sort 'modified' v\xc9\x99 ya 'alpha' t\xc9\x99l\xc9\x99b edir",
    .err_default_requires_value = "X\xc9\x99ta: --default \xc9\x99n az\xc4\xb1 bir d\xc9\x99y\xc9\x99r t\xc9\x99l\xc9\x99b edir",
    .err_default_state_conflict = "X\xc9\x99ta: --default v\xc9\x99ziyy\xc9\x99t ziddiyy\xc9\x99ti",
    .err_default_accepts = "X\xc9\x99ta: --default opened/closed q\xc9\x99bul edir",
    .err_open_requires_dir = "X\xc9\x99ta: --open \xc9\x99n az\xc4\xb1 bir qovluq t\xc9\x99l\xc9\x99b edir",
    .err_close_requires_dir = "X\xc9\x99ta: --close \xc9\x99n az\xc4\xb1 bir qovluq t\xc9\x99l\xc9\x99b edir",
    .err_show_requires_path = "X\xc9\x99ta: --show \xc9\x99n az\xc4\xb1 bir yol t\xc9\x99l\xc9\x99b edir",
    .err_hide_requires_path = "X\xc9\x99ta: --hide \xc9\x99n az\xc4\xb1 bir yol t\xc9\x99l\xc9\x99b edir",
    .err_unknown_option = "Nabilinm\xc9\x99y\xc9\x99n se\xc3\xa7im",
    .err_not_a_directory = "X\xc9\x99ta: '{s}' qovluq deyil",
    .err_regex_empty = "X\xc9\x99ta: regex \xc5\x9fablonu bo\xc5\x9f ola bilm\xc9\x99z",
    .err_paths_must_be_relative = "X\xc9\x99ta: {s} yollar\xc4\xb1 nisbi olmal\xc4\xb1d\xc4\xb1r (\xc9\x99vv\xc9\x99lind\xc9\x99 '/' olmadan): {s}",
    .err_out_of_memory = "Yaddaş çatışmazlığı",
    .err_regex_conflict_path = "X\xc9\x99ta: '{s}' yolu h\xc9\x99m a\xc3\xa7\xc4\xb1q, h\xc9\x99m ba\xc4\x9fl\xc4\xb1 \xc5\x9fablonlara uy\xc4\x9fundur",
    .err_regex_conflict_open = "  a\xc3\xa7\xc4\xb1q \xc5\x9fablonu: {s}",
    .err_regex_conflict_close = "  ba\xc4\x9fl\xc4\xb1 \xc5\x9fablonu: {s}",
    .err_unknown_lang = "X\xc9\x99ta: nabilinm\xc9\x99y\xc9\x99n dil kodu '{s}'. M\xc3\xb6vcud: {s}",

    // ── X\xc9\x99b\xc9\x99rdarlıqlar ──────────────────────────────────────────
    .warn_persist_state = "X\xc9\x99b\xc9\x99rdarlıq: v\xc9\x99ziyy\xc9\x99ti saxlamaq m\xc3\xbcmk\xc3\xbcn olmadı: {}",

    // ── S\xc4\xb1naq rejimi ──────────────────────────────────────────────
    .test_mode_msg = "S\xc4\xb1naq rejimi: Zig vahid testl\xc9\x99ri 'zig build test' vasit\xc9\x99sil\xc9\x99 i\xc5\x9f\xc9\x99 sal\xc4\xb1n\xc4\xb1r",

    // ── Dig\xc9\x99r ──────────────────────────────────────────────────────
    .err_test_bin_run = "X\xc9\x99ta: DIRTREE_TEST_BIN i\xc5\x9f\xc9\x99 sal\xc4\xb1na bilm\xc9\x99di: {s}",
    .err_test_bin_wait = "X\xc9\x99ta: DIRTREE_TEST_BIN g\xc3\xb6zl\xc9\x99nil\xc9\x99 bilm\xc9\x99di",
    .err_render_tree = "A\xc4\x9fac\xc4\xb1n g\xc3\xb6st\xc9\x99rilm\xc9\x99sind\xc9\x99 x\xc9\x99ta: {}",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--komek", .arg = .help },
        .{ .name = "--haqqinda", .arg = .about },
        .{ .name = "--derinlik", .arg = .depth },
        .{ .name = "--sadece", .arg = .simple },
        .{ .name = "--bezekli", .arg = .decorated },
        .{ .name = "--ikonsuz", .arg = .no_icons },
        .{ .name = "--renksiz", .arg = .no_color },
        .{ .name = "--linkler-yok", .arg = .no_hyperlinks },
        .{ .name = "--susmaya-gore", .arg = .default },
        .{ .name = "--ach", .arg = .open },
        .{ .name = "--bagla", .arg = .close },
        .{ .name = "--goster", .arg = .show },
        .{ .name = "--gizle", .arg = .hide },
        .{ .name = "--siralama", .arg = .sort },
        .{ .name = "--artan", .arg = .asc },
        .{ .name = "--azalan", .arg = .desc },
        .{ .name = "--gizlileri-goster", .arg = .show_hidden },
        .{ .name = "--ayarlari-yeniden-yaz", .arg = .rewrite_settings },
        .{ .name = "--konfiqurasiya", .arg = .config },
                .{ .name = "--sinaq", .arg = .@"test" },
        .{ .name = "--dil", .arg = .lang },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "AGAC_SADECE", .var_id = .dirtree_simple },
        .{ .name = "AGAC_BEZEKLI", .var_id = .dirtree_decorated },
        .{ .name = "AGAC_AVTO_SADECE", .var_id = .dirtree_auto_simple },
        .{ .name = "PIPED_STDOUT", .var_id = .piped_stdout },
        .{ .name = "AGAC_SCM_DEYISHIKLIKLER_GIZLI_VE_YA_BAGLI", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
