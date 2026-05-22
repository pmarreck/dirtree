const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── نص المساعدة ──────────────────────────────────────────
    .help_title = "dirtree - أشجار مجلدات ذات حالة للبشر ونماذج اللغة الكبيرة",
    .help_usage = "الاستخدام: dirtree [خيارات] [مسار]",
    .help_options_header = "الخيارات:",
    .help_opt_help = "  -h, --help         عرض رسالة المساعدة هذه",
    .help_opt_about = "  -a, --about        عرض الوصف التفصيلي",
    .help_opt_depth = "  -d, --depth N      تعيين العمق الأقصى (الافتراضي: 4)",
    .help_opt_simple = "  --simple           إخراج بسيط ملائم لنماذج اللغة الكبيرة",
    .help_opt_decorated = "  --decorated        فرض الإخراج المزخرف (حتى عند التوجيه)",
    .help_opt_no_icons = "  --no-icons         تعطيل الرموز (وضع بسيط + ترويسة مزخرفة)",
    .help_opt_no_color = "  --no-color        تعطيل ألوان ANSI وحفظ التفضيل",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   تعطيل روابط OSC8 وحفظ التفضيل",
    .help_opt_default = "  --default X        حفظ الحالة الافتراضية: opened|closed",
    .help_opt_open = "  -o, --open DIR...  فتح مجلد فرعي أو أكثر (كرّر العلم للإضافة)",
    .help_opt_close = "  -c, --close DIR... إغلاق مجلد فرعي أو أكثر (كرّر العلم للإضافة)",
    .help_opt_show = "  --show PATH...     فرض إظهار مسارات نسبية؛ التعبيرات النمطية كـ /نمط/ أو !/نمط/",
    .help_opt_hide = "  --hide PATH...     إخفاء مسارات نسبية؛ التعبيرات النمطية كـ /نمط/ أو !/نمط/ (قابل للتكرار)",
    .help_opt_sort = "  --sort MODE        وضع الترتيب: modified|alpha (الافتراضي: modified)",
    .help_opt_asc = "  --asc              ترتيب تصاعدي",
    .help_opt_desc = "  --desc             ترتيب تنازلي (الافتراضي)",
    .help_opt_show_hidden = "  --show-hidden      عرض المسارات المخفية مؤقتاً عبر الإعدادات",
    .help_opt_rewrite_settings = "  --rewrite-settings إعادة كتابة ملف الحالة بالإعدادات الحالية",
    .help_opt_config = "  --config           عرض التكوين الفعال المحسوب",
        .help_opt_test = "  --test             تشغيل الاختبارات المرتبطة",
    .help_opt_lang = "  --lang CODE        تعيين لغة العرض (مثلاً en، de، fr، ja)",
    .help_regex_note = "استخدم /نمط/ أو !/نمط/ مع --open/--close/--show/--hide لقواعد التعبيرات النمطية؛ المعاملات الأخرى تُعامل كنصوص حرفية.",
    .help_relative_note = "المسارات المقدّمة لـ --show/--hide يجب أن تكون نسبية (بدون '/' في البداية).",
    .help_behavior_header = "السلوك:",
    .help_behavior_text = "افتراضياً، عندما لا يكون stdout طرفية (توجيه)، تُعطّل الألوان/الرموز/الروابط ما لم يُحدد --decorated.",
    .help_examples_header = "أمثلة:",
    .help_example_1 = "  dirtree                       # عرض شجرة المجلد الحالي",
    .help_example_2 = "  dirtree -d 3                  # تعيين العمق إلى 3 مستويات",
    .help_example_3 = "  dirtree --sort alpha --asc    # ترتيب أبجدي تصاعدي",

    // ── نص حول البرنامج ──────────────────────────────────────
    .about_text = "شجرة مجلدات ذات حالة (رموز/ألوان/روابط)؛ --simple لنماذج اللغة الكبيرة؛ يحفظ .dirtree-state (default/open/close/show/hide)؛ تعبيرات نمطية عبر /نمط/ أو !/نمط/؛ النصوص الحرفية يجب أن تكون نسبية؛ متغيرات البيئة: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── أجزاء عدّ المخفيات ───────────────────────────────────
    .hidden_dir_singular = "مجلد",
    .hidden_dir_plural = "مجلدات",
    .hidden_file_singular = "ملف",
    .hidden_file_plural = "ملفات",
    .hidden_and = " و",
    .hidden_is_hidden = " مخفي.",
    .hidden_are_hidden = " مخفية.",
    .stats_shown = " معروض",
    .stats_hidden = " مخفي.",
    .stats_line_singular = "سطر",
    .stats_line_plural = "أسطر",
    .stats_separator = "؛ ",

    // ── رسائل الخطأ ──────────────────────────────────────────
    .err_depth_requires_number = "خطأ: --depth يتطلب معاملاً رقمياً",
    .err_sort_requires_mode = "خطأ: --sort يتطلب 'modified' أو 'alpha'",
    .err_default_requires_value = "خطأ: --default يتطلب قيمة واحدة على الأقل",
    .err_default_state_conflict = "خطأ: تعارض في حالة --default",
    .err_default_accepts = "خطأ: --default يقبل opened/closed",
    .err_open_requires_dir = "خطأ: --open يتطلب مجلداً واحداً على الأقل",
    .err_close_requires_dir = "خطأ: --close يتطلب مجلداً واحداً على الأقل",
    .err_show_requires_path = "خطأ: --show يتطلب مساراً واحداً على الأقل",
    .err_hide_requires_path = "خطأ: --hide يتطلب مساراً واحداً على الأقل",
    .err_unknown_option = "خيار غير معروف",
    .err_not_a_directory = "خطأ: '{s}' ليس مجلداً",
    .err_regex_empty = "خطأ: نمط التعبير النمطي يجب ألا يكون فارغاً",
    .err_paths_must_be_relative = "خطأ: مسارات {s} يجب أن تكون نسبية (بدون '/' في البداية): {s}",
    .err_out_of_memory = "نفدت الذاكرة",
    .err_regex_conflict_path = "خطأ: المسار '{s}' يطابق أنماط الفتح والإغلاق معاً",
    .err_regex_conflict_open = "  نمط الفتح: {s}",
    .err_regex_conflict_close = "  نمط الإغلاق: {s}",
    .err_unknown_lang = "خطأ: رمز لغة غير معروف '{s}'. المتاحة: {s}",
    .err_annotate_requires_path = "Error: annotate requires a path",
    .err_annotate_requires_description = "Error: annotate requires a description (use \"\" to clear)",
    .err_annotate_multiline = "Error: annotation description must be a single line",
    .err_annotate_too_many_args = "Error: annotate accepts exactly two positional arguments: <path> <description>",
    .help_opt_annotate = "  annotate PATH DESC Persist a one-line note about a file or directory (alias: note; empty DESC clears)",

    // ── التحذيرات ────────────────────────────────────────────
    .warn_persist_state = "تحذير: تعذّر حفظ الحالة: {}",

    // ── وضع الاختبار ─────────────────────────────────────────
    .test_mode_msg = "وضع الاختبار: تُشغّل اختبارات Zig الوحدوية عبر 'zig build test'",

    // ── متفرقات ──────────────────────────────────────────────
    .err_test_bin_run = "خطأ: تعذّر تشغيل DIRTREE_TEST_BIN: {s}",
    .err_test_bin_wait = "خطأ: تعذّر انتظار DIRTREE_TEST_BIN",
    .err_render_tree = "خطأ في رسم الشجرة: {}",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--musaada", .arg = .help },
        .{ .name = "--hawla", .arg = .about },
        .{ .name = "--umq", .arg = .depth },
        .{ .name = "--basit", .arg = .simple },
        .{ .name = "--muzakhraf", .arg = .decorated },
        .{ .name = "--bidun-rumooz", .arg = .no_icons },
        .{ .name = "--bidun-alwan", .arg = .no_color },
        .{ .name = "--bidun-rawabet", .arg = .no_hyperlinks },
        .{ .name = "--iftiradiy", .arg = .default },
        .{ .name = "--iftah", .arg = .open },
        .{ .name = "--aghliq", .arg = .close },
        .{ .name = "--azhir", .arg = .show },
        .{ .name = "--ikhfi", .arg = .hide },
        .{ .name = "--tartib", .arg = .sort },
        .{ .name = "--tusaudi", .arg = .asc },
        .{ .name = "--tanazuli", .arg = .desc },
        .{ .name = "--azhir-makhfi", .arg = .show_hidden },
        .{ .name = "--aed-kitabat-iidadat", .arg = .rewrite_settings },
        .{ .name = "--takween", .arg = .config },
                .{ .name = "--ikhtbar", .arg = .@"test" },
        .{ .name = "--lugha", .arg = .lang },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "SHAJARA_BASIT", .var_id = .dirtree_simple },
        .{ .name = "SHAJARA_MUZAKHRAF", .var_id = .dirtree_decorated },
        .{ .name = "SHAJARA_AUTO_BASIT", .var_id = .dirtree_auto_simple },
        .{ .name = "PIPED_STDOUT", .var_id = .piped_stdout },
        .{ .name = "SHAJARA_SCM_TAGHYIRAT_MAKHFIYA_AW_MUGHLQA", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
