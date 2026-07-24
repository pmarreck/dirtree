const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── متن راهنما ───────────────────────────────────────────
    .help_title = "dirtree - درخت پوشه‌های دارای وضعیت برای انسان‌ها و مدل‌های زبانی بزرگ",
    .help_usage = "کاربرد: dirtree [گزینه‌ها] [مسیر]",
    .help_options_header = "گزینه‌ها:",
    .help_opt_help = "  -h, --help         نمایش این پیام راهنما",
    .help_opt_about = "  -a, --about        نمایش توضیحات تفصیلی",
    .help_opt_depth = "  -d, --depth N      تنظیم عمق بیشینه (پیش‌فرض: 4)",
    .help_opt_temp = "  -t, --temp         اعمال تغییرات فقط برای این اجرا (ذخیره نمی‌شود)",
    .help_opt_persist = "  --persist, --save  این تنظیمات را نیز ذخیره کنید (non-TTY و DIRTREE_TEMP را لغو می کند)",
    .help_opt_path = "  -p, --path PATH    نمایش PATH حتی اگر شبیه گزینه یا زیرفرمان باشد",
    .help_opt_simple = "  --simple           خروجی ساده و سازگار با مدل‌های زبانی بزرگ",
    .help_opt_decorated = "  --decorated        خروجی آراسته اجباری (حتی در حالت لوله)",
    .help_opt_no_icons = "  --no-icons         غیرفعال‌سازی نمادها (حالت ساده + سرآیند آراسته)",
    .help_opt_no_color = "  --no-color        فعال/غیرفعال‌کردن رنگ‌های ANSI (ذخیره می‌شود)",
    .help_opt_no_orphan_warning = "  --no-orphan-warning پنهان کردن هشدار یادداشت‌های یتیم",
    .help_opt_notes = "  --no-notes/--show-notes پنهان یا نمایش یادداشت‌های درون‌خطی (DIRTREE_HIDE_NOTES=1 برای پنهان‌سازی پیش‌فرض)",
    .help_opt_notes_mode = "  --notes MODE       چیدمان یادداشت: aligned (پیش‌فرض) یا inline",
    .help_opt_notes_leader = "  --notes-leader     کشیدن نقطه‌چین راهنما از نام‌ها به یادداشت‌های هم‌تراز",
    .warn_orphaned_prefix = "توجه: ",
    .warn_orphaned_suffix = " یادداشت به مسیرهایی اشاره دارند که دیگر وجود ندارند. برای مشاهده 'orphaned-notes' یا برای حذف 'purge-orphaned-notes' را اجرا کنید.",
    .warn_negation_intro = "توجه: یک الگوی نفی‌شده می‌تواند قصد شما را برعکس کند — !/PAT/ با معکوس مطابقت دارد و (?!...) ابتدایی هم نفی است؛ ترکیب آن‌ها نفی دوگانه می‌سازد:",
    .warn_negation_advice = "برای تمرکز روی یک مسیر از {s} PATH و برای فیلتر مثبت از {s} /PAT/ استفاده کنید (قوانین show بر hide اولویت دارند). این قوانین در .dirtree-state ذخیره می‌شوند؛ یک فایل متنی که هنگام پیچیده یا هم‌پوشان شدن می‌توانید دستی ویرایش کنید.",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   فعال/غیرفعال‌کردن پیوندهای OSC8 (ذخیره می‌شود)",
    .help_opt_default = "  --default X        ذخیره وضعیت پیش‌فرض: opened|closed",
    .help_opt_open = "  -o, --open DIR...  بازکردن یک یا چند زیرپوشه (تکرار پرچم برای افزودن)",
    .help_opt_close = "  -c, --close DIR... بستن یک یا چند زیرپوشه (تکرار پرچم برای افزودن)",
    .help_opt_show = "  --show PATH...     نمایش اجباری مسیرهای نسبی؛ عبارات باقاعده به صورت /الگو/ یا !/الگو/",
    .help_opt_hide = "  --hide PATH...     پنهان‌سازی مسیرهای نسبی؛ عبارات باقاعده به صورت /الگو/ یا !/الگو/ (قابل تکرار) (فقط برخی مسیرها؟ از --only استفاده کنید)",
    .help_opt_sort = "  --sort MODE        حالت مرتب‌سازی: modified|alpha (پیش‌فرض: modified)",
    .help_opt_asc = "  --asc              مرتب‌سازی صعودی",
    .help_opt_desc = "  --desc             مرتب‌سازی نزولی (پیش‌فرض)",
    .help_opt_show_hidden = "  --show-hidden      نمایش موقت مسیرهای پنهان‌شده از طریق پیکربندی",
    .help_opt_rewrite_settings = "  --rewrite-settings بازنویسی فایل وضعیت با تنظیمات فعلی",
    .help_opt_config = "  --config           نمایش پیکربندی مؤثر محاسبه‌شده",
    .help_opt_test = "  --test             اجرای آزمون‌های مرتبط",
    .help_opt_lang = "  --lang CODE        تنظیم زبان نمایش (مثلاً en، de، fr، ja)",
    .help_lang_available_label = "کدهای زبان موجود:",
    .help_regex_note = "از /الگو/ یا !/الگو/ با --open/--close/--show/--hide برای قواعد عبارات باقاعده استفاده کنید؛ سایر آرگومان‌ها به عنوان متن حرفی تلقی می‌شوند.",
    .help_relative_note = "مسیرهای ارائه‌شده به --show/--hide باید نسبی باشند (بدون '/' ابتدایی).",
    .help_behavior_header = "رفتار:",
    .help_behavior_text = "تنظیمات ارائه زمانی که stdout یک ترمینال باشد ذخیره می شود. در غیر این صورت آنها فقط برای فراخوان فعلی اعمال می شوند. به طور پیش فرض، تغییرات --open/--close/--show/--hide همیشه ذخیره می شوند. رنگ به طور پیش فرض برای خروجی ترمینال روشن و برای سایر خروجی ها خاموش است. --temp یا --persist/--save به صراحت این قوانین ذخیره را لغو می کند.",
    .persistence_note_tty = "پیام: {s}: ذخیره شد زیرا stdout یک ترمینال است. از --temp برای اعمال آن فقط در این فراخوانی استفاده کنید.",
    .persistence_note_non_tty = "پیام: {s}: ذخیره نشد زیرا stdout یک ترمینال نیست. از --persist/--save برای لغو استفاده کنید.",
    .persistence_note_semantic = "پیام: {s}: ذخیره شد زیرا تغییرات در نمای پروژه مشترک به طور پیش فرض ذخیره می شوند. از --temp استفاده کنید تا آنها را فقط در این فراخوان اعمال کنید.",
    .persistence_note_env = "پیام: {s}: ذخیره نشد زیرا DIRTREE_TEMP=1. از --persist/--save برای لغو استفاده کنید.",
    .persistence_note_mute = "DIRTREE_MUTE_PERSISTENCE_REASON=1 را برای سرکوب این پیام اطلاعاتی تنظیم کنید.",
    .help_examples_header = "مثال‌ها:",
    .help_example_1 = "  dirtree                       # نمایش درخت پوشه فعلی",
    .help_example_2 = "  dirtree -d 3                  # تنظیم عمق به 3 سطح",
    .help_example_3 = "  dirtree --sort alpha --asc    # مرتب‌سازی الفبایی صعودی",
    .help_example_close_comment = "جمع‌کردن یک پوشه (ذخیره می‌شود)",
    .help_example_hide_comment = "پنهان‌کردن فایل‌های منطبق با یک عبارت باقاعده",
    .help_example_only_comment = "تمرکز روی یک زیردرخت، پنهان‌کردن هم‌ترازها",
    .help_example_localized_comment = "نام‌های گزینهٔ بومی‌سازی‌شده نیز کار می‌کنند",

    // ── متن درباره ───────────────────────────────────────────
    .about_text = "درخت پوشه دارای وضعیت (نمادها/رنگ‌ها/پیوندها)؛ --simple برای مدل‌های زبانی بزرگ؛ ذخیره .dirtree-state (default/open/close/show/hide)؛ عبارات باقاعده از طریق /الگو/ یا !/الگو/؛ متن‌های حرفی باید نسبی باشند؛ متغیرهای محیطی: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── اجزای شمارش پنهان‌ها ─────────────────────────────────
    .hidden_dir_singular = "پوشه",
    .hidden_dir_plural = "پوشه",
    .hidden_file_singular = "فایل",
    .hidden_file_plural = "فایل",
    .hidden_and = " و ",
    .hidden_is_hidden = " پنهان است.",
    .hidden_are_hidden = " پنهان هستند.",
    .stats_shown = " نمایش داده شده",
    .stats_hidden = " پنهان.",
    .stats_line_singular = "خط",
    .stats_line_plural = "خط",
    .stats_separator = "؛ ",

    .stats_scm_kept = " به دلیل وجود در مجموعه تغییرات فعلی git/jj پنهان نشد",
    // ── پیام‌های خطا ─────────────────────────────────────────
    .err_depth_requires_number = "خطا: --depth به یک آرگومان عددی نیاز دارد (en: Error: --depth requires a numeric argument)",
    .err_path_requires_arg = "خطا: --path به یک آرگومان دایرکتوری نیاز دارد (en: Error: --path requires a directory argument)",
    .help_opt_max_lines = "  --max-lines N      تنظیم آستانه هشدار خروجی بزرگ (پیش‌فرض: 500)",
    .help_opt_override_warning = "  --override-warning پنهان کردن هشدار خروجی بزرگ",
    .help_opt_only = "  --only PATH        تمرکز روی یک زیردرخت، جمع کردن دایرکتوری‌های هم‌سطح (قابل تکرار)",
    .help_opt_html = "  --html [FILE]      نوشتن درخت HTML مستقل در FILE (- = stdout؛ حذف = باز کردن در مرورگر)",
    .help_opt_no_targets = "  --no-symlink-targets/--no-targets  پنهان کردن هدف‌های پیوند نمادین؛ ‏--no-targets ابرپیوندها را نیز حذف می‌کند (خروجی قابل‌حمل)",

    .warn_large_output_prefix = "هشدار: خروجی حدود ~",
    .warn_large_output_mid = " خط (آستانه: ",
    .warn_large_output_suffix = "). در نظر بگیرید: --depth N یا الگوهای --hide.",
    .err_only_requires_path = "خطا: --only به یک آرگومان مسیر نیاز دارد (en: Error: --only requires a path argument)",
    .err_max_lines_requires_number = "خطا: --max-lines به یک آرگومان عددی نیاز دارد (en: Error: --max-lines requires a numeric argument)",
    .err_notes_requires_mode = "خطا: --notes به 'aligned' یا 'inline' نیاز دارد (en: Error: --notes requires 'aligned' or 'inline')",
    .err_sort_requires_mode = "خطا: --sort به 'modified' یا 'alpha' نیاز دارد (en: Error: --sort requires 'modified' or 'alpha')",
    .err_default_requires_value = "خطا: --default حداقل به یک مقدار نیاز دارد (en: Error: --default requires at least one value)",
    .err_default_state_conflict = "خطا: تعارض وضعیت --default (en: Error: --default state conflict)",
    .err_default_accepts = "خطا: --default فقط opened/closed را می‌پذیرد (en: Error: --default accepts opened/closed)",
    .err_open_requires_dir = "خطا: --open حداقل به یک پوشه نیاز دارد (en: Error: --open requires at least one directory)",
    .err_close_requires_dir = "خطا: --close حداقل به یک پوشه نیاز دارد (en: Error: --close requires at least one directory)",
    .err_show_requires_path = "خطا: --show حداقل به یک مسیر نیاز دارد (en: Error: --show requires at least one path)",
    .err_hide_requires_path = "خطا: --hide حداقل به یک مسیر نیاز دارد (en: Error: --hide requires at least one path)",
    .err_unknown_option = "گزینه ناشناخته (en: Unknown option)",
    .err_not_a_directory = "خطا: '{s}' یک پوشه نیست (en: Error: '{s}' is not a directory)",
    .err_regex_empty = "خطا: الگوی عبارت باقاعده نباید خالی باشد (en: Error: regex pattern must not be empty)",
    .err_paths_must_be_relative = "خطا: مسیرهای {s} باید نسبی باشند (بدون '/' ابتدایی): {s} (en: Error: {s} paths must be relative (no leading '/'): {s})",
    .err_out_of_memory = "حافظه کافی نیست (en: Out of memory)",
    .err_regex_conflict_path = "خطا: مسیر '{s}' با هر دو الگوی بازکردن و بستن مطابقت دارد (en: Error: path '{s}' matches both open and close patterns)",
    .err_regex_conflict_open = "  الگوی بازکردن: {s} (en:   open pattern: {s})",
    .err_regex_conflict_close = "  الگوی بستن: {s} (en:   close pattern: {s})",
    .err_regex_invalid = "خطا: الگوی regex نامعتبر: {s} (en: Error: invalid regex pattern: {s})",
    .err_unknown_lang = "خطا: کد زبان ناشناخته '{s}'. موجود: {s} (en: Error: unknown language code '{s}'. Available: {s})",
    .err_annotate_requires_path = "Error: annotate requires a path",
    .err_annotate_requires_description = "Error: annotate requires a description (use \"\" to clear)",
    .err_annotate_multiline = "Error: annotation description must be a single line",
    .err_annotate_too_many_args = "Error: annotate accepts exactly two positional arguments: <path> <description>",
    .help_opt_annotate = "  annotate PATH DESC ثبت یک یادداشت تک‌خطی درباره یک فایل یا دایرکتوری (نام مستعار: note؛ خالی گذاشتن DESC آن را پاک می‌کند)",
    .help_opt_orphaned_notes = "  orphaned-notes [DIR] فهرست یادداشت‌هایی که مسیرشان وجود ندارد",
    .help_opt_purge_orphaned_notes = "  purge-orphaned-notes [DIR] حذف یادداشت‌هایی که مسیرشان وجود ندارد",
    .help_subcommands =
    \\<annotate>
    \\کاربرد: dirtree annotate PATH DESC
    \\        dirtree note PATH DESC          (نام مستعار)
    \\
    \\یک یادداشت یک‌خطی دربارهٔ یک فایل یا پوشه ذخیره کنید. یادداشت در
    \\.dirtree-state ذخیره می‌شود و دفعهٔ بعد که درخت رسم می‌شود در کنار PATH نمایش داده می‌شود.
    \\
    \\آرگومان‌ها:
    \\  PATH   فایل یا پوشه، نسبت به پوشهٔ فعلی
    \\  DESC   متن یادداشت؛ برای پاک‌کردن یک یادداشت موجود رشتهٔ خالی "" را بدهید
    \\
    \\مثال‌ها:
    \\  dirtree annotate src/main.zig "نقطهٔ ورود خط فرمان"
    \\  dirtree note docs "یادداشت‌های طراحی اینجا هستند"
    \\  dirtree annotate README.md ""        # پاک‌کردن یادداشت روی README.md
    \\</annotate>
    \\<orphaned_notes>
    \\کاربرد: dirtree orphaned-notes [DIR]
    \\
    \\فهرست یادداشت‌هایی که مسیر هدفشان دیگر وجود ندارد — برای مثال پس از آنکه
    \\فایلی تغییر نام یافته، جابه‌جا یا حذف شده باشد. مقدار پیش‌فرض DIR پوشهٔ فعلی است.
    \\این فقط خواندنی است: چیزی تغییر نمی‌کند. برای حذف آن‌ها از purge-orphaned-notes استفاده کنید.
    \\
    \\مثال‌ها:
    \\  dirtree orphaned-notes
    \\  dirtree orphaned-notes src
    \\</orphaned_notes>
    \\<purge_orphaned_notes>
    \\کاربرد: dirtree purge-orphaned-notes [DIR]
    \\
    \\حذف یادداشت‌هایی که مسیر هدفشان دیگر وجود ندارد. مقدار پیش‌فرض DIR پوشهٔ
    \\فعلی است. ابتدا orphaned-notes را اجرا کنید تا دقیقاً آنچه حذف خواهد شد را پیش‌نمایش ببینید.
    \\
    \\مثال‌ها:
    \\  dirtree purge-orphaned-notes
    \\  dirtree purge-orphaned-notes src
    \\</purge_orphaned_notes>
    ,
    .orphaned_header = "یادداشت‌های یتیم (مسیرهایی که دیگر وجود ندارند):",
    .orphaned_none = "هیچ یادداشت یتیمی وجود ندارد.",
    .purge_header = "یادداشت‌های یتیم حذف شدند:",
    .purge_none = "یادداشت یتیمی برای حذف وجود ندارد.",
    .help_opt_version = "  --version          Show version (offline; reads cached update-available notice)",
    .help_opt_version_check = "  --version-check    Force a fresh online check against the GitHub releases API",

    // ── هشدارها ──────────────────────────────────────────────
    .warn_persist_state = "هشدار: ذخیره وضعیت ممکن نشد: {}",

    // ── حالت آزمون ───────────────────────────────────────────
    .test_mode_msg = "حالت آزمون: آزمون‌های واحد Zig از طریق 'zig build test' اجرا می‌شوند",

    // ── متفرقه ───────────────────────────────────────────────
    .err_test_bin_run = "خطا: اجرای DIRTREE_TEST_BIN ممکن نشد: {s} (en: Error: could not run DIRTREE_TEST_BIN: {s})",
    .err_test_bin_wait = "خطا: انتظار برای DIRTREE_TEST_BIN ممکن نشد (en: Error: could not wait for DIRTREE_TEST_BIN)",
    .err_render_tree = "خطا در رسم درخت: {} (en: Error rendering tree: {})",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--rahnama", .arg = .help },
        .{ .name = "--darbare", .arg = .about },
        .{ .name = "--omgh", .arg = .depth },
        .{ .name = "--masir", .arg = .path },
        .{ .name = "--sade", .arg = .simple },
        .{ .name = "--arasteh", .arg = .decorated },
        .{ .name = "--bedun-nemad", .arg = .no_icons },
        .{ .name = "--bedun-rang", .arg = .no_color },
        .{ .name = "--rang", .arg = .color },
        .{ .name = "--bedun-hoshdar-yatim", .arg = .no_orphan_warning },
        .{ .name = "--bedun-yaddasht", .arg = .no_notes },
        .{ .name = "--namayesh-yaddasht", .arg = .show_notes },
        .{ .name = "--chideman-yaddasht", .arg = .notes },
        .{ .name = "--noqtechin-yaddasht", .arg = .note_leader },
        .{ .name = "--bedun-link", .arg = .no_hyperlinks },
        .{ .name = "--peyvandha", .arg = .hyperlinks },
        .{ .name = "--pishfarz", .arg = .default },
        .{ .name = "--baz-kardan", .arg = .open },
        .{ .name = "--bastan", .arg = .close },
        .{ .name = "--namayesh", .arg = .show },
        .{ .name = "--penhan", .arg = .hide },
        .{ .name = "--morattab", .arg = .sort },
        .{ .name = "--soudi", .arg = .asc },
        .{ .name = "--nozooli", .arg = .desc },
        .{ .name = "--namayesh-penhan", .arg = .show_hidden },
        .{ .name = "--baznevisi-tanzimate", .arg = .rewrite_settings },
        .{ .name = "--pikarband", .arg = .config },
        .{ .name = "--azmayesh", .arg = .@"test" },
        .{ .name = "--zaban", .arg = .lang },
        .{ .name = "--movaqqat", .arg = .temporary },
        .{ .name = "yaddasht", .arg = .annotate },
        .{ .name = "yaddashthaye-yatim", .arg = .orphaned_notes },
        .{ .name = "paksazi-yaddashthaye-yatim", .arg = .purge_orphaned_notes },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "DERAKHT_SADE", .var_id = .dirtree_simple },
        .{ .name = "DERAKHT_ARASTEH", .var_id = .dirtree_decorated },
        .{ .name = "DERAKHT_AUTO_SADE", .var_id = .dirtree_auto_simple },
        .{ .name = "PIPED_STDOUT", .var_id = .piped_stdout },
        .{ .name = "DERAKHT_SCM_TAGHYIRAT_PENHAN_YA_BASTEH", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
