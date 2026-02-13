const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── טקסט עזרה ────────────────────────────────────────────
    .help_title = "dirtree - עצי ספריות בעלי מצב לבני אדם ולמודלי שפה גדולים",
    .help_usage = "שימוש: dirtree [אפשרויות] [נתיב]",
    .help_options_header = "אפשרויות:",
    .help_opt_help = "  -h, --help         הצגת הודעת עזרה זו",
    .help_opt_about = "  -a, --about        הצגת תיאור מפורט",
    .help_opt_depth = "  -d, --depth N      הגדרת עומק מרבי (ברירת מחדל: 4)",
    .help_opt_simple = "  --simple           פלט פשוט ידידותי למודלי שפה גדולים",
    .help_opt_decorated = "  --decorated        כפיית פלט מעוטר (גם בצנרת)",
    .help_opt_no_icons = "  --no-icons         ביטול סמלים (מצב פשוט + כותרת מעוטרת)",
    .help_opt_no_color = "  --no-color        ביטול צבעי ANSI ושמירת ההעדפה",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   ביטול קישורי OSC8 ושמירת ההעדפה",
    .help_opt_default = "  --default X        שמירת מצב ברירת מחדל: opened|closed",
    .help_opt_open = "  -o, --open DIR...  פתיחת תת-ספרייה אחת או יותר (חזרה על הדגל להוספה)",
    .help_opt_close = "  -c, --close DIR... סגירת תת-ספרייה אחת או יותר (חזרה על הדגל להוספה)",
    .help_opt_show = "  --show PATH...     הצגת נתיבים יחסיים בכפייה; ביטויים רגולריים כ-‎/תבנית/ או !/תבנית/",
    .help_opt_hide = "  --hide PATH...     הסתרת נתיבים יחסיים; ביטויים רגולריים כ-‎/תבנית/ או !/תבנית/ (ניתן לחזרה)",
    .help_opt_sort = "  --sort MODE        מצב מיון: modified|alpha (ברירת מחדל: modified)",
    .help_opt_asc = "  --asc              מיון עולה",
    .help_opt_desc = "  --desc             מיון יורד (ברירת מחדל)",
    .help_opt_show_hidden = "  --show-hidden      הצגה זמנית של נתיבים מוסתרים דרך הגדרות",
    .help_opt_rewrite_settings = "  --rewrite-settings כתיבה מחדש של קובץ המצב עם ההגדרות הנוכחיות",
    .help_opt_config = "  --config           הצגת תצורה אפקטיבית מחושבת",
        .help_opt_test = "  --test             הרצת בדיקות משויכות",
    .help_opt_lang = "  --lang CODE        הגדרת שפת תצוגה (למשל en, de, fr, ja)",
    .help_regex_note = "השתמש ב-‎/תבנית/ או !/תבנית/ עם --open/--close/--show/--hide לכללי ביטויים רגולריים; ארגומנטים אחרים מטופלים כמילוליים.",
    .help_relative_note = "נתיבים ש-‎--show/--hide מקבלים חייבים להיות יחסיים (ללא '/' מוביל).",
    .help_behavior_header = "התנהגות:",
    .help_behavior_text = "כברירת מחדל, כאשר stdout אינו TTY (צנרת), צבעים/סמלים/קישורים מושבתים אלא אם ניתן --decorated.",
    .help_examples_header = "דוגמאות:",
    .help_example_1 = "  dirtree                       # הצגת עץ הספרייה הנוכחית",
    .help_example_2 = "  dirtree -d 3                  # הגדרת עומק ל-3 רמות",
    .help_example_3 = "  dirtree --sort alpha --asc    # מיון אלפביתי עולה",

    // ── טקסט אודות ───────────────────────────────────────────
    .about_text = "עץ ספריות בעל מצב (סמלים/צבעים/קישורים); --simple למודלי שפה גדולים; שומר .dirtree-state (default/open/close/show/hide); ביטויים רגולריים דרך /תבנית/ או !/תבנית/; מילוליים חייבים להיות יחסיים; משתני סביבה: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── חלקי ספירת מוסתרים ───────────────────────────────────
    .hidden_dir_singular = "ספרייה",
    .hidden_dir_plural = "ספריות",
    .hidden_file_singular = "קובץ",
    .hidden_file_plural = "קבצים",
    .hidden_and = " ו-",
    .hidden_is_hidden = " מוסתר.",
    .hidden_are_hidden = " מוסתרים.",
    .stats_shown = " מוצגים",
    .stats_hidden = " מוסתרים.",
    .stats_line_singular = "שורה",
    .stats_line_plural = "שורות",
    .stats_separator = "; ",

    // ── הודעות שגיאה ─────────────────────────────────────────
    .err_depth_requires_number = "שגיאה: --depth דורש ארגומנט מספרי",
    .err_sort_requires_mode = "שגיאה: --sort דורש 'modified' או 'alpha'",
    .err_default_requires_value = "שגיאה: --default דורש לפחות ערך אחד",
    .err_default_state_conflict = "שגיאה: התנגשות מצב ב---default",
    .err_default_accepts = "שגיאה: --default מקבל opened/closed",
    .err_open_requires_dir = "שגיאה: --open דורש לפחות ספרייה אחת",
    .err_close_requires_dir = "שגיאה: --close דורש לפחות ספרייה אחת",
    .err_show_requires_path = "שגיאה: --show דורש לפחות נתיב אחד",
    .err_hide_requires_path = "שגיאה: --hide דורש לפחות נתיב אחד",
    .err_unknown_option = "אפשרות לא מוכרת",
    .err_not_a_directory = "שגיאה: '{s}' אינו ספרייה",
    .err_regex_empty = "שגיאה: תבנית הביטוי הרגולרי אינה יכולה להיות ריקה",
    .err_paths_must_be_relative = "שגיאה: נתיבי {s} חייבים להיות יחסיים (ללא '/' מוביל): {s}",
    .err_out_of_memory = "אין מספיק זיכרון",
    .err_regex_conflict_path = "שגיאה: הנתיב '{s}' תואם גם לתבניות פתיחה וגם לתבניות סגירה",
    .err_regex_conflict_open = "  תבנית פתיחה: {s}",
    .err_regex_conflict_close = "  תבנית סגירה: {s}",
    .err_unknown_lang = "שגיאה: קוד שפה לא מוכר '{s}'. זמינים: {s}",

    // ── אזהרות ───────────────────────────────────────────────
    .warn_persist_state = "אזהרה: לא ניתן לשמור את המצב: {}",

    // ── מצב בדיקה ────────────────────────────────────────────
    .test_mode_msg = "מצב בדיקה: בדיקות יחידה של Zig מורצות דרך 'zig build test'",

    // ── שונות ────────────────────────────────────────────────
    .err_test_bin_run = "שגיאה: לא ניתן להריץ DIRTREE_TEST_BIN: {s}",
    .err_test_bin_wait = "שגיאה: לא ניתן להמתין ל-DIRTREE_TEST_BIN",
    .err_render_tree = "שגיאה ברינדור העץ: {}",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--ezra", .arg = .help },
        .{ .name = "--odot", .arg = .about },
        .{ .name = "--omek", .arg = .depth },
        .{ .name = "--pashut", .arg = .simple },
        .{ .name = "--meutat", .arg = .decorated },
        .{ .name = "--lelo-smailim", .arg = .no_icons },
        .{ .name = "--lelo-tseva", .arg = .no_color },
        .{ .name = "--lelo-kishurim", .arg = .no_hyperlinks },
        .{ .name = "--brera-mehdal", .arg = .default },
        .{ .name = "--ptakh", .arg = .open },
        .{ .name = "--sgor", .arg = .close },
        .{ .name = "--hatsa", .arg = .show },
        .{ .name = "--hastir", .arg = .hide },
        .{ .name = "--miun", .arg = .sort },
        .{ .name = "--ole", .arg = .asc },
        .{ .name = "--yored", .arg = .desc },
        .{ .name = "--hatsa-mustar", .arg = .show_hidden },
        .{ .name = "--ktov-mehadash-hagdarot", .arg = .rewrite_settings },
        .{ .name = "--tatzura", .arg = .config },
                .{ .name = "--bdika", .arg = .@"test" },
        .{ .name = "--safa", .arg = .lang },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "ETZ_PASHUT", .var_id = .dirtree_simple },
        .{ .name = "ETZ_MEUTAT", .var_id = .dirtree_decorated },
        .{ .name = "ETZ_AUTO_PASHUT", .var_id = .dirtree_auto_simple },
        .{ .name = "PIPED_STDOUT", .var_id = .piped_stdout },
        .{ .name = "ETZ_SCM_SHINUYIM_MUSTRIM_O_SGURIM", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
